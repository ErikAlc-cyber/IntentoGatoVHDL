LIBRARY IEEE;

USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY datapath IS
	PORT(
		clk, rst : IN STD_LOGIC;
		salida, s1,s2 : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		--salida: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
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

	TYPE data IS ARRAY (11 DOWNTO 0) OF STD_LOGIC_VECTOR(15 DOWNTO 0);
	TYPE cmp IS ARRAY (10 DOWNTO 0) OF STD_LOGIC_VECTOR(15 DOWNTO 0);
	TYPE list IS ARRAY (51 DOWNTO 0) OF STD_LOGIC_VECTOR(11 DOWNTO 0);
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
		0  => "0000000000000000", -- 
		1  => "0000000000000000", -- 
		2  => "0000000000000000", -- 
		3  => "0000000000000000", -- 
		4  => "0000000000000000", -- 
		5  => "0000000000000000", -- 
		6  => "0000000000000000", -- 
		7  => "0000000000000000", -- 
		8  => "0000000000000000", -- 
		9  => "0000000000000000", -- 
		10 => "0000000000000000", -- 
		11 => "0000000000000000"  -- 
	);
	
	CONSTANT cmprs : cmp := (
	--Aqui van almacenadas las "configuraciones" de el comparador y de las flags
	--Carry, Zero, Overflow, Sign, Mayor, Igual, Menor
		0  => "0000000000000001", -- El numero es menor
		1  => "0000000000000010", -- El numero es igual
		2  => "0000000000000011", -- El numero es menor o igual
		3  => "0000000000000100", -- El numero es mayor
		4  => "0000000000000101", -- El numero es diferente
		5  => "0000000000000110", -- El numero es mayor o igual
		6  => "0000000000001000", -- El numero es negativo
		7  => "0000000000010000", -- El numero es muy grande
		8  => "0000000000100000", -- El numero es cero
		9  => "0000000001000000", -- El numero tiene un bit extra
		10 => "0000000000000000"  -- Salto directo sin comprobacion
	);
	
	CONSTANT INSTRUCTIONS : list := (
	
		-- Comienza el juego del gato
		0  => ("0000"&"0000"&"0000"&"0000"), -- 
		1  => ("0000"&"0000"&"0000"&"0000"), --  
		2  => ("0000"&"0000"&"0000"&"0000"), -- 
		3  => ("0000"&"0000"&"0000"&"0000"), -- 
		4  => ("0000"&"0000"&"0000"&"0000"), --  
		5  => ("0000"&"0000"&"0000"&"0000"), -- 
		6  => ("0000"&"0000"&"0000"&"0000"), --
		7  => ("0000"&"0000"&"0000"&"0000"), --
		8  => ("0000"&"0000"&"0000"&"0000"), -- 
		9  => ("0000"&"0000"&"0000"&"0000"), -- 
		10 => ("0000"&"0000"&"0000"&"0000"), -- 
		11 => ("0000"&"0000"&"0000"&"0000"), -- 
		12 => ("0000"&"0000"&"0000"&"0000"), -- 
		13 => ("0000"&"0000"&"0000"&"0000"), -- 
		14 => ("0000"&"0000"&"0000"&"0000"), -- 
		15 => ("0000"&"0000"&"0000"&"0000"), -- 
		16 => ("0000"&"0000"&"0000"&"0000"), -- 
		17 => ("0000"&"0000"&"0000"&"0000"), -- 
		18 => ("0000"&"0000"&"0000"&"0000"), -- 
		19 => ("0000"&"0000"&"0000"&"0000"), -- 
		20 => ("0000"&"0000"&"0000"&"0000"), -- 
		21 => ("0000"&"0000"&"0000"&"0000"), -- 
		22 => ("0000"&"0000"&"0000"&"0000"), --
		23 => ("0000"&"0000"&"0000"&"0000"), --
		24 => ("0000"&"0000"&"0000"&"0000"), --
		25 => ("0000"&"0000"&"0000"&"0000"), --
		26 => ("0000"&"0000"&"0000"&"0000"), --
		27 => ("0000"&"0000"&"0000"&"0000"), --
		28 => ("0000"&"0000"&"0000"&"0000"), --
		29 => ("0000"&"0000"&"0000"&"0000"), --
		30 => ("0000"&"0000"&"0000"&"0000"), -- 
		31 => ("0000"&"0000"&"0000"&"0000"), -- 
		32 => ("0000"&"0000"&"0000"&"0000"), -- 
		33 => ("0000"&"0000"&"0000"&"0000"), -- 
		34 => ("0000"&"0000"&"0000"&"0000"), -- 
		35 => ("0000"&"0000"&"0000"&"0000"), -- 
		36 => ("0000"&"0000"&"0000"&"0000"), -- 
		37 => ("0000"&"0000"&"0000"&"0000"), -- 
		38 => ("0000"&"0000"&"0000"&"0000"), -- 
		39 => ("0000"&"0000"&"0000"&"0000"), -- 
		40 => ("0000"&"0000"&"0000"&"0000"), -- 
		41 => ("0000"&"0000"&"0000"&"0000"), -- 
		42 => ("0000"&"0000"&"0000"&"0000"), -- 
		43 => ("0000"&"0000"&"0000"&"0000"), -- 
		44 => ("0000"&"0000"&"0000"&"0000"), -- 
		45 => ("0000"&"0000"&"0000"&"0000"), -- 
		46 => ("0000"&"0000"&"0000"&"0000"), -- 
		47 => ("0000"&"0000"&"0000"&"0000"), -- 
		48 => ("0000"&"0000"&"0000"&"0000"), -- 
		49 => ("0000"&"0000"&"0000"&"0000"), -- 
		50 => ("0000"&"0000"&"0000"&"0000"), -- 
		51 => ("0000"&"0000"&"0000"&"0000")  -- 
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
							REG_D <= values(to_integer(unsigned(MAR(3 DOWNTO 0))));
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
							s1 <= REG_A;
							REG_B <= reggy(to_integer(unsigned(MAR(3 DOWNTO 0))));
							s2 <= REG_B;
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
					END IF;
				
				WHEN state3 => 
					IF (reggy(0)(15) = '1') THEN
						salida <= '0' & reggy(0)(14 DOWNTO 0);
						z_flag <= zflag;
						s_flag <= '1';
						ov_flag <= ovflag;
						c_flag <= cflag;
					ELSE
						salida <= reggy(0);
						z_flag <= zflag;
						s_flag <= sflag;
						ov_flag <= ovflag;
						c_flag <= cflag;
					END IF;
					pr_state <= state3;
			END CASE;
		END IF;
		ins <= MAR;
	END PROCESS;
	alu1: ALU PORT MAP(REG_A, REG_B, OP, MBR, clk, rst, zflag, sflag, ovflag, cflag);
END ARCHITECTURE;