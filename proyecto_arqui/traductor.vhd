LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY Traductor IS PORT(
	enter : IN std_logic;
	Entrada : IN std_logic_vector(8 DOWNTO 0);
	Salida : OUT std_logic_vector(15 DOWNTO 0)
);
END ENTITY Traductor;

ARCHITECTURE trad OF Traductor IS 
Begin
	PROCESS(enter) IS
	Begin
			IF (enter = '0') THEN
				Salida <= "0000000000000000";
			ELSE
				Salida <= "0000000" & Entrada(8 DOWNTO 0);
			END IF;
		END PROCESS;
END ARCHITECTURE;