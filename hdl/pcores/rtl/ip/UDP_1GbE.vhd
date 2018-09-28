----------------------------------------------------------------------
-- Title      : 1 Gbe UDP network implementation with
--                     open-cores tri-mac-core on RHINO
----------------------------------------------------------------------
-- Project    : RHINO SDR Processing Blocks
----------------------------------------------------------------------
--
-- Author     : Lekhobola Tsoeunyane
-- Company    : University Of Cape Town
-- Email      : lekhobola@gmail.com
----------------------------------------------------------------------
-- Features
-- 1) Marvell 88E1111S initialization
-- 2) UDP packet transmission and reception
-- 2) Adopting the tri-mac-core to work on RHINO board.

-- Date: 01 March 2015
-- Revision: 01 November 2016
----------------------------------------------------------------------

----------------------------------------------------------------------
-- Description:
----------------------------------------------------------------------
----                                                              ----
---- Copyright (C) 2013 Steffen Mauch                             ----
----     steffen.mauch (at) gmail.com                             ----
----                                                              ----
---- This source file may be used and distributed without         ----
---- restriction provided that this copyright statement is not    ----
---- removed from the file and that any derivative work contains  ----
---- the original copyright notice and the associated disclaimer. ----
----                                                              ----
---- This source file is free software; you can redistribute it   ----
---- and/or modify it under the terms of the GNU Lesser General   ----
---- Public License as published by the Free Software Foundation; ----
---- either version 2.1 of the License, or (at your option) any   ----
---- later version.                                               ----
----                                                              ----
---- This source is distributed in the hope that it will be       ----
---- useful, but WITHOUT ANY WARRANTY; without even the implied   ----
---- warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ----
---- PURPOSE.  See the GNU Lesser General Public License for more ----
---- details.                                                     ----
----                                                              ----
---- You should have received a copy of the GNU Lesser General    ----
---- Public License along with this source; if not, download it   ----
---- from http://www.opencores.org/lgpl.shtml                     ----
----                                                              ----
----------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

Library UNISIM;
use UNISIM.vcomponents.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.math_real.all;

entity UDP_1GbE is
    generic(
        UDP_TX_DATA_BYTE_LENGTH : natural := 1;
        UDP_RX_DATA_BYTE_LENGTH : natural:= 1
    );
    port(
        -- user logic interface
        own_ip_addr     : in    std_logic_vector(31 downto 0);
        own_mac_addr    : in    std_logic_vector(47 downto 0);
        dst_ip_addr     : in    std_logic_vector(31 downto 0);
        dst_mac_addr    : in    std_logic_vector(47 downto 0);

        udp_src_port    : in    std_logic_vector(15 downto 0);
        udp_dst_port    : in    std_logic_vector(15 downto 0);

        udp_tx_pkt_data : in    std_logic_vector(8 * UDP_TX_DATA_BYTE_LENGTH - 1 downto 0);
        udp_tx_pkt_vld  : in    std_logic;
        udp_tx_rdy      : out   std_logic;

        udp_rx_pkt_data : out   std_logic_vector(8 * UDP_RX_DATA_BYTE_LENGTH - 1 downto 0);
        udp_rx_pkt_req  : in    std_logic;
        udp_rx_rdy      : out   std_logic;

        mac_init_done   : out   std_logic;

        -- MAC interface
        GIGE_COL        : in    std_logic;
        GIGE_CRS        : in    std_logic;
        GIGE_MDC        : out   std_logic;
        GIGE_MDIO       : inout std_logic;
        GIGE_TX_CLK     : in    std_logic;
        GIGE_nRESET     : out   std_logic;
        GIGE_RXD        : in    std_logic_vector( 7 downto 0 );
        GIGE_RX_CLK     : in    std_logic;
        GIGE_RX_DV      : in    std_logic;
        GIGE_RX_ER      : in    std_logic;
        GIGE_TXD        : out   std_logic_vector( 7 downto 0 );
        GIGE_GTX_CLK    : out   std_logic;
        GIGE_TX_EN      : out   std_logic;
        GIGE_TX_ER      : out   std_logic;

        -- system control
        clk_125mhz      : in    std_logic;
        clk_62_5mhz     : in    std_logic;
        sys_rst_i       : in    std_logic;
        sysclk_locked   : in    std_logic
    );
end UDP_1GbE;

architecture arc of UDP_1GbE is

    component MAC_top
    port(
        --//system signals
        Reset               : in  std_logic;
        Clk_125M            : in  std_logic;
        Clk_user            : in  std_logic;
        Clk_reg             : in  std_logic;
        Speed               : out std_logic_vector( 2 downto 0);
        --//user interface
        Rx_mac_ra           : out std_logic;
        Rx_mac_rd           : in  std_logic;
        Rx_mac_data         : out std_logic_vector( 31 downto 0 );
        Rx_mac_BE           : out std_logic_vector( 1 downto 0 );
        Rx_mac_pa           : out std_logic;
        Rx_mac_sop          : out std_logic;
        Rx_mac_eop          : out std_logic;
        --//user interface
        Tx_mac_wa           : out std_logic;
        Tx_mac_wr           : in  std_logic;
        Tx_mac_data         : in  std_logic_vector( 31 downto 0 );
        Tx_mac_BE           : in  std_logic_vector( 1 downto 0 );--//big endian
        Tx_mac_sop          : in  std_logic;
        Tx_mac_eop          : in  std_logic;
        --//pkg_lgth fifo
        Pkg_lgth_fifo_rd    : in  std_logic;
        Pkg_lgth_fifo_ra    : out std_logic;
        Pkg_lgth_fifo_data  : out std_logic_vector( 15 downto 0 );
        --//Phy interface
        Gtx_clk             : out std_logic;--//used only in GMII mode
        Rx_clk              : in  std_logic;
        Tx_clk              : in  std_logic; --//used only in MII mode
        Tx_er               : out std_logic;
        Tx_en               : out std_logic;
        Txd                 : out std_logic_vector( 7 downto 0 );
        Rx_er               : in  std_logic;
        Rx_dv               : in  std_logic;
        Rxd                 : in  std_logic_vector( 7 downto 0 );
        Crs                 : in  std_logic;
        Col                 : in  std_logic;
        --//host interface
        CSB                 : in  std_logic;
        WRB                 : in  std_logic;
        CD_in               : in  std_logic_vector( 15 downto 0 );
        CD_out              : out std_logic_vector( 15 downto 0 );
        CA                  : in  std_logic_vector( 7 downto 0 );
        -- mdx
        Mdo                 : out std_logic; --// MII Management Data Output
        MdoEn               : out std_logic; --// MII Management Data Output Enable
        Mdi                 : in  std_logic;
        Mdc                 : out std_logic; --// MII Management Data Clock
        -- MII to CPU
        Divider             : in   std_logic_vector(7 downto 0);
        CtrlData            : in   std_logic_vector(15 downto 0);
        Rgad                : in   std_logic_vector(4 downto 0);
        Fiad                : in   std_logic_vector(4 downto 0);
        NoPre               : in   std_logic;
        WCtrlData           : in   std_logic;
        RStat               : in   std_logic;
        ScanStat            : in   std_logic;
        Busy                : out  std_logic;
        LinkFail            : out  std_logic;
        Nvalid              : out  std_logic;
        Prsd                : out  std_logic_vector(15 downto 0);
        WCtrlDataStart      : out  std_logic;
        RStatStart          : out  std_logic;
        UpdateMIIRX_DATAReg : out  std_logic
    );
    end component;

    component calc_ipv4_checksum
    port (
        clk      : in  STD_LOGIC;
        data     : in  STD_LOGIC_VECTOR (159 downto 0);
        ready    : out STD_LOGIC;
        checksum : out STD_LOGIC_VECTOR (15 downto 0);
        reset    : in  STD_LOGIC);
    end component;

    ---------------------------------------------------------------------------
    --                            DUBUGGING SECTION
    ---------------------------------------------------------------------------
    signal dbg_i_own_ip_addr        : std_logic_vector(31 downto 0);
    signal dbg_i_own_mac_addr       : std_logic_vector(47 downto 0);
    signal dbg_i_dst_ip_addr        : std_logic_vector(31 downto 0);
    signal dbg_i_dst_mac_addr       : std_logic_vector(47 downto 0);
    signal dbg_i_udp_src_port       : std_logic_vector(15 downto 0);
    signal dbg_i_udp_dst_port       : std_logic_vector(15 downto 0);
    signal dbg_i_udp_tx_pkt_data_frq: std_logic_vector(47 downto 0);
    signal dbg_i_udp_tx_pkt_vld     : std_logic;
    signal dbg_i_sys_rst_i          : std_logic;

    signal dbg_i                    : std_logic_vector(241 downto 0);

    signal dbg_o_Busy               : std_logic;
    signal dbg_o_LinkFail           : std_logic;
    signal dbg_o_Nvalid             : std_logic;
    signal dbg_o_Prsd               : std_logic_vector(15 downto 0);
    signal dbg_o_WCtrlDataStart     : std_logic;
    signal dbg_o_RStatStart         : std_logic;
    signal dbg_o_UpdateMIIRX_DATAReg: std_logic;

    signal dbg_o                    : std_logic_vector(21 downto 0);

    signal dbg_ila_mii              : std_logic_vector(62 downto 0);

    signal control_0                : std_logic_vector(35 DOWNTO 0);
    signal control_1                : std_logic_vector(35 DOWNTO 0);
    signal control_2                : std_logic_vector(35 DOWNTO 0);

    component chipscope_icon
    PORT (
        CONTROL0 : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
        CONTROL1 : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
        CONTROL2 : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0));
    end component;

    component chipscope_vio_udp
    PORT (
        CONTROL : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
        ASYNC_OUT : IN STD_LOGIC_VECTOR(241 DOWNTO 0));
    end component;

    component chipscope_vio_mii
    PORT (
        CONTROL : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
        ASYNC_IN : IN STD_LOGIC_VECTOR(21 DOWNTO 0));
    end component;

    component chipscope_ila_mii
    PORT (
        CONTROL : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
        CLK : IN STD_LOGIC;
        TRIG0 : IN STD_LOGIC_VECTOR(62 DOWNTO 0));
    end component;
    ---------------------------------------------------------------------------
    --                        END OF DUBUGGING SECTION
    ---------------------------------------------------------------------------

    signal s_own_ip_addr        : std_logic_vector(31 downto 0);
    signal s_own_mac_addr       : std_logic_vector(47 downto 0);
    signal s_dst_ip_addr        : std_logic_vector(31 downto 0);
    signal s_dst_mac_addr       : std_logic_vector(47 downto 0);
    signal s_udp_src_port       : std_logic_vector(15 downto 0);
    signal s_udp_dst_port       : std_logic_vector(15 downto 0);
    signal s_udp_tx_pkt_data_frq: std_logic_vector(47 downto 0);
    signal s_udp_tx_pkt_data    : std_logic_vector(127 downto 0);
    signal s_udp_tx_pkt_vld     : std_logic;
    signal s_sys_rst_i          : std_logic;

    attribute S: string;
    attribute keep : string;

    signal c3_rst0 : std_logic;
    signal reset   : std_logic;

    signal Rx_mac_ra   : std_logic;
    signal Rx_mac_rd   : std_logic;
    signal Rx_mac_data : std_logic_vector( 31 downto 0 );
    signal Rx_mac_BE   : std_logic_vector( 1 downto 0 );
    signal Rx_mac_pa   : std_logic;
    signal Rx_mac_sop  : std_logic;
    signal Rx_mac_eop  : std_logic;

    --//user interface
    signal Tx_mac_wa   : std_logic;
    signal Tx_mac_wr   : std_logic;
    signal Tx_mac_data : std_logic_vector( 31 downto 0 );
    signal Tx_mac_BE   : std_logic_vector( 1 downto 0 );--//big endian
    signal Tx_mac_sop  : std_logic;
    signal Tx_mac_eop  : std_logic;
    --//pkg_lgth fifo
    signal Pkg_lgth_fifo_rd   : std_logic;
    signal Pkg_lgth_fifo_ra   : std_logic;
    signal Pkg_lgth_fifo_data : std_logic_vector( 15 downto 0 );

    signal CSB    : std_logic;
    signal WRB    : std_logic;
    signal CD_in  : std_logic_vector( 15 downto 0 );
    signal CD_out : std_logic_vector( 15 downto 0 );
    signal CA     : std_logic_vector( 7 downto 0 );
    --//mdx
    signal Mdo   : std_logic; --// MII Management Data Output
    signal MdoEn : std_logic; --// MII Management Data Output Enable
    signal Mdi   : std_logic;

    signal ethernet_speed : std_logic_vector( 2 downto 0);

    signal GIGE_GTX_CLK_buf    : std_logic;

    type state_type_ethernet is (arp,arp_wait,idle,wait_state,wait_state1,send_udp,wait_state2);  --type of state machine.
    signal state_ethernet : state_type_ethernet := wait_state2; --arp --current and next state declaration.

    --- transmisssion constants
    constant pkt_data_length       : integer := 8 * UDP_TX_DATA_BYTE_LENGTH;
    constant pkt_byte_mod           : integer := (UDP_TX_DATA_BYTE_LENGTH - 2) mod 4;
    constant pkt_data_mod           : integer := (pkt_data_length - 16) mod 32;
    constant pkt_data_word_length     : integer := (pkt_data_length - 16) / 32;

    constant length_ethernet_frame             : integer := integer(ceil(real((UDP_TX_DATA_BYTE_LENGTH) / 4))) + 11;---12;
    constant length_ethernet_arp_frame         : integer := 11;
    constant length_ethernet_arp_request_frame : integer := 11;

    -- receiving constants
    constant rcv_pkt_data_length      : integer := 8 * UDP_RX_DATA_BYTE_LENGTH;
    constant rcv_pkt_byte_mod           : integer := (UDP_RX_DATA_BYTE_LENGTH - 2) mod 4;
    constant rcv_pkt_data_mod           : integer := (rcv_pkt_data_length - 16) mod 32;
    constant rcv_pkt_data_word_length : integer := (rcv_pkt_data_length - 16) / 32;

    constant rcv_length_ethernet_frame  :  integer := integer(ceil(real((UDP_RX_DATA_BYTE_LENGTH) / 4))) + 1;

    signal udp_rx_pkt_data_tmp : std_logic_vector(rcv_pkt_data_length - 1 downto 0) := (others => '0');
    signal udp_rx_pkt_data_r   : std_logic_vector(31 downto 0) := (others => '0');
    signal udp_rx_rdy_tmp      : std_logic := '0';

    type array_network is array (0 to length_ethernet_frame-1) of std_logic_vector(31 downto 0);
    type array_network_arp is array (0 to length_ethernet_arp_frame-1) of std_logic_vector(31 downto 0);
    type array_network_arp_request is array (0 to length_ethernet_arp_request_frame-1) of std_logic_vector(31 downto 0);
    signal eth_array : array_network;
    signal arp_array : array_network_arp;
    signal arp_request_array : array_network_arp_request;
    signal counter_ethernet : integer range 0 to length_ethernet_frame-1;


    signal Rx_clk : std_logic;
    signal Tx_clk : std_logic;
    signal Tx_er  : std_logic;
    signal Tx_en  : std_logic;
    signal Txd    : std_logic_vector( 7 downto 0 );
    signal Rx_er  : std_logic;
    signal Rx_dv  : std_logic;
    signal Rxd    : std_logic_vector( 7 downto 0 );

    signal MDC_sig : std_logic;

    signal calc_checksum : std_logic_vector( 15 downto 0);

    signal LED_sig : std_logic;

    signal counter_ethernet_delay : integer := 0;

    signal counter_ethernet_rec : integer range 0 to 15;
    signal packet_valid : std_logic;

    signal LED_data : std_logic_vector( 7 downto 0);

    signal Rx_mac_rd_sig : std_logic;

    signal udp_valid : std_logic := '0';

    signal arp_valid_response          : std_logic;
    signal arp_valid_response_recieved : std_logic;
    signal arp_valid                   : std_logic;
    signal arp_mac                     : std_logic_vector(47 downto 0);
    signal arp_ip                      : std_logic_vector(31 downto 0);
    signal arp_send                    : std_logic;
    signal arp_clear                   : std_logic;


    -- signal for destination MAC address
    signal dst_mac_addr_r : std_logic_vector( 47 downto 0 );

    signal gmii_phy_rst_n : std_logic;

    -- PHY management
    signal config_state        : integer range 0 to 31 := 0;
    signal config_checked      : std_logic := '0';
    signal config_delay_count  : integer range 0 to 250000000;
    signal phy_reg_addr        : std_logic_vector(4 downto 0) := (others => '0');

    signal Divider             : std_logic_vector(7 downto 0) := x"1A";
    signal CtrlData            : std_logic_vector(15 downto 0);
    signal Rgad                : std_logic_vector(4 downto 0);
    signal Fiad                : std_logic_vector(4 downto 0) := "00001";
    signal NoPre               : std_logic;
    signal WCtrlData           : std_logic;
    signal RStat               : std_logic;
    signal ScanStat            : std_logic;
    signal Busy                : std_logic;
    signal LinkFail            : std_logic;
    signal Nvalid              : std_logic;
    signal Prsd                : std_logic_vector(15 downto 0);
    signal WCtrlDataStart      : std_logic;
    signal RStatStart          : std_logic;
    signal UpdateMIIRX_DATAReg : std_logic;

    -- Udp transmission
    signal udp_counter : integer   := 0;
    signal udp_rec     : std_logic := '0';
    signal counter_rx  : integer   := 0;
    signal packet_vld  : std_logic := '0';
    signal mac_init_ok : std_logic := '0';

    -- Debug signals
    signal tx_state     : std_logic_vector(2 downto 0) := "000";
    signal rx_state     : std_logic_vector(2 downto 0) := "000";
    signal rx_udp_state : std_logic_vector(3 downto 0) := "0000";
    signal toggle       : std_logic := '0'; -- 50 mhz user clock
    signal toggle1      : std_logic := '0'; -- 125 mhz
    signal toggle2      : std_logic := '0'; -- 125 mhz
begin


     s_own_ip_addr       <= own_ip_addr;
     s_own_mac_addr      <= own_mac_addr;
     s_dst_ip_addr       <= dst_ip_addr;
     s_dst_mac_addr      <= dst_mac_addr;
     s_udp_src_port      <= udp_src_port;
     s_udp_dst_port      <= udp_dst_port;
     s_udp_tx_pkt_data   <= udp_tx_pkt_data;
     s_udp_tx_pkt_vld    <= udp_tx_pkt_vld;
     s_sys_rst_i         <= sys_rst_i;

--    s_own_ip_addr           <= dbg_i_own_ip_addr;
--    s_own_mac_addr          <= dbg_i_own_mac_addr;
--    s_dst_ip_addr           <= dbg_i_dst_ip_addr;
--    s_dst_mac_addr          <= dbg_i_dst_mac_addr;
--    s_udp_src_port          <= dbg_i_udp_src_port;
--    s_udp_dst_port          <= dbg_i_udp_dst_port;
--    s_udp_tx_pkt_data_frq   <= dbg_i_udp_tx_pkt_data_frq;
--    s_udp_tx_pkt_vld        <= dbg_i_udp_tx_pkt_vld;
--    s_sys_rst_i             <= dbg_i_sys_rst_i;


    reset <= not sysclk_locked or dbg_i_sys_rst_i;

    udp_tx_rdy <= '1' when (Tx_mac_wa = '1' and state_ethernet = wait_state2) else '0';
     --dst_mac_addr <= dst_mac_addr_r;

    mac_init_done <= mac_init_ok;

    -- settings for ethernet MAC
    Ethernet_MAC_top : MAC_top
    port map(
        --//system signals
        Reset    => reset,
        Clk_125M => clk_125mhz,
        Clk_user => clk_62_5mhz,--!!!!!!!!!!!
        Clk_reg  => clk_62_5mhz,--!!!!!!!!!!!

        -- speed settings after opencore tri-mode (PDF)!
        -- b100 :   1000Mbit
        -- b010 :   100Mbit
        -- b001 :   10Mbit
        Speed => ethernet_speed,

        --//user interface
        Rx_mac_ra   => Rx_mac_ra,
        Rx_mac_rd   => Rx_mac_rd,
        Rx_mac_data => Rx_mac_data,
        Rx_mac_BE   => Rx_mac_BE,
        Rx_mac_pa   => Rx_mac_pa,
        Rx_mac_sop  => Rx_mac_sop,
        Rx_mac_eop  => Rx_mac_eop,
        --//user interface
        Tx_mac_wa   => Tx_mac_wa,
        Tx_mac_wr   => Tx_mac_wr,
        Tx_mac_data => Tx_mac_data,
        Tx_mac_BE   => Tx_mac_BE, --//big endian
        Tx_mac_sop  => Tx_mac_sop,
        Tx_mac_eop  => Tx_mac_eop,

        --//pkg_lgth fifo
        -- signals for FIFO implementation of RX in core
        -- with clock Clk_user!!
        Pkg_lgth_fifo_rd   => Pkg_lgth_fifo_rd,
        Pkg_lgth_fifo_ra   => Pkg_lgth_fifo_ra,
        Pkg_lgth_fifo_data => Pkg_lgth_fifo_data,

        --//Phy interface
        Gtx_clk => GIGE_GTX_CLK_buf,--//used only in GMII mode
        Crs     => GIGE_CRS,
        Col     => GIGE_COL,

        Rx_clk => Rx_clk,
        --Tx_clk    => Tx_clk, --//used only in MII mode
        Tx_clk => GIGE_TX_CLK, --//used only in MII mode
        --Tx_clk    => '0',
        Tx_er  => Tx_er,
        Tx_en  => Tx_en,
        Txd    => Txd,
        Rx_er  => Rx_er,
        Rx_dv  => Rx_dv,
        Rxd    => Rxd,

        --//host interface
        CSB    => CSB,
        WRB    => WRB,
        CD_in  => CD_in,
        CD_out => CD_out,
        CA     => CA,

        --//mdx
        Mdo   => Mdo, --// MII Management Data Output
        MdoEn => MdoEn, --// MII Management Data Output Enable
        Mdi   => Mdi,
        Mdc   => MDC_sig, --// MII Management Data Clock

        --
        Divider   => Divider,
        CtrlData  => CtrlData,
        Rgad      => Rgad,
        Fiad      => Fiad,
        NoPre     => NoPre,
        WCtrlData => WCtrlData,
        RStat     => RStat,
        ScanStat  => ScanStat,

        Busy                 => Busy,
        LinkFail             => LinkFail,
        Nvalid               => Nvalid,
        Prsd                 => Prsd,
        WCtrlDataStart       => WCtrlDataStart,
        RStatStart           => RStatStart,
        UpdateMIIRX_DATAReg  => UpdateMIIRX_DATAReg
    );

    -- be careful!
    GIGE_nRESET <= not reset;

    GIGE_TX_ER <= Tx_er;
    GIGE_TX_EN <= Tx_en;
    GIGE_TXD   <= Txd;

    Rx_er  <= GIGE_RX_ER;
    Rx_dv  <= GIGE_RX_DV;
    Rxd    <= GIGE_RXD;
    Rx_clk <= GIGE_RX_CLK;

    gmii_phy_rst_n <= not reset;

    -- MIIM Management
    GIGE_MDIO <= Mdo when MdoEn = '1' else 'Z';
    Mdi <= GIGE_MDIO when MdoEn = '0' else 'Z';

    CSB <= '0';
    WRB <= '1';

    calc_ipv4_checksum_inst : calc_ipv4_checksum
    port map (
        clk => clk_62_5mhz,--!!!!!!!!!!!
        data => eth_array(8)(31 downto 16) & eth_array(7) & eth_array(6) & eth_array(5) & eth_array(4)& eth_array(3)(15 downto 0),
        --ready : out STD_LOGIC;
        checksum => calc_checksum,
        reset => '0'
    );

    Rx_mac_rd <= Rx_mac_rd_sig AND Rx_mac_ra;

    ethernet_data_rec_process : process(c3_rst0,clk_62_5mhz)
    begin
        if( c3_rst0 = '1' ) then
            counter_ethernet_rec <= 0;
            packet_valid <= '0';
            Rx_mac_rd_sig <= '0';

            arp_send <= '0';
            arp_mac <= (others => '0');
            arp_ip <= (others => '0');
            dst_mac_addr_r <= (others => '0');
            arp_valid <= '0';
            arp_valid_response <= '0';
            arp_valid_response_recieved <= '0';
            udp_valid <= '0';
        elsif( rising_edge(clk_62_5mhz) ) then
            if( config_checked = '1' ) then
                dst_mac_addr_r <= s_dst_mac_addr;
                Rx_mac_rd_sig <= '0';

                if(tx_state = "010") then
                    udp_valid <= '0';
                end if;

                if( arp_clear = '1' ) then
                    arp_send <= '0';
                end if;

                if( Rx_mac_ra = '1') then
                    Rx_mac_rd_sig <= '1';
                    if( Rx_mac_pa = '1' ) then

                        counter_ethernet_rec <= counter_ethernet_rec+1;

                        -- check if dest. is our FPGA device!!
                        -- when true then packet_valid is high else low
                        if( counter_ethernet_rec = 0 ) then
                            if( Rx_mac_data = s_own_mac_addr (47 downto 16) ) then
                                packet_valid <= '1';
                            else
                                packet_valid <= '0';
                            end if;
                        elsif( counter_ethernet_rec = 1 ) then
                            if( Rx_mac_data(31 downto 16) = s_own_mac_addr (15 downto 0) ) then
                                packet_valid <= '1';
                            else
                                packet_valid <= '0';
                            end if;
                        end if;


                        if( counter_ethernet_rec = 3 ) then
                            --if( Rx_mac_data = ( x"0806" & x"0001" ) AND arp_send = '0' ) then

                            -- check if it is an UDP request, then udp_valid = '1'!!
                            -- Ethernet Type = "0x0800" | Version Header = "0100" | Total Length = "0101" | Differential Services = x"0x00"
                            if( Rx_mac_data = ( x"0800" & "0100" & "0101" & x"00" ) ) then
                                udp_valid <= '1';
                            else
                                if(udp_rx_pkt_req = '0') then
                                    udp_valid <= '0';
                                end if;
                                -- check if it is an ARP request, then arp_valid = '1'!!
                                if( Rx_mac_data = ( x"0806" & x"0001" ) ) then
                                    arp_valid <= '1';
                                else
                                    arp_valid <= '0';
                                end if;
                            end if;
                        end if;

                        -- if ARP request, process packet further
                        if( arp_valid = '1' ) then
                            if( counter_ethernet_rec = 4 ) then
                                if( Rx_mac_data = ( x"0800" & x"06" & x"04" ) ) then
                                    arp_valid <= '1';
                                else
                                    arp_valid <= '0';
                                end if;

                            elsif( counter_ethernet_rec = 5 ) then
                                rx_state <= "000";
                                if( Rx_mac_data(31 downto 16) = x"0001" ) then
                                    arp_valid <= '1';
                                    arp_mac(47 downto 32) <= Rx_mac_data(15 downto 0);
                                elsif( Rx_mac_data(31 downto 16) = x"0002" ) then
                                    arp_valid_response <= '1';
                                    arp_mac(47 downto 32) <= Rx_mac_data(15 downto 0);
                                    arp_valid <= '1';
                                else
                                    arp_valid <= '0';
                                end if;

                            elsif( counter_ethernet_rec = 6 ) then
                                rx_state <= "001";
                                arp_mac(31 downto 0) <= Rx_mac_data;

                            elsif( counter_ethernet_rec = 7 ) then
                                rx_state <= "010";
                                arp_ip <= Rx_mac_data;
                                arp_valid_response <= '0';
                                if( Rx_mac_data = s_dst_ip_addr  ) then
                                    arp_valid_response <= '1';
                                end if;

                            elsif( counter_ethernet_rec = 8 ) then
                                rx_state <= "011";
                                arp_valid_response <= '0';
                                if( Rx_mac_data = s_own_mac_addr (47 downto 16) ) then
                                    arp_valid_response <= '1';
                                end if;

                            elsif( counter_ethernet_rec = 9 ) then
                                rx_state <= "100";
                                if( Rx_mac_data(15 downto 0) = s_own_ip_addr(31 downto 16) ) then
                                    arp_valid <= '1';
                                else
                                    arp_valid <= '0';
                                end if;

                                arp_valid_response <= '0';
                                if( Rx_mac_data(31 downto 16) = s_own_mac_addr (15 downto 0) ) then
                                    arp_valid_response <= '1';
                                end if;

                            elsif( counter_ethernet_rec = 10 ) then
                                rx_state <= "101";
                                arp_valid <= '0';
                                arp_valid_response <= '0';
                                if( Rx_mac_data(31 downto 16) = s_own_ip_addr(15 downto 0) ) then
                                    if( arp_valid_response = '1' ) then
                                        arp_valid_response_recieved <= '1';
                                        arp_send <= '0';
                                        dst_mac_addr_r <= arp_mac;
                                    else
                                        arp_send <= '1';
                                        arp_valid_response_recieved <= '0';
                                    end if;
                                end if;

                            end if;
                        end if;

                    end if;

                else
                    counter_ethernet_rec <= 0;
                end if;

            end if;
        end if;
    end process;

    udp_packet_data_process : process(c3_rst0,clk_62_5mhz)

    begin
        if( c3_rst0 = '1' ) then
            counter_rx <= 0;
            packet_vld <= '0';
        elsif( rising_edge(clk_62_5mhz) ) then

                udp_rx_rdy        <= '0';
                udp_rx_rdy_tmp  <= '0';
            --    ila_data0(60) <= '0';
                counter_rx          <= 0;

            case rx_udp_state is

                when x"0" =>

                    rx_udp_state <= x"0";

                    if(packet_valid = '1') then
                        packet_vld <= '1';
                    end if;

                    if(counter_ethernet_rec = 10 and counter_rx = 0 and packet_valid = '1') then
                            udp_rx_pkt_data_tmp(rcv_pkt_data_length - 1 downto rcv_pkt_data_length - 16) <= Rx_mac_data(15 downto 0);
                            counter_rx <= counter_rx + 1;
                            packet_vld <= '1';
                            rx_udp_state <= x"1";
                    end if;

                when x"1" =>

                    rx_udp_state <= x"1";

                    if(counter_rx = rcv_length_ethernet_frame-1) then
                       --TODO: fix this to accommodate multiple cases
                        if(rcv_length_ethernet_frame = 1) then
                            --udp_rx_pkt_data_tmp((rcv_length_ethernet_frame * 32) - rcv_pkt_data_length - 1 downto  0) <= Rx_mac_data(31 downto ((rcv_length_ethernet_frame * 32) - ((rcv_length_ethernet_frame * 32) - rcv_pkt_data_length)));  --Rx_mac_data
                            udp_rx_pkt_data_tmp(7 downto  0) <= Rx_mac_data(31 downto 24);  --Rx_mac_data
                        else
                            udp_rx_pkt_data_tmp(15 downto  0) <= Rx_mac_data(31 downto 16);
                        end if;

                        counter_rx <=  counter_rx + 1;
                        rx_udp_state <= x"2";

                    elsif(counter_rx < rcv_length_ethernet_frame-1 and packet_vld = '1') then

                        --    if(counter_rx < rcv_length_ethernet_frame ) then
                        --          udp_rx_pkt_data_tmp(rcv_pkt_data_length - 17 - (counter_rx * 32) downto rcv_pkt_data_length - 16 - (counter_rx * 32) - 32) <= Rx_mac_data;
                        --    else
                            --    if(rcv_pkt_byte_mod > 0) then
                                    --udp_rx_pkt_data_tmp(rcv_pkt_data_length - 17 - (counter_rx * 32) downto rcv_pkt_data_length - 16 - (counter_rx * 32) - rcv_pkt_data_mod) <= Rx_mac_data(31 downto 32 - rcv_pkt_data_mod);
                            --        udp_rx_pkt_data_tmp(rcv_pkt_data_length - (counter_rx * 32) + 15 downto rcv_pkt_data_length - (counter_rx * 32) - rcv_pkt_data_mod) <= Rx_mac_data; --(31 downto 32 - rcv_pkt_data_mod);
                            --    else
                            --        udp_rx_pkt_data_tmp(rcv_pkt_data_length - 17 - (counter_rx * 32) downto rcv_pkt_data_length - 16 - (counter_rx * 32) - 32) <= Rx_mac_data;
                            --    end if;
                        --    end if;
                            udp_rx_pkt_data_tmp(rcv_pkt_data_length - (counter_rx * 32) + 15 downto rcv_pkt_data_length - (counter_rx * 32) - rcv_pkt_data_mod) <= Rx_mac_data;
                            counter_rx <= counter_rx + 1;
                     end if;

                when x"2" =>

                    rx_udp_state <= x"2";

                    packet_vld <= '0';
                    counter_rx <= 0;
                    if(udp_rx_pkt_req = '1' and udp_valid = '1') then
                        udp_rx_pkt_data <= udp_rx_pkt_data_tmp;
                        udp_rx_rdy        <= '1';
                        udp_rx_rdy_tmp  <= '1';
                        rx_udp_state <= x"3";
                    end if;

                when x"3" =>

                    udp_rx_pkt_data <= (others => 'Z');
                    udp_rx_rdy        <= '0';
                    rx_udp_state <= x"0";

                when others => null;
            end case;
        end if;
    end process;


    ethernet_data_process : process(c3_rst0,clk_62_5mhz)
        variable counter : integer := 0;
        variable ip_header_length  : std_logic_vector(15 downto 0);
        variable udp_header_length : std_logic_vector(15 downto 0);
    begin
       Tx_mac_BE <= (others => 'Z');


        -- determine ip header and udp header length attributes
--        if(pkt_byte_mod > 0)then
--            ip_header_length  := conv_std_logic_vector((UDP_TX_DATA_BYTE_LENGTH + 28 + (4 - pkt_byte_mod)), 16);
--            udp_header_length := conv_std_logic_vector((UDP_TX_DATA_BYTE_LENGTH + 8 +  (4 - pkt_byte_mod)), 16);
--        else
--            ip_header_length  := conv_std_logic_vector((UDP_TX_DATA_BYTE_LENGTH + 28), 16);
--            udp_header_length := conv_std_logic_vector((UDP_TX_DATA_BYTE_LENGTH + 8), 16);
--        end if;
        ip_header_length := x"002b"; -- force IP length to 0x002b = 43...
        udp_header_length := x"0017"; -- force UDP length field to 0x0017 = 23 which is what passive wants


        -- UDP packet
        eth_array(0) <= s_dst_mac_addr(47 downto 16);
        eth_array(1) <= s_dst_mac_addr(15 downto 0) & s_own_mac_addr (47 downto 32);
        eth_array(2) <= s_own_mac_addr (31 downto 0);
                        --  ethernet type    | Version / Header length | diff Services
        eth_array(3) <= x"0800"          & "0100" & "0101"         & "00000000"    ;
                            -- total length        |  identification
        eth_array(4) <= ip_header_length       & x"0000";
                            -- Flags , Fragment Offeset  | time to live | protocol
        eth_array(5) <= "0100000000000000"          &  "01000000"  & "00010001";
                            -- header checksum |  Source IP:
        eth_array(6) <= calc_checksum     &  s_own_ip_addr(31 downto 16);
                            --                           |  Destin IP:
        eth_array(7) <= s_own_ip_addr(15 downto 0) &  s_dst_ip_addr (31 downto 16);
                            --                             | source port
        eth_array(8) <= s_dst_ip_addr (15 downto 0)  &  s_udp_src_port ;
                            -- dest port | length
        eth_array(9) <= s_udp_dst_port   & udp_header_length ;
                            -- checksum  |  data
        eth_array(10)(31 downto 16) <= x"0000";
                            -- data
        ---- eth_array(11) <= conv_std_logic_vector(udp_counter, 32);--x"6c6c6f20";
--
--         if(pkt_data_length = 8) then
--             eth_array(10)(15 downto 0) <= s_udp_tx_pkt_data & (7 downto 0 => '0');
--         else
--             eth_array(10)(15 downto 0) <= s_udp_tx_pkt_data(pkt_data_length - 1 downto pkt_data_length - 16);
--        
--             counter := 0;
--             for i in 11 to length_ethernet_frame - 2 loop
--                 eth_array(i) <= s_udp_tx_pkt_data(pkt_data_length - (counter * 32) - 17 downto pkt_data_length - (counter * 32) - 48);
--                 counter := counter + 1;
--             end loop;
--        
--             if(pkt_byte_mod > 0) then
--                 eth_array(length_ethernet_frame - 1) <=  s_udp_tx_pkt_data(pkt_data_mod - 1 downto 0) & (32 - pkt_data_mod - 1 downto 0  => '0');
--             else
--                 eth_array(length_ethernet_frame - 1) <= s_udp_tx_pkt_data(31 downto 0);
--             end if;
--         end if;

        -- allowing chipscope to inject frequency data into payload (see spreadsheet)
        eth_array(10)(15 downto 0)  <= udp_tx_pkt_data(127 downto 112);
        eth_array(11)               <= udp_tx_pkt_data(111 downto 80);
        eth_array(12)               <= udp_tx_pkt_data(79 downto 48);
        eth_array(13)               <= dbg_i_udp_tx_pkt_data_frq(47 downto 16);
        eth_array(14)(31 downto 16) <= dbg_i_udp_tx_pkt_data_frq(15 downto 0);
        eth_array(14)(15 downto 0)  <= (others=>'0');

        -- answer to ARP request from any computer
        arp_array(0) <= arp_mac(47 downto 16);
        arp_array(1) <= arp_mac(15 downto 0) & s_own_mac_addr (47 downto 32);
        arp_array(2) <= s_own_mac_addr (31 downto 0);
        arp_array(3) <= x"0806" & x"0001";
        arp_array(4) <= x"0800" & x"06" & x"04";
        arp_array(5) <= x"0002" & s_own_mac_addr (47 downto 32);
        arp_array(6) <= s_own_mac_addr (31 downto 0);
        arp_array(7) <= s_own_ip_addr;
        arp_array(8) <= arp_mac(47 downto 16);
        arp_array(9) <= arp_mac(15 downto 0) & arp_ip(31 downto 16);
        arp_array(10) <= arp_ip(15 downto 0) & x"0000";

        -- init ARP request array
        arp_request_array(0) <= x"FFFFFFFF";
        arp_request_array(1) <= x"FFFF" & s_own_mac_addr (47 downto 32);
        arp_request_array(2) <= s_own_mac_addr (31 downto 0);
        arp_request_array(3) <= x"0806" & x"0001";
        arp_request_array(4) <= x"0800" & x"06" & x"04";
        arp_request_array(5) <= x"0001" & s_own_mac_addr (47 downto 32);
        arp_request_array(6) <= s_own_mac_addr (31 downto 0);
        arp_request_array(7) <= s_own_ip_addr;
        arp_request_array(8) <= x"00000000";
        arp_request_array(9) <= x"0000" & s_dst_ip_addr (31 downto 16);
        arp_request_array(10) <= s_dst_ip_addr (15 downto 0) & x"0000";

        if( c3_rst0 = '1' ) then
            Tx_mac_wr <= '0';
            Tx_mac_sop <= '0';
            Tx_mac_eop <= '0';
            counter_ethernet <= 0;
            counter_ethernet_delay <= 0;
            state_ethernet <= wait_state2; --arp;
            arp_clear <= '0';
        elsif( rising_edge(clk_62_5mhz) ) then
            Tx_mac_sop <= '0';
            Tx_mac_eop <= '0';
            Tx_mac_wr <= '0';
            arp_clear <= '0';

            if (config_checked = '1') then

                -- signal start of the frame
                if( Tx_mac_wa = '1' AND counter_ethernet = 0 AND counter_ethernet_delay = 0) then
                    Tx_mac_sop <= '1';
                end if;

                case state_ethernet is

                    -- send ARP request to recieve the MAC of dst_ip_addr
                    when arp =>
                        tx_state <= "000";
                        if( Tx_mac_wa = '1') then
                            state_ethernet <= arp;
                            Tx_mac_wr <= '1';

                            if( counter_ethernet < length_ethernet_arp_request_frame-1 ) then
                                counter_ethernet <= counter_ethernet + 1;
                            else
                                state_ethernet <= arp_wait;
                                -- signal end of the frame
                                Tx_mac_eop <= '1';
                                Tx_mac_BE <= "00";
                            end if;
                            Tx_mac_data <= arp_request_array(counter_ethernet);

                        else
                            state_ethernet <= arp_wait;
                        end if;

                    -- wait some time to recieve answer to ARP request
                    when arp_wait =>
                        tx_state <= "001";
                        counter_ethernet <= 0;
                        Tx_mac_data <= (others => '0');
                        if( counter_ethernet_delay < 2**21-1 ) then
                            counter_ethernet_delay <= counter_ethernet_delay + 1;
                            state_ethernet <= arp_wait;
                        else
                            state_ethernet <= arp;
                            counter_ethernet_delay <= 0;
                        end if;

                        if( arp_valid_response_recieved = '1' ) then
                            state_ethernet <= idle;
                        end if;

                    -- respond to ARP request
                    when idle =>
                        tx_state <= "010";
                        if( Tx_mac_wa = '1') then
                            state_ethernet <= idle;
                            Tx_mac_wr <= '1';

                            if( arp_send = '1' and s_udp_tx_pkt_vld = '0') then
                                if( counter_ethernet < length_ethernet_arp_frame-1 ) then
                                    counter_ethernet <= counter_ethernet + 1;
                                else
                                    --counter_ethernet <= 0;
                                    state_ethernet <= wait_state2;
                                    arp_clear <= '1';
                                    -- signal end of the frame
                                    Tx_mac_BE <= "00";
                                    Tx_mac_eop <= '1';
                                end if;
                                Tx_mac_data <= arp_array(counter_ethernet);
                            else
                                if( counter_ethernet < length_ethernet_frame-1 ) then
                                    counter_ethernet <= counter_ethernet + 1;
                                else
                                    --counter_ethernet <= 0;
                                    Tx_mac_eop <= '1';
                                    -- signal end of the frame
                                    Tx_mac_BE <= "00";
                                    state_ethernet <= wait_state2;
                                end if;
                                Tx_mac_data <= eth_array(counter_ethernet);
                            end if;
                        else
                            state_ethernet <= wait_state;
                        end if;

                    -- wait some time till Tx_mac_wa is high again
                    when wait_state =>
                        tx_state <= "101";
                        if( Tx_mac_wa = '1' ) then
                            state_ethernet <= idle;
                        else
                            state_ethernet <= wait_state;
                        end if;

                    -- wait such that throughput is not as high as possible
                    when wait_state2 =>
                        tx_state <= "110";
                        mac_init_ok <= '1';

                        counter_ethernet           <= 0;
                        counter_ethernet_delay <= 0;

                        if(s_udp_tx_pkt_vld = '1' or arp_send = '1') then
                            state_ethernet <= idle;
                        else
                            state_ethernet <= wait_state2;
                        end if;
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------------------
    -- Marvell 88E1111S initialization
    ------------------------------------------------------------------------------

    phy_config : process(clk_62_5mhz, reset)
    begin
        if(rising_edge(clk_62_5mhz)) then
            if reset = '1' then
                -- reset the counter and other signals
                config_state <= 0;
                config_delay_count <= 0;
                CtrlData  <= (others => '0');
                Rgad      <= (others => '0');
                NoPre     <= '0';
                WCtrlData <= '0';
                RStat     <= '0';
                ScanStat  <= '0';
                config_checked <= '0';
            else
                case config_state is
                    when 0 =>
                        if(config_delay_count < 250000000) then
                            config_delay_count <= config_delay_count + 1;
                        --else
                        elsif(config_checked = '0') then
                           phy_reg_addr <= phy_reg_addr + 1;

                            config_state <= 1;
                        end if;
                    when 1 =>
                        CtrlData  <= x"0C61";
                        Rgad      <= "10100"; -- Register 20
                        NoPre     <= '0';
                        WCtrlData <= '1';
                        RStat     <= '0';
                        ScanStat  <= '0';

                        config_state <= 2;
                    when 2 =>
                        if(Busy = '1') then
                            config_state <= 3;
                        end if;
                    when 3 =>
                        if(Busy = '0') then
                            config_state <= 4;
                        elsif(MdoEn = '0') then
                            WCtrlData     <= '0';
                        end if;
                    when 4 =>
                        CtrlData  <= x"0000";
                        Rgad      <= "10100";
                        NoPre     <= '0';
                        WCtrlData <= '0';
                        RStat     <= '1';
                        ScanStat  <= '0';

                        config_state <= 5;

                    when 5 =>
                        if(Busy = '1') then
                            config_state <= 6;
                        end if;
                    when 6 =>
                        if(Busy = '0') then
                            config_delay_count <= 0;
                            config_checked <= '1';
                            config_state <= 0;
                        elsif(MdoEn = '0') then
                            RStat     <= '0';
                        end if;
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process;

    -- ODDR2 is needed instead of the following
    --   GIGE_GTX_CLK <= GIGE_GTX_CLK_buf;
    -- because GIGE_GTX_CLK is dcm_vga_clk_125mhz
    -- and limiting in Spartan 6
    txclk_ODDR2_inst : ODDR2
    generic map (
        DDR_ALIGNMENT => "NONE",
        INIT => '0',
        SRTYPE => "SYNC")
    port map (
        Q => GIGE_GTX_CLK, -- 1-bit DDR output data
        C0 => GIGE_GTX_CLK_buf, -- clock is your signal from PLL
        C1 => not(GIGE_GTX_CLK_buf), -- n
        D0 => '1', -- 1-bit data input (associated with C0)
        D1 => '0' -- 1-bit data input (associated with C1)
    );

    -- ODDR2 is needed instead of the following
    --   GIGE_GTX_CLK <= GIGE_GTX_CLK_buf;
    -- because GIGE_GTX_CLK is dcm_vga_clk_125mhz
    -- and limiting in Spartan 6
    MDC_ODDR2_inst : ODDR2
    generic map (
        DDR_ALIGNMENT => "NONE",
        INIT => '0',
        SRTYPE => "SYNC")
    port map (
        Q => GIGE_MDC, -- 1-bit DDR output data
        C0 => MDC_sig, -- clock is your signal from PLL
        C1 => not(MDC_sig), -- n
        D0 => '1', -- 1-bit data input (associated with C0)
        D1 => '0' -- 1-bit data input (associated with C1)
    );


    ---------------------------------------------------------------------------
    --                            DUBUGGING SECTION
    ---------------------------------------------------------------------------
    my_icon : chipscope_icon
    port map (
        CONTROL0 => control_0,
        CONTROL1 => control_1,
        CONTROL2 => control_2);

    my_vio_udp : chipscope_vio_udp
    port map (
        CONTROL => control_0,
        ASYNC_OUT => dbg_i);

    my_vio_mii : chipscope_vio_mii
    port map (
        CONTROL => control_1,
        ASYNC_IN => dbg_o);

    my_ila_mii : chipscope_ila_mii
    port map (
        CONTROL => control_2,
        CLK => clk_62_5mhz,
        TRIG0 => dbg_ila_mii);

--    dbg_i_own_ip_addr           <= dbg_i(241 downto 210); --(31 downto 0);
--    dbg_i_own_mac_addr          <= dbg_i(209 downto 162); --(47 downto 0);
--    dbg_i_dst_ip_addr           <= dbg_i(161 downto 130);--(31 downto 0);
--    dbg_i_dst_mac_addr          <= dbg_i(129 downto 82); --(47 downto 0);
--    dbg_i_udp_src_port          <= dbg_i(81 downto 66); --(15 downto 0);
--    dbg_i_udp_dst_port          <= dbg_i(65 downto 50); --(15 downto 0);
--    dbg_i_udp_tx_pkt_data_frq   <= dbg_i(49 downto 2); --(47 downto 0);
--    dbg_i_udp_tx_pkt_vld        <= dbg_i(1); --;
--    dbg_i_sys_rst_i             <= dbg_i(0); --;

    dbg_o_Busy                  <= Busy;
    dbg_o_LinkFail              <= LinkFail;
    dbg_o_Nvalid                <= Nvalid;
    dbg_o_WCtrlDataStart        <= WCtrlDataStart;
    dbg_o_RStatStart            <= RStatStart;
    dbg_o_UpdateMIIRX_DATAReg   <= UpdateMIIRX_DATAReg;
    dbg_o_Prsd                  <= Prsd;

--    dbg_o(21)                   <= dbg_o_Busy;
--    dbg_o(20)                   <= dbg_o_LinkFail;
--    dbg_o(19)                   <= dbg_o_Nvalid;
--    dbg_o(18)                   <= dbg_o_WCtrlDataStart;
--    dbg_o(17)                   <= dbg_o_RStatStart;
--    dbg_o(16)                   <= dbg_o_UpdateMIIRX_DATAReg;
--    dbg_o(15 downto 0)          <= dbg_o_Prsd;
--
--
--    dbg_ila_mii(62 downto 58)   <= conv_std_logic_vector(config_state, 5);
--    dbg_ila_mii(57 downto 26)   <= conv_std_logic_vector(config_delay_count, 32);
--    dbg_ila_mii(25)             <= config_checked;
--    dbg_ila_mii(24 downto 9)    <= CtrlData;
--    dbg_ila_mii(8 downto 4)     <= Rgad;
--    dbg_ila_mii(3)              <= WCtrlData;
--    dbg_ila_mii(2)              <= ScanStat;
--    dbg_ila_mii(1)              <= NoPre;
--    dbg_ila_mii(0)              <= RStat;
    ---------------------------------------------------------------------------
    --                        END OF DUBUGGING SECTION
    ---------------------------------------------------------------------------


end arc;
