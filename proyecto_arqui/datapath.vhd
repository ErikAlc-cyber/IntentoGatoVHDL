LIBRARY IEEE;

USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY datapath IS
	PORT(
		clk, rst : IN STD_LOGIC;
		mov : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		J1, J2, Turn, Mov_retro : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		ins : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
	);
END ENTITY datapath;

ARCHITECTURE bhr OF datapath IS

	TYPE state is (state0,state1,state2,state3);
	SIGNAL pr_state : state;
	
	SIGNAL REG_A,REG_B,REG_C,REG_D : STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL PC, PC_AUX : INTEGER RANGE -9999 TO 9999 := 0;
	SIGNAL OFFSET : INTEGER RANGE -9999 TO 9999 := 0;
	
	SIGNAL MAR, IR : STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL ACC: STD_LOGIC_VECTOR(9 DOWNTO 0);
	SIGNAL MBR : STD_LOGIC_VECTOR(15 DOWNTO 0);

	SIGNAL buff1: STD_LOGIC_VECTOR(7 DOWNTO 0):= "00001011";
	SIGNAL buff2: STD_LOGIC_VECTOR(7 DOWNTO 0);

	TYPE data IS ARRAY (7 DOWNTO 0) OF STD_LOGIC_VECTOR(15 DOWNTO 0);
	TYPE list IS ARRAY (7 DOWNTO 0) OF STD_LOGIC_VECTOR(15 DOWNTO 0);
	TYPE reg IS ARRAY(0 TO 15) OF STD_LOGIC_VECTOR(15 DOWNTO 0);
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
		0 => ("0000"&"1101"&"0001"&"0000"), -- Empezar contador en 0
		1 => ("0000"&"1101"&"0010"&"0010"), -- Empezar limite en 8
		2 => ("0000"&"1101"&"0011"&"0011"), -- Cargar Sumando = 1
		3 => ("0000"&"0111"&"0001"&"0011"), -- Contador ++
		
		4 => ("0000"&"1011"&"0001"&"0010"), -- Comparar Contador con limite
		5 => ("1110"&"0010"&"0000"&"0111"), -- Contador igual a 8? si saltar a 7
		6 => ("1110"&"0000"&"0000"&"0011"), -- repetir 3
		
		7 => ("1111"&"1111"&"1111"&"1111")
		
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
								REG_C <= reggy(to_integer(unsigned(MAR(3 DOWNTO 0))));
								REG_D <= tablero(to_integer(unsigned(REG_C)));
							ELSIF (MAR(15 DOWNTO 12) = "0010") THEN
								REG_D <= mov;
							ELSIF (MAR(15 DOWNTO 12) = "0011") THEN
								REG_D <= reggy(to_integer(unsigned(MAR(3 DOWNTO 0))));
							ELSIF (MAR(15 DOWNTO 12) = "0000") THEN
								REG_D <= values(to_integer(unsigned(MAR(3 DOWNTO 0))));
							END IF;
							OFFSET <= PC;
						
						ELSIF (MAR(15 DOWNTO 12) = "1110") THEN -- jump 
							IF(cmprs(to_integer(unsigned(MAR(11 DOWNTO 8)))) = reggu(0)) THEN -- Primero se comprueba si hubo una comparacion primero
								OFFSET <= to_integer(unsigned(MAR(7 DOWNTO 0)));
								reggy(15) <= "0000000000000100";
							
							ELSIF(MAR(11 DOWNTO 8) = "0000") THEN -- Si no hay comparacion se hace un salto directo
								OFFSET <= to_integer(unsigned(MAR(7 DOWNTO 0)));
								reggy(15) <= "0000000000000001";	
								
							ELSE -- En cualquier otro caso no se hace nada
								OFFSET <= PC+1;
								reggy(15) <= "0000000000000011";
							END IF;
	
						ELSE
							-- El resto de operaciones son controladas por la ALU
							OP <= MAR(11 DOWNTO 8);
							REG_A <= reggy(to_integer(unsigned(MAR(7 DOWNTO 4))));
							REG_B <= reggy(to_integer(unsigned(MAR(3 DOWNTO 0))));
							OFFSET <= PC;
						END IF;
					
					END IF;
					J1 <= reggy(1);
					J2 <= reggy(2);
					pr_state <= state2;
				
				WHEN state2 => -- EXECUTE
					IF (MAR(11 DOWNTO 8) = "1111") THEN
						reggy(to_integer(unsigned(MAR(7 DOWNTO 4)))) <= MBR;
						pr_state <= state3;
					ELSE
						IF (MAR(11 DOWNTO 8) = "1101") THEN
							reggy(to_integer(unsigned(MAR(7 DOWNTO 4)))) <= REG_D;		
						
						ELSIF(MAR(11 DOWNTO 8) = "1011") THEN
							reggu(0) <= MBR; -- Aqui se guarda el resultado de la comparacion
						
						ELSE
							IF (sflag = '1') THEN
								reggy(to_integer(unsigned(MAR(7 DOWNTO 4)))) <= '1' & MBR(14 DOWNTO 0);
							ELSE
								reggy(to_integer(unsigned(MAR(7 DOWNTO 4)))) <= MBR;
							END IF;
						END IF;
						IF (MAR(15 DOWNTO 12) = "1110") THEN
							PC <= OFFSET;
						ELSE
							PC <= OFFSET + 1;
						END IF;
						Turn <= reggu(0);
						Mov_retro <= reggy(15);
						pr_state <= state0;
					END IF;
					
				WHEN state3 => 
					J1 <= reggy(1);
					J2 <= reggy(2);
					Turn <= reggy(3);
					Mov_retro <= reggy(13);
					pr_state <= state3;
			END CASE;
		END IF;
		ins <= MAR;
	END PROCESS;
	alu1: ALU PORT MAP(REG_A, REG_B, OP, MBR, clk, rst, zflag, sflag, ovflag, cflag);
END ARCHITECTURE;