----------------------------------------------------------------------------------
-- Company: Open Research Institute, Inc.
-- Engineer: Skunkwrx and Abraxas3d
-- 
-- Design Name: 
-- Module Name: decoder_tb - Behavioral
-- Project Name: Phase 4, Haifuraiya
-- Target Devices: 
-- Tool Versions: Vivado 2021.1
-- Description: 
-- 
-- Dependencies: 
-- 
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- In order to read test vectors in from a file
use std.textio.all;
use ieee.std_logic_textio.all;

entity decoder_tb is
--  Port ( );
end decoder_tb;

architecture Behavioral of decoder_tb is

component decoder is
   port(
   rst      : in STD_LOGIC;
   clk      : in STD_LOGIC;
   s_tdata  : in STD_LOGIC_VECTOR (7 downto 0);
   s_tlast  : in STD_LOGIC;
   s_tvalid : in STD_LOGIC;
   s_tready : out STD_LOGIC;
   m_tdata  : out STD_LOGIC_VECTOR (7 downto 0);
   m_tlast  : out STD_LOGIC;
   m_tvalid : out STD_LOGIC;
   m_tready : in STD_LOGIC);
end component decoder;

    signal rst : STD_LOGIC;
    signal clk : STD_LOGIC := '0';
    signal input_data : STD_LOGIC_VECTOR (7 downto 0);
    signal s_tlast : STD_LOGIC;
    signal s_tvalid : STD_LOGIC := '1';
    signal s_tready : STD_LOGIC;
    signal output_data : STD_LOGIC_VECTOR (7 downto 0);
    signal m_tlast : STD_LOGIC;
    signal m_tvalid : STD_LOGIC;
    signal m_tready : STD_LOGIC;
   

begin

DUT : decoder 

port map(
    clk => clk,
    rst => rst,
    s_tdata => input_data,
    s_tlast => s_tlast,
    s_tvalid => s_tvalid,
    s_tready => s_tready,
    m_tdata => output_data,
    m_tlast => m_tlast,
    m_tvalid => m_tvalid,
    m_tready => m_tready);
   
-- please visit the friendly people at 
-- https://surf-vhdl.com/read-from-file-in-vhdl-using-textio-library/
-- for helpful examples

p_read : process
--------------------------------------------------------------------------------------------------
file test_vector                : text open read_mode is "cobs-test.txt";
--file test_vector                : text open read_mode is "kb5mu-cobs-test";
--file test_vector                : text open read_mode is "COBS_dec-tv-in-b4f69311";
--file test_vector                : text open read_mode is "COBS_dec-tv-in-67c041aa"
--file test_vector                : text open read_mode is "COBS_dec-tv-in-6dc71d1e";
--file test_vector                : text open read_mode is "COBS_dec-tv-in-d98b7d1e";
--file test_vector                : text open read_mode is "COBS_dec-tv-in-d38ef41e";
variable row                    : line;
variable v_data_read            : integer := 0;
variable validity               : integer := 0;
variable readiness              : integer := 0;
variable resetting              : integer := 0;

file output_vector              : text open write_mode is "cobs-test-output.txt";
variable output_row             : line;

begin

    -- read from input file in "row" variable
    -- input data, s_tvalid, s_tready, rst
    while not endfile(test_vector) loop
    readline(test_vector, row);
    -- Skip empty lines and single-line comments
    if row.all'length = 0 or row.all(1) = '-' then
        next;
    end if;

    read(row,v_data_read);
    input_data <= STD_LOGIC_VECTOR(TO_UNSIGNED(v_data_read,8));
    
    read(row, validity);
    s_tvalid <= to_unsigned(validity,1)(0);
    
    read(row, readiness);
    m_tready <= to_unsigned(readiness,1)(0);
    
    read(row, resetting);
    rst <= to_unsigned(resetting,1)(0);
   
    
    clk <= '1';
    wait for 1 NS;
    clk <= '0';
    wait for 1 NS;
    
    
-- make a header for the output file whenever we get a reset signal
    
    if rst = '1' then
        write(output_row, string'("-- rst input_data s_tlast s_tvalid s_tready output_data m_tlast m_tvalid m_tready"));  
        writeline(output_vector, output_row);
    end if;
    
-- things we write to our output file
--    signal rst : STD_LOGIC;
--    signal input_data : STD_LOGIC_VECTOR (7 downto 0);
--    signal s_tlast : STD_LOGIC;
--    signal s_tvalid : STD_LOGIC := '1'; 
--    signal s_tready : STD_LOGIC;
--    signal output_data : STD_LOGIC_VECTOR (7 downto 0);
--    signal m_tlast : STD_LOGIC;
--    signal m_tvalid : STD_LOGIC;
--    signal m_tready : STD_LOGIC;
    
    write(output_row, rst, right, 2);
    write(output_row, input_data, right, 9);
    write(output_row, s_tlast, right, 2);
    write(output_row, s_tvalid, right, 2);
    write(output_row, s_tready, right, 2);
    write(output_row, output_data, right, 9);
    write(output_row, m_tlast, right, 2);
    write(output_row, m_tvalid, right, 2);
    write(output_row, m_tready, right, 2);
    writeline(output_vector, output_row);    
    
    end loop;

end process p_read;       

end Behavioral;



