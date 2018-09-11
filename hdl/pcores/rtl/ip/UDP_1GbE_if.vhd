----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    17:52:01 04/27/2015 
-- Design Name: 
-- Module Name:    UDP_1Gbe_Core - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity UDP_1GbE_if is
	port(
		GIGE_COL			: in std_logic;
		GIGE_CRS			: in std_logic;
		GIGE_MDC			: out std_logic;
		GIGE_MDIO		: inout std_logic;
		GIGE_TX_CLK	   : in std_logic;
		GIGE_nRESET	   : out std_logic;
		GIGE_RXD			: in std_logic_vector( 7 downto 0 );
		GIGE_RX_CLK		: in std_logic;
		GIGE_RX_DV		: in std_logic;
		GIGE_RX_ER		: in std_logic;
		GIGE_TXD			: out std_logic_vector( 7 downto 0 );
		GIGE_GTX_CLK 	: out std_logic;
		GIGE_TX_EN		: out std_logic;
		GIGE_TX_ER		: out std_logic;
		
		dcm_100mhz_in	: in std_logic;
--		sys_clk_p      : in  std_logic;
--		sys_clk_n      : in  std_logic;
		sys_rst_i      : in  std_logic;
		send_packet		: in	std_logic
	);
end UDP_1GbE_if;

architecture Behavioral of UDP_1GbE_if is
	
	---------------------------------------------------------------------------
	--	Signal declaration section 
	---------------------------------------------------------------------------
	
	attribute S: string;
	attribute keep : string;
	
	attribute S of GIGE_RXD   : signal is "TRUE";
	attribute S of GIGE_RX_DV : signal is "TRUE";
	attribute S of GIGE_RX_ER : signal is "TRUE";
	
	-- define constants
	constant UDP_TX_DATA_BYTE_LENGTH : integer := 16;		--not SET TO MINIMUM LENGTH
	constant UDP_RX_DATA_BYTE_LENGTH : integer := 37;
	constant TX_DELAY						: integer := 10;
	
	-- system control
	signal clk_125mhz   : std_logic;
	signal clk_100mhz    : std_logic;
	signal clk_25mhz    : std_logic;
	signal sys_reset     : std_logic;
	signal sysclk_locked : std_logic;
	
	-- MAC signals
	signal udp_tx_pkt_data  : std_logic_vector (8 * UDP_TX_DATA_BYTE_LENGTH - 1 downto 0);
	signal udp_tx_pkt_vld : std_logic;
	signal udp_tx_pkt_sent  : std_logic;
	signal udp_tx_pkt_vld_r : std_logic;
	signal udp_tx_rdy		: std_logic;
			
	signal udp_rx_pkt_data  : std_logic_vector(8 * UDP_RX_DATA_BYTE_LENGTH - 1 downto 0);
	signal udp_rx_pkt_data_r: std_logic_vector(8 * UDP_RX_DATA_BYTE_LENGTH - 1 downto 0);
	signal udp_rx_pkt_req   : std_logic;
   signal udp_rx_rdy			: std_logic;
	signal udp_rx_rdy_r  	: std_logic;
	
	signal dst_mac_addr     : std_logic_vector(47 downto 0);
	signal tx_state			: std_logic_vector(2 downto 0) := "000";
	signal rx_state			: std_logic_vector(2 downto 0) := "000";
	signal locked				: std_logic;
	signal mac_init_done		: std_logic;
	signal GIGE_GTX_CLK_r   : std_logic;
	signal GIGE_MDC_r			: std_logic;
	
	signal tx_delay_cnt		: integer := 0;
	
--	signal sys_rst				: std_logic := '1';
	
	---------------------------------------------------------------------------
	--	Component declaration section 
	---------------------------------------------------------------------------
	component clk_manager is
	port(
		--External Control
		dcm_100mhz_in : in std_logic;
--		SYS_CLK_P_i  : in  std_logic;
--		SYS_CLK_N_i  : in  std_logic;
		SYS_RST_i    : in  std_logic;

		-- Clock out ports
		clk_125mhz    : out std_logic;
		clk_100mhz    : out std_logic;	
		clk_25mhz     : out std_logic;
		
		-- Status and control signals
		RESET         : out std_logic;
		sysclk_locked : out std_logic
	);
	end component clk_manager;
	
	component UDP_1GbE is
	  generic(
			UDP_TX_DATA_BYTE_LENGTH : natural := 1;
			UDP_RX_DATA_BYTE_LENGTH : natural:= 1
	 );
	 port(
			-- user logic interface
			own_ip_addr		   : in std_logic_vector (31 downto 0);
			own_mac_addr      : in std_logic_vector (47 downto 0);
			dst_ip_addr       : in std_logic_vector (31 downto 0);
			dst_mac_addr      : in std_logic_vector(47 downto 0);

			udp_src_port  		: in std_logic_vector (15 downto 0);
			udp_dst_port      : in std_logic_vector (15 downto 0);

			udp_tx_pkt_data	: in  std_logic_vector (8 * UDP_TX_DATA_BYTE_LENGTH - 1 downto 0);
			udp_tx_pkt_vld    : in  std_logic;
			udp_tx_rdy			: out std_logic;

			udp_rx_pkt_data   : out std_logic_vector(8 * UDP_RX_DATA_BYTE_LENGTH - 1 downto 0);
			udp_rx_pkt_req    : in  std_logic;
			udp_rx_rdy		   : out std_logic;

			mac_init_done	   : out std_logic;	
					
			-- MAC interface
			GIGE_COL			: in std_logic;
			GIGE_CRS			: in std_logic;
			GIGE_MDC			: out std_logic;
			GIGE_MDIO	   : inout std_logic;
			GIGE_TX_CLK	   : in std_logic;
			GIGE_nRESET	   : out std_logic;
			GIGE_RXD			: in std_logic_vector( 7 downto 0 );
			GIGE_RX_CLK		: in std_logic;
			GIGE_RX_DV		: in std_logic;
			GIGE_RX_ER		: in std_logic;
			GIGE_TXD			: out std_logic_vector( 7 downto 0 );
			GIGE_GTX_CLK 	: out std_logic;
			GIGE_TX_EN		: out std_logic;
			GIGE_TX_ER		: out std_logic;
			
			-- system control
			clk_125mhz     : in  std_logic;
			clk_100mhz     : in  std_logic;
			sys_rst_i      : in  std_logic;
			sysclk_locked  : in  std_logic
	  );
	end component UDP_1GbE;

	
begin

	UDP_1GbE_inst : UDP_1GbE 	  
	generic map(
			UDP_TX_DATA_BYTE_LENGTH => UDP_TX_DATA_BYTE_LENGTH,
			UDP_RX_DATA_BYTE_LENGTH => UDP_RX_DATA_BYTE_LENGTH
	 )
	port map(
			-- user logic interface
			own_ip_addr		   => x"c0a86b1c",	-- 192.168.107.28
			own_mac_addr      => x"0e0e0e0e0e0b",
			dst_ip_addr       => x"c0a86b1d",	-- 192.168.107.29
			dst_mac_addr      => x"0e0e0e0e0e0c",
			
			-- mac's MAC is x"406c8f0012cd"
			-- REx's MAC is x"0e0e0e0e0e0c"
			
			udp_src_port  		=> x"1f40", --8000
			udp_dst_port      => x"1f43", --8003
			
			udp_tx_pkt_data	=> udp_tx_pkt_data,
			udp_tx_pkt_vld    => udp_tx_pkt_vld,
			udp_tx_rdy		   => udp_tx_rdy,
			
			udp_rx_pkt_data   => udp_rx_pkt_data,
			udp_rx_pkt_req    => udp_rx_pkt_req,
			udp_rx_rdy		   => udp_rx_rdy,
			
			mac_init_done	   => mac_init_done,	
			
			-- MAC interface
			GIGE_COL			=> GIGE_COL,
			GIGE_CRS			=> GIGE_CRS,
			GIGE_MDC			=> GIGE_MDC,
			GIGE_MDIO	   => GIGE_MDIO,
			GIGE_TX_CLK	   => GIGE_TX_CLK,
			GIGE_nRESET	   => GIGE_nRESET,
			GIGE_RXD			=> GIGE_RXD,
			GIGE_RX_CLK		=> GIGE_RX_CLK,
			GIGE_RX_DV		=> GIGE_RX_DV,
			GIGE_RX_ER		=> GIGE_RX_ER,
			GIGE_TXD			=> GIGE_TXD,
			GIGE_GTX_CLK 	=> GIGE_GTX_CLK,
			GIGE_TX_EN		=> GIGE_TX_EN,
			GIGE_TX_ER		=> GIGE_TX_ER,
			
			-- system control
			clk_125mhz     => clk_125mhz,
			clk_100mhz     => clk_100mhz,
			sys_rst_i      => sys_reset,
			sysclk_locked  => sysclk_locked
	  );	 
	  
	  clk_manager_inst : clk_manager 
		port map(
			--External Control
			dcm_100mhz_in => dcm_100mhz_in,
--			SYS_CLK_P_i  => sys_clk_p,
--			SYS_CLK_N_i  => sys_clk_n,
			SYS_RST_i    => sys_rst_i,

			-- Clock out ports
			clk_125mhz    => clk_125mhz,
			clk_100mhz    => clk_100mhz,
			clk_25mhz     => clk_25mhz,
			
			-- Status and control signals
			RESET         => sys_reset,
			sysclk_locked => sysclk_locked 
		);
		
		-----------------------------------------------------------------------
		--				Enables Transmission
		-----------------------------------------------------------------------
		
		
		-----------------------------------------------------------------------
		--				UDP TRANSMISSION SECTION
		-----------------------------------------------------------------------
		tx_proc : process(sys_rst_i,clk_100mhz)
	  begin
			
			if(sys_rst_i = '1') then
			elsif(rising_edge(clk_100mhz)) then
				case tx_state is
					when "000" =>
						tx_delay_cnt <= 0;
						if(udp_tx_rdy = '1') then
							tx_state <= "001";															
						end if;
					when "001" =>
						if(udp_tx_rdy = '1') then
						
						
--							if(tx_delay_cnt = TX_DELAY) then
--								tx_delay_cnt <= 0;
								if (send_packet = '1') then
									udp_tx_pkt_vld_r <= '1';
									udp_tx_pkt_data  <= x"0d000000000004000300140534210000";
								else
									udp_tx_pkt_vld_r <= '0';
								end if;
								
								
--							else
--							   udp_tx_pkt_vld_r <= '0';
--								tx_delay_cnt <= tx_delay_cnt + 1;
--							end if;
							
							
						else
							tx_state <= "000";	
						end if;
					when others =>
						null;
				end case;
			end if;
			
			
	  end process;
	  	  
	  udp_tx_pkt_vld <= udp_tx_pkt_vld_r;
	  
	  --udp_tx_pkt_data  <= x"0d000000000004000300140534210000";
	  
	  -----------------------------------------------------------------------
		--				UDP RECEPTION SECTION
		-----------------------------------------------------------------------
	  rx_proc : process(sys_rst_i,clk_100mhz)
	  begin
			if(sys_rst_i = '1') then
				null;
			elsif(rising_edge(clk_100mhz)) then
				case rx_state is
					when "000" =>
						udp_rx_pkt_req <= '1';
						udp_rx_rdy_r <= udp_rx_rdy;
						rx_state <= "001";	
					when "001" =>
						if(udp_rx_rdy = '1') then
							udp_rx_pkt_data_r <= udp_rx_pkt_data;
							udp_rx_rdy_r <= udp_rx_rdy;
							rx_state <= "010";	
						end if;
					when "010" =>						
						udp_rx_pkt_data_r <= (others => '0');
						rx_state <= "000";	
						udp_rx_rdy_r <= udp_rx_rdy;
					when others =>
						null;
				end case;
			end if;
	  end process;

		 	 
end Behavioral;

