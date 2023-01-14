LIBRARY IEEE;

USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY datapath IS
	PORT(
		clk, rst, enter : IN STD_LOGIC;
		mov : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		J1, J2, Turn, Mov_retro : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		ins : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
		z_flag, s_flag, ov_flag, c_flag : OUT STD_LOGIC
	);
END ENTITY datapath;

ARCHITECTURE bhr OF datapath IS

	TYPE state is (state0,state1,state2,state3);
	SIGNAL pr_state : state;
	
	SIGNAL REG_A,REG_B,REG_C,REG_D : STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL PC, PC_AUX, OFFSET : INTEGER RANGE 0 TO 9999 := 0;
	
	SIGNAL MAR, IR : STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL ACC: STD_LOGIC_VECTOR(9 DOWNTO 0);
	SIGNAL MBR : STD_LOGIC_VECTOR(15 DOWNTO 0);

	SIGNAL buff1: STD_LOGIC_VECTOR(7 DOWNTO 0):= "00001011";
	SIGNAL buff2: STD_LOGIC_VECTOR(7 DOWNTO 0);

	TYPE data IS ARRAY (7 DOWNTO 0) OF STD_LOGIC_VECTOR(15 DOWNTO 0);
	TYPE list IS ARRAY (80 DOWNTO 0) OF STD_LOGIC_VECTOR(11 DOWNTO 0);
	TYPE reg IS ARRAY(0 TO 7) OF STD_LOGIC_VECTOR(15 DOWNTO 0);
	TYPE cmp IS ARRAY (10 DOWNTO 0) OF STD_LOGIC_VECTOR(15 DOWNTO 0);
	
	SIGNAL reggy, reggu : reg;
	SIGNAL zflag, sflag, ovflag, cflag : STD_LOGIC;
	SIGNAL wrt, flag : STD_LOGIC:= '0';
	SIGNAL OP, dir : STD_LOGIC_VECTOR(3 DOWNTO 0);
	SIGNAL data_in : STD_LOGIC_VECTOR(9 DOWNTO 0);
	
	SIGNAL signo1, signo2 : STD_LOGIC :='0';
	
	CONSTANT values : data := (
	-- Datos precargados en la "ROM" para usar despues en el programa
		0  => "0000000000000000", -- Comenzar en 0
		1  => "1111111111111111", -- 1nos de referencia
		2  => "0000000000001000", -- 8 estados donde ganas
		3  => "0000000000000001", -- Valor 1, para los ciclos
		4  => "0000001000000000", -- limite real del tablero
		5  => "0000000000000000", -- Placeholder
		6  => "0000000000000000", -- Placeholder
		7  => "0000000000000000" -- Placeholder
	);
	
	CONSTANT tablero : data := (
		0  => "0000000111000000", --Estados ganadores del tablero
		1  => "0000000000111000",
		2  => "0000000000000111",
		3  => "0000000100100100",
		4  => "0000000010010010",
		5  => "0000000001001001",
		6  => "0000000100010001",
		7  => "0000000001010100"
	);
	
	CONSTANT cmprs : cmp := (
	--Aqui van almacenadas las "configuraciones" de el comparador y de las flags
	--Carry, Zero, Overflow, Sign, Mayor, Igual, Menor
		0   => "0000000000000000",  -- Salto directo sin comprobacion
		1   => "0000000000000001", -- El numero es menor
		2   => "0000000000000010", -- El numero es igual
		3   => "0000000000000011", -- El numero es menor o igual
		4   => "0000000000000100", -- El numero es mayor
		5   => "0000000000000101", -- El numero es diferente
		6   => "0000000000000110", -- El numero es mayor o igual
		7   => "0000000000001000", -- El numero es negativo
		8   => "0000000000010000", -- El numero es muy grande
		9   => "0000000000100000", -- El numero es cero
		10  => "0000000001000000"  -- El numero tiene un bit extra
	);
	
	CONSTANT INSTRUCTIONS : list := (
	
		-- Comienza el juego del gato
		0  => ("0000"&"1101"&"0000"&"0000"), -- Cargar jugador 1 en 0 
		1  => ("0000"&"1101"&"0001"&"0000"), -- Cargar jugador 2 en 0 
		2  => ("0000"&"1101"&"0010"&"0000"), -- Cargar Auxiliar  en 0
		4  => ("0000"&"1101"&"0100"&"0000"), -- Turno, empieza jugador 1
		
		5  => ("0010"&"1101"&"0110"&"0000"), -- Movimiento jugador
		6  => ("0011"&"1101"&"0111"&"0110"), -- Movimiento jugador a aux
		
		7  => ("0000"&"0011"&"0110"&"0000"), -- Esta ocupada por jugador 1?
		8  =>	("0000"&"1011"&"0110"&"0111"), -- si?
		9  => ("1110"&"0010"&"0010"&"1100"), -- moverse a instruccion 44
		
		10 => ("0011"&"1101"&"0111"&"0110"), -- Movimiento jugador a aux
		11 => ("0000"&"0011"&"0110"&"0001"), -- Esta ocupada por jugador 2?
		12 =>	("0000"&"1011"&"0110"&"0111"), -- si?
		13 => ("1110"&"0010"&"0011"&"1010"), -- moverse a instruccion 58
		
		14 => ("0000"&"1101"&"0101"&"1001"), -- Cargar turno alternativo
		15 => ("0000"&"1011"&"0101"&"1000"), -- turno jugador 2?
		16 => ("1110"&"0010"&"0001"&"0100"), -- si, saltar a 20
		17 => ("0000"&"0111"&"0000"&"0110"), -- guardar movimiento del jugador 1
	
		18 => ("0000"&"1011"&"0101"&"1000"), -- turno jugador 1?
		19 => ("1110"&"0101"&"0001"&"0101"), -- si, saltar a 21
		20 => ("0000"&"0111"&"0001"&"0110"), -- guardar movimiento del jugador 2
		
		21 => ("0000"&"1101"&"1000"&"1000"), -- Empezar contador en 0
		22 => ("0000"&"1101"&"1001"&"1010"), -- Empezar limite en 8
		23 => ("0001"&"1101"&"0011"&"1000"), -- Cargar Ganadores con 0
		24 => ("0000"&"1101"&"1011"&"0011"), -- Cargar Sumando = 1
		25 => ("0000"&"1011"&"0000"&"0001"), -- Gano jugador 1?
		26 => ("1110"&"0010"&"0010"&"1110"), -- si, mover a 46
		27 =>	("0000"&"0111"&"1000"&"1011"), -- Contador ++
		28 =>	("0000"&"1011"&"1000"&"1001"), -- Contador mayor a 8?
		29 => ("1110"&"0110"&"0010"&"0000"), -- si saltar a 32
		30 => ("0001"&"1101"&"0011"&"1000"), -- aumentar tablero
		31 => ("1110"&"0000"&"0001"&"1001"), -- repetir 25
		
		32 => ("0000"&"1101"&"1000"&"1000"), -- Empezar contador en 0
		33 => ("0000"&"1101"&"1001"&"1010"), -- Empezar limite en 8
		34 => ("0001"&"1101"&"0011"&"1000"), -- Cargar Ganadores con 0
		35 => ("0000"&"1101"&"1011"&"0011"), -- Cargar Sumando = 1
		36 => ("0000"&"1011"&"0001"&"0001"), -- Gano jugador 2?
		37 => ("1110"&"0010"&"0010"&"1110"), -- si, mover a 46
		38 =>	("0000"&"0111"&"1000"&"1011"), -- Contador ++
		39 =>	("0000"&"1011"&"1000"&"1001"), -- Contador igual a 8?
		40 => ("1110"&"0010"&"0010"&"1100"), -- si saltar a 44
		41 => ("0001"&"1101"&"0011"&"1000"), -- aumentar tablero
		42 => ("1110"&"0000"&"0010"&"0100"), -- repetir 36
		
		43 => ("1110"&"0000"&"0000"&"0000"), -- tablero lleno, reiniciar
		
	   44 => ("0000"&"0001"&"0100"&"0000"), -- pasar turno, aplicar (not)
		45 => ("1110"&"0000"&"0000"&"0101"), -- repetir ins 5
	
		46 => ("1111"&"1111"&"1111"&"1111"), -- esperar
		47 => ("0000"&"0000"&"0000"&"0000"), -- reiniciar
	
		48 => ("0000"&"1101"&"1000"&"0000"), -- Empezar contador en 0
		49 => ("0000"&"1101"&"1001"&"0010"), -- Empezar limite en 8
		50 => ("0000"&"1101"&"1010"&"0100"), -- Cargar Limite  del tablero
		51 => ("0000"&"1101"&"1011"&"0011"), -- Cargar Sumando = 1
		52 =>	("0000"&"0101"&"0110"&"0000"), -- Mover la seleccion en 1
		53 =>	("0000"&"1011"&"0110"&"1010"), -- La seleccion ya esta en el limite del tablero?
		54 =>	("1110"&"0010"&"0100"&"1110"), -- si, ir a 78
		55 =>	("0000"&"1011"&"1000"&"1001"), -- Contador mayor a 8?
		56 =>	("1110"&"0010"&"0010"&"1011"), -- si, ir a 43
		57 =>	("0000"&"0111"&"1000"&"1011"), -- Contador ++
		58 => ("0011"&"1101"&"0111"&"0110"), -- Movimiento jugador a aux
		59 => ("0000"&"0011"&"0110"&"0000"), -- Esta ocupada por jugador 1?
		60 =>	("0000"&"1011"&"0110"&"0111"), -- si?
		61 => ("1110"&"0010"&"0011"&"0100"), -- Si repetir 52
		62 => ("1110"&"0000"&"0000"&"1010"), -- Volver a  10
	
		63 => ("0000"&"1101"&"1000"&"1000"), -- Empezar contador en 0
		64 => ("0000"&"1101"&"1001"&"1010"), -- Empezar limite en 8
		65 => ("0000"&"1101"&"1010"&"0100"), -- Cargar Limite  del tablero
		66 => ("0000"&"1101"&"1011"&"0011"), -- Cargar Sumando = 1
		67 =>	("0000"&"0101"&"0110"&"0000"), -- Mover la seleccion en 1
		68 =>	("0000"&"1011"&"0110"&"1010"), -- La seleccion ya esta en el limite del tablero?
		69 =>	("1110"&"0010"&"0010"&"0110"), -- si, ir a 80
		70 =>	("0000"&"1011"&"1000"&"1001"), -- Contador mayor a 8?
		71 =>	("1110"&"0010"&"0101"&"0000"), -- si, ir a 43
		72 =>	("0000"&"0111"&"1000"&"1011"), -- Contador ++
		73 => ("0011"&"1101"&"0111"&"0110"), -- Movimiento jugador a aux
		74 => ("0000"&"0011"&"0110"&"0001"), -- Esta ocupada por jugador 2?
		75 =>	("0000"&"1011"&"0110"&"0111"), -- si?
		76 => ("1110"&"0010"&"0100"&"0011"), -- Si repetir 67
		77 => ("1110"&"0000"&"0000"&"1110"),  -- Volver a 14
		
		78 => ("0000"&"1011"&"0110"&"0011"), -- Reiniciar el tablero
		79 => ("1110"&"0000"&"0011"&"0111"),  -- Volver a 55
	
		80 => ("0000"&"1011"&"0110"&"0011"), -- Reiniciar el tablero
		81 => ("1110"&"0000"&"0100"&"0110")  -- Volver a 70
	);
	
	COMPONENT ALU IS 
		PORT(
			A,B : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
			sel : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
			R : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			clk, rst : IN STD_LOGIC;
			z_flag, s_flag, ov_flag, c_flag : OUT STD_LOGIC
		);
	END COMPONENT ALU;
	
BEGIN


	PROCESS(clk, rst, REG_A, REG_B, REG_C, REG_D) IS
	BEGIN
		IF (rst = '0') THEN
			pr_state <= state0;
			PC <= 0;
		ELSIF (RISING_EDGE(clk)) THEN
			CASE pr_state IS
				WHEN state0 => -- FETCH
					pr_state <= state1;
					MAR <= INSTRUCTIONS(PC);	
					
				WHEN state1 => -- DECODE
					IF (MAR(11 DOWNTO 8) /= "1111") THEN
						IF (MAR(11 DOWNTO 8) = "1101") THEN --En caso que la instruccion sea load
							IF (MAR(15 DOWNTO 12) = "0001") THEN
								REG_C <= unsigned(MAR(3 DOWNTO 0));
								REG_D <= tablero(to_integer());
							ELSIF (MAR(15 DOWNTO 12) = "0010") THEN
								REG_D <= mov;
							ELSIF (MAR(15 DOWNTO 12) = "0011") THEN
								REG_D <= reggy(to_integer(unsigned(MAR(3 DOWNTO 0))));
							ELSE
								REG_D <= values(to_integer(unsigned(MAR(3 DOWNTO 0))));
							END IF;
							OFFSET <= 1;
						
						ELSIF (MAR(15 DOWNTO 12) = "1110") THEN -- jump 
							IF(cmprs(to_integer(unsigned(MAR(11 DOWNTO 8)))) /= reggy(7)) THEN -- Primero se comprueba si hubo una comparacion primero (En este caso no se consideran las flags)
								OFFSET <= to_integer(unsigned(MAR(7 DOWNTO 0))) - PC;
							
							ELSIF(cmprs(to_integer(unsigned(MAR(11 DOWNTO 8)))) = "0000000000000000") THEN -- Si no hay comparacion se hace un salto directo
								OFFSET <= to_integer(unsigned(MAR(7 DOWNTO 0)));
							
							ELSE -- En cualquier otro caso no se hace nada
								OFFSET <= 1;
							END IF;
						
						ELSIF (MAR(11 DOWNTO 8) = "1100") THEN -- branch con banderas
							IF (zflag = '1') THEN -- zflag, sflag, ovflag, cflag
								OFFSET <= 0;
							
							ELSIF (sflag = '1') THEN
								OFFSET <= 0;
							
							ELSIF (ovflag = '1') THEN
								OFFSET <= 0;
							
							ELSE
								OFFSET <= 0;
							END IF;
						ELSE
							-- El resto de operaciones son controladas por la ALU
							OP <= MAR(11 DOWNTO 8);
							REG_A <= reggy(to_integer(unsigned(MAR(7 DOWNTO 4))));
							J1 <= REG_A;
							REG_B <= reggy(to_integer(unsigned(MAR(3 DOWNTO 0))));
							J2 <= REG_B;
							OFFSET <= 1;
						END IF;
					END IF;
					pr_state <= state2;
				
				WHEN state2 => -- EXECUTE
					IF (MAR(11 DOWNTO 8) = "1111") THEN
						reggy(to_integer(unsigned(MAR(7 DOWNTO 4)))) <= MBR;
						pr_state <= state3;
					ELSE
						IF (MAR(11 DOWNTO 8) = "1101") THEN
							reggy(to_integer(unsigned(MAR(7 DOWNTO 4)))) <= REG_D;		
						ELSIF(MAR(11 DOWNTO 8) = "1011") THEN
							reggy(7) <= MBR; -- Aqui se guarda en el ultimo registro el resultado de la comparacion
						ELSE
							IF (sflag = '1') THEN
								reggy(to_integer(unsigned(MAR(7 DOWNTO 4)))) <= '1' & MBR(14 DOWNTO 0);
							ELSE
								reggy(to_integer(unsigned(MAR(7 DOWNTO 4)))) <= MBR;
							END IF;
						END IF;
					PC_AUX <= PC + OFFSET;
					PC <= PC_AUX;
					pr_state <= state0;
					Turn <= reggy(4);
					Mov_retro <= reggy(2);
					END IF;
				
				WHEN state3 => 
					pr_state <= state3;
			END CASE;
		END IF;
		ins <= MAR;
	END PROCESS;
	alu1: ALU PORT MAP(REG_A, REG_B, OP, MBR, clk, rst, zflag, sflag, ovflag, cflag);
END ARCHITECTURE;