----------------------------------------------------------------------------------
-- Company: Open Research Institute, Inc.
-- Engineer: Skunkwrx, Abraxas3d
-- 
-- Design Name: COBS protocol decoder
-- Module Name: decoder - Behavioral
-- Project Name: Phase 4 "Haifuraiya"
-- Target Devices: 7000 Zynq
-- Tool Versions: 2021.1
-- Description: COBS protocol decoder. 
--              https://en.wikipedia.org/wiki/Consistent_Overhead_Byte_Stuffing
-- 
-- Dependencies: 
--Additional Comments: This work is Open Source and licensed using CERN OHL v2.0
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.NUMERIC_STD.ALL;

--Entity Declaration
entity decoder is
    Port ( rst      : in STD_LOGIC;
           clk      : in STD_LOGIC;
           s_tdata  : in STD_LOGIC_VECTOR (7 downto 0);
           s_tlast  : in STD_LOGIC;
           s_tvalid : in STD_LOGIC;
           s_tready : out STD_LOGIC;
           m_tdata  : out STD_LOGIC_VECTOR (7 downto 0);
           m_tlast  : out STD_LOGIC;
           m_tvalid : out STD_LOGIC;
           m_tready : in STD_LOGIC);
end decoder;

--Architecture
architecture Behavioral of decoder is

	-- internal copy of s_tdata
    signal input_data          : STD_LOGIC_VECTOR (7 downto 0);

    -- s_tdata delayed by one clk where s_tvalid is high
    signal input_data_d        : STD_LOGIC_VECTOR (7 downto 0);

    -- internal version of s_tlast
    -- not used for anything
    -- We create our own m_tlast from the COBS framing instead
    signal s_tlast_i           : STD_LOGIC;

    -- internal version of input handshaking signal s_tvalid
    signal s_tvalid_i          : STD_LOGIC;

    -- s_tvalid delayed by one clk
    -- thus, a version of s_tvalid aligned with input_data_d
    signal s_tvalid_i_d        : STD_LOGIC;

    -- s_tvalid delayed by two clks
    -- thus, a version of s_tvalid aligned with output_data
    signal s_tvalid_i_d_d      : STD_LOGIC;
    
    -- countdown of bytes in this sequence
    -- loads from input_data_d when it represents the frame count
    --   as determined by signal counter_load
    -- contains the count while m_tdata contains the implied 0 at
    --   the end of a sequence, or the next count that replaced it
    -- counts down thereafter, to contain 1 when the last non-zero
    --   byte of the sequence is on m_tdata
    -- allowed to count down to 0, but not beyond
    signal count               : STD_LOGIC_VECTOR (7 downto 0);

	-- enable to load count from input_data_d on this clk edge
	-- two cases detected:
	--    * first valid non-zero byte after a frame separator
	--    * first valid byte after count is exhausted
	-- allowed to be high for multiple cycles
    signal counter_load        : STD_LOGIC;

    -- counter_load delayed by one clk where s_tvalid is high
    -- used to identify the first valid data byte of any sequence,
    --   for purposes of computing m_tvalid (via pre_tvalid)
    signal counter_load_d      : STD_LOGIC;

    -- detection of a valid frame separator (zero) byte in input_data_d
    signal frame_sep           : STD_LOGIC;

    -- frame_sep delayed by one clk where s_tvalid is high
    -- used to compute counter_load
    -- used to compute rising edge of pre_tvalid
    signal frame_sep_d         : STD_LOGIC;
    
    -- frame_sep_d delayed by an additional clk (not depending on s_tvalid)
    -- used to find the first non-zero byte of the new frame
    signal frame_sep_d_d       : STD_LOGIC;
        
    -- move the frame_sep signal that occurred during m_tready low
    -- out to the first cycle when m_tready is high again
    signal use_saved_frame_sep : STD_LOGIC;

    -- flag to remember that the frame count for this sequence was 255,
    --   to handle the special case that such a sequence does not have
    --   an implied zero byte at the end.
    -- set when loading count with 255
    -- cleared when the counter is reloaded with anything else
    signal case_255            : STD_LOGIC;

    -- internal version of m_tdata output
    signal output_data         : STD_LOGIC_VECTOR (7 downto 0);

    -- internal version of m_tlast output
    -- high when the last byte of a frame is valid on m_tdata
    signal m_tlast_i           : STD_LOGIC;

    -- delayed versions of m_tlast
    signal m_tlast_i_d         : STD_LOGIC;
    signal m_tlast_i_d_d       : STD_LOGIC;

    -- intermediate result for m_tvalid.
    -- high across all data bytes of each sequence on m_tdata
    -- does not go low for bytes on m_tdata corresponding to
    --   bytes invalidated by s_tvalid.
    signal pre_tvalid          : STD_LOGIC;

    -- internal version of m_tvalid output.
    -- pre_tvalid with periods of low s_tvalid_d_d punched out
    signal m_tvalid_i          : STD_LOGIC;

    -- internal version of m_tready input
    -- also the internal version of s_tready output
    -- passes through m_tready to s_tready with no clk delays
    signal m_tready_i          : STD_LOGIC;

    -- constant byte value 0xFF, for comparison purposes
    signal all_ones            : STD_LOGIC_VECTOR(input_data'range) := (others => '1');

    -- constant byte value 0x00, for comparison purposes
    signal all_zeros           : STD_LOGIC_VECTOR(input_data'range) := (others => '0');

begin

    -- asynchronous assignments
    
    frame_sep <= '1' when input_data_d = all_zeros and s_tvalid_i_d = '1'
                else '0';
    
    m_tlast_i <= '1' when ((frame_sep = '1' and m_tvalid_i = '1' and m_tready = '1'))
                else '0';
    
    counter_load <= '1' when (input_data_d /= all_zeros and frame_sep_d = '1' and s_tvalid_i_d = '1')   -- start of frame
                          or (to_integer(unsigned(count)) = 1 and s_tvalid_i_d = '1')   -- start of next sequence in frame
                else '0';
    
    m_tvalid_i <= '1' when ((pre_tvalid = '1' and s_tvalid_i_d_d = '1'    -- usual case, if input_data was valid
                        and not (to_integer(unsigned(count)) = 1 and s_tvalid_i_d = '0')) -- defer last byte; might be m_tlast
                      or (pre_tvalid = '1' and to_integer(unsigned(count)) = 1
                        and s_tvalid_i_d = '1' and s_tvalid_i_d_d = '0')) -- pick up that deferred last byte
                else '0';
                
    
    s_tready <= m_tready_i;
    m_tdata <= output_data;
    input_data <= s_tdata;
    s_tvalid_i <= s_tvalid;
    m_tready_i <= m_tready;
    m_tvalid <= m_tvalid_i;
    m_tlast <= m_tlast_i;
    
-- processes



    set_case_255 : process (rst, clk)
    begin
        if rst = '1' then
            case_255 <= '0';
        elsif rising_edge(clk) and m_tready_i = '1' then
            if counter_load = '1' and input_data_d = all_ones then
                case_255 <= '1';
            elsif counter_load = '1' and input_data_d /= all_ones then
                case_255 <= '0';
            end if;
        end if;
    end process set_case_255;


    
    delay_s_tvalid : process (rst, clk)
    begin
        if rst = '1' then
            s_tvalid_i_d <= '0';
            s_tvalid_i_d_d <= '0';
        elsif rising_edge(clk) and m_tready_i = '1' then
            s_tvalid_i_d <= s_tvalid_i;             
            s_tvalid_i_d_d <= s_tvalid_i_d;
        end if;
    end process delay_s_tvalid;
    
    
    
    create_pre_tvalid : process (rst, clk)
    begin
        if rst = '1' then
            counter_load_d <= '0';
            pre_tvalid <= '0';
        elsif rising_edge(clk) and m_tready_i = '1' then
            if s_tvalid_i_d = '1' then
                counter_load_d <= counter_load;
                if (frame_sep_d_d = '1' and frame_sep_d = '0')            -- normal last byte of frame 
                or (counter_load_d = '1' and frame_sep_d = '0')           -- normal first byte of a sequence
                then       
                    pre_tvalid <= '1';
                end if;
            end if;
            if frame_sep = '1'
            then
                pre_tvalid <= '0';
            end if;
            if counter_load = '1' and case_255 = '1' then
                pre_tvalid <= '0';
            end if;
        end if;
    end process create_pre_tvalid;
     
     

    delay_m_tlast_i : process (rst, clk)
    begin
        if rst = '1' then
            m_tlast_i_d <= '0';
            m_tlast_i_d_d <= '0';
        elsif rising_edge(clk) and m_tready_i = '1' then
            m_tlast_i_d <= m_tlast_i;
            m_tlast_i_d_d <= m_tlast_i_d;
        end if;
    end process delay_m_tlast_i;



    set_counter : process (rst,clk)
    begin
        if rst = '1' then
            count <= (others => '0');
            frame_sep_d <= '0';
            frame_sep_d_d <= '0';
        elsif rising_edge(clk) and m_tready_i = '1' then
            frame_sep_d_d <= frame_sep_d;
            if s_tvalid_i_d = '1' then
                frame_sep_d <= frame_sep;
                if counter_load = '1' then 
                    count <= input_data_d;
                elsif count /= all_zeros
                then
                    count <= STD_LOGIC_VECTOR(unsigned(count) - 1);
                end if;
            end if;
        end if;
    end process set_counter;
    
    
    
    create_output : process (rst, clk)
    begin
        if rst = '1' then
            output_data <= (others => '0');
        elsif rising_edge(clk) and m_tready_i = '1' then
            if counter_load = '1'
            then
                output_data <= all_zeros;
            elsif s_tvalid_i_d = '1' then
                output_data <= input_data_d;                
            end if;
        end if;
    end process create_output;
    
  
    
    selective_delay_of_input_data : process (rst,clk)
    begin
        if rst = '1' then
            input_data_d <= all_zeros;
        elsif rising_edge(clk) and m_tready_i = '1' then
            if s_tvalid_i = '1' then
                input_data_d <= input_data;
            end if;    
        end if;
    end process selective_delay_of_input_data;
    

end Behavioral;

