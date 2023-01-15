LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY Traductor IS PORT(
	Entrada : IN std_logic_vector(5 DOWNTO 0);
	Salida : OUT std_logic_vector(15 DOWNTO 0)
);
END ENTITY Traductor;

ARCHITECTURE trad OF Traductor IS 
	Begin
		Salida <= "0000000000"&Entrada(5 DOWNTO 0);
END ARCHITECTURE;