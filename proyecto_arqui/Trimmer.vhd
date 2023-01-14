LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY Trimmer IS PORT(
	I : IN std_logic_vector(15 DOWNTO 0);
	O : OUT std_logic_vector(8 DOWNTO 0)
);
END ENTITY Trimmer;

ARCHITECTURE trimm OF Trimmer IS
	Begin
		O <= I(8 DOWNTO 0);
END ARCHITECTURE;