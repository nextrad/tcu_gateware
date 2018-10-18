-- tcu_fc.vhd
-- TIMING CONTROL UNIT FSM + i/o Controller
-- Platform independent version

-- TODO:
--      fix generics, either give all or nothing

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tcu_fc is
generic(
        PULSE_PARAMS_WIDTH      : natural := 80;
        PULSE_PARAMS_ADDR_WIDTH : natural := 5;
        INSTRUCTION_WIDTH       : natural := 16;
        STATUS_WIDTH            : natural := 16
    );
port(
        clk_IN                  : in  std_logic;
        clk_125MHz_IN           : in  std_logic;
        rst_IN                  : in  std_logic;
        trigger_IN              : in  std_logic;

        -- instruction and data registers
        instruction_IN          : in  std_logic_vector(INSTRUCTION_WIDTH - 1 downto 0);
        num_pulses_IN           : in  std_logic_vector(15 downto 0);
        num_repeats_IN          : in  std_logic_vector(31 downto 0);
        x_amp_delay_IN          : in  std_logic_vector(15 downto 0);
        l_amp_delay_IN          : in  std_logic_vector(15 downto 0);
        rex_delay_IN            : in  std_logic_vector(15 downto 0);
        pre_pulse_IN            : in  std_logic_vector(15 downto 0);
        pri_pulse_width_IN      : in  std_logic_vector(31 downto 0);
        pulse_params_IN         : in  std_logic_vector(PULSE_PARAMS_WIDTH - 1 downto 0);
        pulse_index_OUT         : out std_logic_vector(PULSE_PARAMS_ADDR_WIDTH - 1 downto 0);
        status_OUT              : out std_logic_vector(STATUS_WIDTH - 1 downto 0);

        -- amp bias and polarization switches
        bias_x_OUT              : out std_logic;
        bias_l_OUT              : out std_logic;
        pol_tx_x_OUT            : out std_logic;
        pol_tx_l_OUT            : out std_logic;
        pol_rx_l_OUT            : out std_logic;
        pri_OUT                 : out std_logic;
		  send_pkt_OUT : out std_logic;
        -- ethernet ports for frequency setting to REX/Passives
--        GIGE_COL                : in  std_logic;
--        GIGE_CRS                : in  std_logic;
        GIGE_MDC                : out std_logic;
        GIGE_MDIO               : inout std_logic;
        GIGE_TX_CLK             : in  std_logic;
        GIGE_nRESET             : out std_logic;
        GIGE_RXD                : in  std_logic_vector(7 downto 0);
        GIGE_RX_CLK             : in  std_logic;
        GIGE_RX_DV              : in  std_logic;
        GIGE_RX_ER              : in  std_logic;
        GIGE_TXD                : out std_logic_vector(7 downto 0);
        GIGE_GTX_CLK            : out std_logic;
        GIGE_TX_EN              : out std_logic;
        GIGE_TX_ER              : out std_logic
    );
end tcu_fc;

architecture behave of tcu_fc is
    attribute S: string;
    attribute KEEP : string;
    -- tcu fsm signals
    type state_type is (IDLE, ARMED, PRE_PULSE, MAIN_BANG, DIGITIZE, DONE, FAULT);
    signal state                    : state_type := IDLE;

    signal start_amp_flag           : std_logic                     := '0';
    signal amp_on_duration          : unsigned(15 downto 0)         := (others => '0');
    signal amp_on_counter           : unsigned(15 downto 0)         := (others => '0');
    signal amp_on                   : std_logic                     := '0';
    signal sw_off_delay             : unsigned(15 downto 0)         := (others => '0');
    signal rex_delay                : unsigned(15 downto 0)         := (others => '0');

    -- amplifier active high/low constants, change if needed
    constant X_POL_TX_HORIZONTAL    : std_logic := '0';
    constant X_POL_TX_VERTICAL      : std_logic := not X_POL_TX_HORIZONTAL;
    constant L_POL_TX_HORIZONTAL    : std_logic := '0';
    constant L_POL_TX_VERTICAL      : std_logic := not L_POL_TX_HORIZONTAL;
    constant L_POL_RX_HORIZONTAL    : std_logic := '0';
    constant L_POL_RX_VERTICAL      : std_logic := not L_POL_RX_HORIZONTAL;
    constant X_AMP_ON               : std_logic := '1';
    constant X_AMP_OFF              : std_logic := not X_AMP_ON;
    constant L_AMP_ON               : std_logic := '0';
    constant L_AMP_OFF              : std_logic := not L_AMP_ON;

    -- pri signals
    signal start_pri_flag           : std_logic                     := '0';
    signal pri_on_duration          : unsigned(31 downto 0)         := (others => '0');
    signal pri_on_counter           : unsigned(31 downto 0)         := (others => '0');
    signal pri_on                   : std_logic                     := '0';

    -- pulse parameters signals
    signal pre_pulse_duration       : unsigned(15 downto 0)         := (others => '0');
    signal main_bang_duration       : unsigned(15 downto 0)         := (others => '0');
    signal digitization_duration    : unsigned(31 downto 0)         := (others => '0');
    signal pol_mode                 : std_logic_vector(2 downto 0)  := (others => '0');
    signal frequency                : std_logic_vector(15 downto 0) := (others => '0');

    -- other signals
    signal pulse_index              : unsigned(4 downto 0)          := (others => '0');
    alias  soft_arm                 : std_logic is instruction_IN(0);
    signal pre_pulse_counter        : unsigned(15 downto 0)         := (others => '0');
    signal main_bang_counter        : unsigned(15 downto 0)         := (others => '0');
    signal digitize_counter         : unsigned(31 downto 0)         := (others => '0');
    signal block_counter            : unsigned(31 downto 0)         := (others => '0');

    constant UDP_DELAY              : natural                       := 10; -- seems to output ~2 udp packets per pulse
    signal udp_counter              : integer range 0 to UDP_DELAY  := 0;


    signal r_instruction            : std_logic_vector(INSTRUCTION_WIDTH-1  downto 0);
    signal r_num_pulses             : std_logic_vector(15 downto 0) := (others => '0');
    signal r_num_repeats            : std_logic_vector(31 downto 0) := (others => '0');
    signal r_x_amp_delay            : std_logic_vector(15 downto 0) := (others => '0');
    signal r_l_amp_delay            : std_logic_vector(15 downto 0) := (others => '0');
    signal r_pre_pulse              : std_logic_vector(15 downto 0) := (others => '0');
    signal r_pri_pulse_width        : std_logic_vector(31 downto 0) := (others => '0');
    signal r_rex_delay              : std_logic_vector(15 downto 0) := (others => '0');

    --    Ethernet Signal declaration section
    attribute S of GIGE_RXD   : signal is "TRUE";
    attribute S of GIGE_RX_DV : signal is "TRUE";
    attribute S of GIGE_RX_ER : signal is "TRUE";

    -- define constants
    constant UDP_TX_DATA_BYTE_LENGTH : integer := 15;        --not SET TO MINIMUM LENGTH
    constant UDP_RX_DATA_BYTE_LENGTH : integer := 37;
    constant TX_DELAY                : integer := 100;

    -- system control
    signal clk_125mhz               : std_logic;
    signal clk_100mhz               : std_logic;
    signal sys_reset                : std_logic;
    signal sysclk_locked            : std_logic;

    -- MAC signals
    signal udp_tx_pkt_data          : std_logic_vector (8 * UDP_TX_DATA_BYTE_LENGTH - 1 downto 0);
    signal udp_tx_pkt_vld           : std_logic;
    signal udp_tx_pkt_sent          : std_logic;
    signal udp_tx_pkt_vld_r         : std_logic;
    signal udp_tx_rdy               : std_logic;

    signal udp_rx_pkt_data          : std_logic_vector(8 * UDP_RX_DATA_BYTE_LENGTH - 1 downto 0);
    signal udp_rx_pkt_data_r        : std_logic_vector(8 * UDP_RX_DATA_BYTE_LENGTH - 1 downto 0);
    signal udp_rx_pkt_req           : std_logic;
    signal udp_rx_rdy               : std_logic;
    signal udp_rx_rdy_r             : std_logic;


    signal dst_mac_addr             : std_logic_vector(47 downto 0);
    signal locked                   : std_logic;
    signal mac_init_done            : std_logic;
    attribute keep of mac_init_done : signal is "true";

    signal GIGE_GTX_CLK_r           : std_logic;
    signal GIGE_MDC_r               : std_logic;

    signal tx_delay_cnt             : integer := 0;

    signal udp_send_packet          : std_logic:='0';
    signal udp_init_packet          : std_logic:='0';
    signal udp_send_packet_r_50     : std_logic:='0';
    signal udp_send_packet_r2_50    : std_logic:='0';
    attribute keep of udp_send_packet: signal  is "TRUE";

    signal udp_send_flag            : std_logic;
    signal udp_receive_packet       : std_logic_vector(1 downto 0) := "00";
    signal udp_packet               : std_logic_vector (8 * UDP_TX_DATA_BYTE_LENGTH - 1 downto 0);
    signal rex_set                  : std_logic;

    signal l_band_freq              : std_logic_vector (15 downto 0) := x"1405";
    signal x_band_freq              : std_logic_vector (15 downto 0) := x"3421";
    signal pol                      : std_logic_vector (15 downto 0) := x"0000";
   signal l_band_freq_r_50         : std_logic_vector (15 downto 0) := x"1405";
   signal x_band_freq_r_50         : std_logic_vector (15 downto 0) := x"3421";
   signal pol_r_50                 : std_logic_vector (15 downto 0) := x"0000";
   signal l_band_freq_r2_50        : std_logic_vector (15 downto 0) := x"1405";
   signal x_band_freq_r2_50        : std_logic_vector (15 downto 0) := x"3421";
   signal pol_r2_50                : std_logic_vector (15 downto 0) := x"0000";

    ---------------------------------------------------------------
    ------------------ UDP Core Declaration Start -----------------
    ---------------------------------------------------------------
    component udp_core is
    	port(
    		clock_125_i : in std_ulogic;

            ip_src_i   : in std_ulogic_vector(31  downto 0);
            ip_dst_i   : in std_ulogic_vector(31  downto 0);
            mac_src_i  : in std_ulogic_vector(47  downto 0);
            mac_dst_i  : in std_ulogic_vector(47  downto 0);
            prt_src_i  : in std_ulogic_vector(15  downto 0);
            prt_dst_i  : in std_ulogic_vector(15  downto 0);
            payload_i  : in std_ulogic_vector(119 downto 0);
            send_pkt_i : in std_ulogic;

    		phy_reset_o    : out   std_ulogic;
    		mdc_o          : out   std_ulogic;
    		mdio_io        : inout std_ulogic;

    		mii_tx_clk_i   : in    std_ulogic;
    		mii_tx_er_o    : out   std_ulogic;
    		mii_tx_en_o    : out   std_ulogic;
    		mii_txd_o      : out   std_ulogic_vector(7 downto 0);
    		mii_rx_clk_i   : in    std_ulogic;
    		mii_rx_er_i    : in    std_ulogic;
    		mii_rx_dv_i    : in    std_ulogic;
    		mii_rxd_i      : in    std_ulogic_vector(7 downto 0);
    		gmii_gtx_clk_o : out   std_ulogic;

    		led_o          : out   std_ulogic_vector(3 downto 0);
    		user_led_o     : out   std_ulogic_vector(1 downto 0)
    	);
    end component;
    ---------------------------------------------------------------
    ------------------ UDP Core Declaration END -------------------
    ---------------------------------------------------------------

begin
    input_registers : process(clk_IN)
    begin
        if rising_edge(clk_IN) then
            -- pulse parameter decoding
            pre_pulse_duration      <= unsigned(pre_pulse_IN); -- = 30us
            main_bang_duration      <= unsigned(pulse_params_IN(15 downto 0));
            digitization_duration   <= unsigned(pulse_params_IN(47 downto 32) & pulse_params_IN(31 downto 16));-- =
            pol_mode                <= pulse_params_IN(50 downto 48);
            frequency               <= pulse_params_IN(79 downto 64);

            if pol_mode(2) = '1' then
                x_band_freq <= frequency;
                pol         <= x"0100";
            else
                l_band_freq <= frequency;
                pol         <= x"0000";
            end if;

            r_instruction     <= instruction_IN;
            r_num_pulses      <= num_pulses_IN;
            r_num_repeats     <= num_repeats_IN;
            r_x_amp_delay     <= x_amp_delay_IN;
            r_l_amp_delay     <= l_amp_delay_IN;
            r_pre_pulse       <= pre_pulse_IN;
            r_pri_pulse_width <= pri_pulse_width_IN;
            r_rex_delay       <= rex_delay_IN;
        end if;
    end process;

    -- TCU FSM
    fsm : process(clk_IN, rst_IN, trigger_IN)
    begin
        if rising_edge(clk_IN) then
            if rst_IN = '1' then
                pre_pulse_counter   <= (others => '0');
                main_bang_counter   <= (others => '0');
                digitize_counter    <= (others => '0');
                block_counter       <= (others => '0');
                state               <= IDLE;
                start_amp_flag      <= '0';
                start_pri_flag      <= '0';

            else

                case(state) is

                    when IDLE =>
                        status_OUT(2 downto 0) <= "000";
                        if soft_arm = '1' then
                            state <= ARMED;
                            udp_init_packet <= '1';
                        else
                            state <= IDLE;
                        end if;

                    when ARMED =>
                    udp_init_packet <= '0';
                        status_OUT(2 downto 0) <= "001";
                        if soft_arm = '0' then
                            state <= IDLE;
                        elsif trigger_IN = '1' then
                            state <= PRE_PULSE;
                        else
                            state <= ARMED;
                        end if;

                    when PRE_PULSE =>
                        status_OUT(2 downto 0) <= "010";
                        start_amp_flag    <= '1';
                        -- udp_send_packet   <= '1';
                        pre_pulse_counter <= pre_pulse_counter + x"0001";
                        if pre_pulse_counter >= (pre_pulse_duration-1) then
                            -- udp_send_packet   <= '0';
                            start_amp_flag    <= '0';
                            start_pri_flag    <= '1';
                            state             <= MAIN_BANG;
                            pre_pulse_counter <= (others => '0');
                        else
                            state <= PRE_PULSE;
                        end if;

                    when MAIN_BANG =>
                        status_OUT(2 downto 0) <= "011";
                        start_pri_flag         <= '0';
                        main_bang_counter      <= main_bang_counter + x"0001";
                        if main_bang_counter >= (main_bang_duration-1) then
                            state <= DIGITIZE;
                            main_bang_counter <= (others => '0');
                        else
                            state <= MAIN_BANG;
                        end if;

                    when DIGITIZE =>
                        status_OUT(2 downto 0) <= "100";
                        digitize_counter <= digitize_counter + x"00000001";

                        if digitize_counter >= (digitization_duration-1)  then
                            pulse_index      <= pulse_index + "00001";
                            digitize_counter <= (others => '0');

                            if block_counter >= (unsigned(r_num_repeats)-1) then
                                block_counter <= (others => '0');
                                pulse_index   <= (others => '0');
                                state         <= DONE;
                            else
                                if pulse_index = (unsigned(r_num_pulses)-1) then
                                    block_counter <= block_counter + x"00000001";
                                    pulse_index   <= (others => '0');
                                end if;

                                state <= PRE_PULSE;
                            end if;
                        else
                            state <= DIGITIZE;
                        end if;

                    when DONE =>
                        status_OUT(2 downto 0) <= "101";
                                if soft_arm = '1' then
                                    state <= DONE;
                                else
                                    state <= IDLE;
                                end if;

                    when OTHERS =>
                        status_OUT(2 downto 0) <= "110";
                        state                  <= FAULT;
                end case;

            end if;
        end if;
    end process;

    pulse_index_OUT <= std_logic_vector(pulse_index);

    amplifiers : process(clk_IN, rst_IN, start_amp_flag)
    begin
        if rising_edge(clk_IN) then
            if rst_IN = '1' then
                amp_on <= '0';
                amp_on_counter <= (others => '0');
            else
                if start_amp_flag = '1' then
                    amp_on <= '1';
						  udp_send_packet <= '1';
                end if;
                if amp_on = '1' then
							udp_send_packet <= '0';
                    amp_on_counter <= amp_on_counter + x"0001";
                    if amp_on_counter >= (amp_on_duration-1) then -- -3 to compensate for 2 cycle lag
                        amp_on <= '0';
                        amp_on_counter <= (others => '0');
                    end if;
                end if;
            end if;
        end if;
    end process;

    rex_delay    <= unsigned(r_rex_delay);
    sw_off_delay <= unsigned(r_l_amp_delay) when pol_mode(2) = '0' else unsigned(r_x_amp_delay);
    bias_L_OUT   <= L_AMP_ON when amp_on = '1' and pol_mode(2) = '0' else L_AMP_OFF;
    bias_X_OUT   <= X_AMP_ON when amp_on = '1' and pol_mode(2) = '1' else X_AMP_OFF;
    process(clk_IN)
    begin
        if rising_edge(clk_IN) then
            amp_on_duration <= pre_pulse_duration + main_bang_duration - sw_off_delay + rex_delay;
        end if;
    end process;

    pri : process(clk_IN, rst_IN, start_pri_flag)
    begin
        if rising_edge(clk_IN) then
            if rst_IN = '1' then
                pri_on <= '0';
                pri_on_counter <= (others => '0');
            else
                if start_pri_flag = '1' then
                    pri_on <= '1';
                end if;
                if pri_on = '1' then
                    pri_on_counter <= pri_on_counter + x"000001";
                    if pri_on_counter >= (pri_on_duration) then
                        pri_on <= '0';
                        pri_on_counter <= (others => '0');
                    end if;
                end if;
            end if;
            pri_on_duration <= unsigned(r_pri_pulse_width);
            pri_OUT <= pri_on;
        end if;
    end process;

    amp_pol_switches : process(clk_IN, rst_IN, state)
    begin
        if rising_edge(clk_IN) then
            if rst_IN = '1' then
                pol_rx_l_OUT <= '0';
                pol_tx_l_OUT <= '0';
                pol_tx_x_OUT <= '0';
            else
                --  X-band pulse
                if pol_mode(2) = '1' then
                    if pol_mode(0) = '0' then
                        pol_tx_x_OUT <= X_POL_TX_HORIZONTAL;
                    else
                        pol_tx_x_OUT <= X_POL_TX_VERTICAL;
                    end if;
                -- L-band pulse
                else
                    if pol_mode(1) = '1' then
                        pol_tx_l_OUT <= L_POL_TX_HORIZONTAL;
                    else
                        pol_tx_l_OUT <= L_POL_TX_VERTICAL;
                    end if;
                    if pol_mode(0) = '1' then
                        pol_rx_l_OUT <= L_POL_RX_HORIZONTAL;
                    else
                        pol_rx_l_OUT <= L_POL_RX_VERTICAL;
                    end if;
                end if;
            end if;
        end if;
    end process;

    synch_ff1 : process(clk_125MHz_IN)
    begin
        if rising_edge(clk_125MHz_IN) then
            -- udp_send_packet_r_50 <= udp_send_packet or udp_init_packet;
            udp_send_packet_r_50 <= udp_init_packet;
            l_band_freq_r_50     <= l_band_freq;
            x_band_freq_r_50     <= x_band_freq;
            pol_r_50             <= pol;
        end if;
    end process;

    synch_ff2 : process(clk_125MHz_IN)
    begin
        if rising_edge(clk_125MHz_IN) then
            udp_send_packet_r2_50 <= udp_send_packet_r_50;
            l_band_freq_r2_50     <= l_band_freq_r_50;
            x_band_freq_r2_50     <= x_band_freq_r_50;
            pol_r2_50             <=pol_r_50;
        end if;
    end process;

    udp_tx_pkt_data <= x"0d000000000004000300" & l_band_freq_r2_50 & x_band_freq_r2_50 & pol_r2_50(15 downto 8);
    -- udp_tx_pkt_data <= x"0d000000000004000300" & l_band_freq & x_band_freq & pol;

    freq_set : process(clk_125MHz_IN)
    begin
        if(rising_edge(clk_125MHz_IN)) then
            if udp_counter = 0 then
                if udp_send_packet_r2_50 = '1' then
                    udp_tx_pkt_vld_r <= '1';
                    udp_counter      <= udp_counter + 1;
                end if;
            else
                udp_tx_pkt_vld_r <= '0';
                udp_counter      <= udp_counter + 1;
                if udp_counter = UDP_DELAY then
                    udp_counter <= 0;
                end if;
            end if;
        end if;
    end process;

    udp_tx_pkt_vld <= udp_tx_pkt_vld_r;

    ---------------------------------------------------------------
    ---------------- UDP Core Instantiation START -----------------
    ---------------------------------------------------------------
    Inst_udp_core: udp_core
    PORT MAP(
        clock_125_i => clk_125MHz_IN,

        ip_src_i    => x"c0a83601",     -- 192.168.54.1
        ip_dst_i    => x"c0a83664",     -- 192.168.54.100
        mac_src_i   => x"0e0e0e0e0e0b",
        mac_dst_i   => x"0014a372173f", -- MAC PASSIVE
        prt_src_i   => x"1f40",         --8000
        prt_dst_i   => x"2711",         --10001

        payload_i   => std_ulogic_vector(udp_tx_pkt_data),
        send_pkt_i  => std_ulogic(udp_send_packet_r2_50),

        std_logic(mdc_o)            => GIGE_MDC,
        mdio_io                     => std_ulogic(GIGE_MDIO), -- check this
        mii_tx_clk_i                => std_ulogic(GIGE_TX_CLK),
        std_logic(phy_reset_o)      => GIGE_nRESET,
        mii_rxd_i                   => std_ulogic_vector(GIGE_RXD),
        mii_rx_clk_i                => std_ulogic(GIGE_RX_CLK),
        mii_rx_dv_i                 => std_ulogic(GIGE_RX_DV),
        mii_rx_er_i                 => std_ulogic(GIGE_RX_ER),
        std_logic_vector(mii_txd_o) => GIGE_TXD,
        std_logic(gmii_gtx_clk_o)   => GIGE_GTX_CLK,
        std_logic(mii_tx_en_o)      => GIGE_TX_EN,
        std_logic(mii_tx_er_o)      => GIGE_TX_ER,

        led_o => open,
        user_led_o => open

    );
    ---------------------------------------------------------------
    ---------------- UDP Core Instantiation END -------------------
    ---------------------------------------------------------------
send_pkt_OUT <= udp_tx_pkt_vld;
end behave;
