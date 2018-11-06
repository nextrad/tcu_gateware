library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

Library UNISIM;
use UNISIM.vcomponents.all;

entity tcu_fc_reg_top is
  port (
        -- External clock source
        i_CLK_P         : in std_logic;
        i_CLK_N         : in std_logic;
        o_LOGIC_HIGH    : out std_logic;

        -- GPMC ports
        i_GPMC_A        : in    std_logic_vector(10 downto 1);
        io_GPMC_D       : inout std_logic_vector(15 downto 0);
        i_GPMC_CLK      : in    std_logic;
        i_GPMC_N_CS     : in    std_logic_vector(6  downto 0);
        i_GPMC_N_WE     : in    std_logic;
        i_GPMC_N_OE     : in    std_logic;
        i_GPMC_N_ADV_ALE: in    std_logic;

        -- Interface ports
        i_RESET         : in  std_logic;
        i_TRIGGER       : in  std_logic;
        o_BIAS_X        : out std_logic;
        o_BIAS_L        : out std_logic;
        o_POL_TX_X      : out std_logic;
        o_POL_TX_L      : out std_logic;
        o_POL_RX_L      : out std_logic;
        o_PRI           : out std_logic;
        o_TRIGGER       : out std_logic;
        o_STATUS_BUZ    : out std_logic;
        o_STATUS_LED    : out std_logic_vector(3 downto 0);

        -- LED indicator ports
        o_LED_RHINO     : out   std_logic_vector(7 downto 0);
        o_LED_FMC       : out   std_logic_vector(3 downto 0);

        -- 1Gbps ethernet ports
        GIGE_MDC        : out std_logic;
        GIGE_MDIO       : inout std_logic;
        GIGE_TX_CLK     : in std_logic;
        GIGE_nRESET     : out std_logic;
        GIGE_RXD        : in std_logic_vector(7 downto 0);
        GIGE_RX_CLK     : in std_logic;
        GIGE_RX_DV      : in std_logic;
        GIGE_RX_ER      : in std_logic;
        GIGE_TXD        : out std_logic_vector(7 downto 0);
        GIGE_GTX_CLK    : out std_logic;
        GIGE_TX_EN      : out std_logic;
        GIGE_TX_ER      : out std_logic
  );
end entity;

architecture structural of tcu_fc_reg_top is
    COMPONENT gpmc_wb
    PORT(
        gpmc_a          : IN    std_logic_vector(10 downto 1);
        gpmc_clk_i      : IN    std_logic;
        gpmc_n_cs       : IN    std_logic_vector(6 downto 0);
        gpmc_n_we       : IN    std_logic;
        gpmc_n_oe       : IN    std_logic;
        gpmc_n_adv_ale  : IN    std_logic;
        sys_clk_P       : IN    std_logic;
        sys_clk_N       : IN    std_logic;
        ACK_I           : IN    std_logic;
        DAT_I           : IN    std_logic_vector(15 downto 0);
        ADR_O           : OUT   std_logic_vector(7 downto 0);
        gpmc_d          : INOUT std_logic_vector(15 downto 0);
        CLK_400MHz      : OUT   std_logic;
        CLK_100MHz      : OUT   std_logic;
        CLK_125MHz      : OUT   STD_LOGIC;
        CLK             : OUT   std_logic;
        RST             : OUT   std_logic;
        DAT_O           : OUT   std_logic_vector(15 downto 0);
        WE_O            : OUT   std_logic;
        slave_sel_OUT   : OUT   std_logic
        );
    END COMPONENT;

    -- Interconnecting signals

    signal s_clk_100    : std_logic:='0';
    signal s_clk_125    : std_logic:='0';
    signal s_clk_locked : std_logic:='0';
    signal s_rst_sys    : std_logic;
    signal s_clk_wb     : std_logic:='0';
    signal s_rst_wb     : std_logic:='0';
    signal s_ack        : std_logic:='0';
    signal s_dat_m2s    : std_logic_vector(15 downto 0):=(others=>'0');
    signal s_dat_s2m    : std_logic_vector(15 downto 0):=(others=>'0');
    signal s_adr        : std_logic_vector(7 downto 0):=(others=>'0');
    signal s_we         : std_logic:='0';
    signal s_slave_sel  : std_logic:='0';
    signal s_clk_400MHz  : std_logic:='0';

    signal s_status : std_logic_vector(15 downto 0):=(others=>'0');

    COMPONENT tcu_fc_reg
    PORT(
         -- control_INOUT : inout std_logic_vector(35 downto 0);

        clk_IN          : IN    std_logic;
        clk_125MHz_IN           : in  std_logic;
        rst_IN          : IN    std_logic;
        trigger_IN      : IN    std_logic;
        CLK_I           : IN    std_logic;
        RST_I           : IN    std_logic;
        STB_I           : IN    std_logic;
        WE_I            : IN    std_logic;
        DAT_I           : IN    std_logic_vector(15 downto 0);
        ADR_I           : IN    std_logic_vector(7 downto 0);
        status_OUT      : OUT   std_logic_vector(15 downto 0);
        bias_x_OUT      : OUT   std_logic;
        bias_l_OUT      : OUT   std_logic;
        pol_tx_x_OUT    : OUT   std_logic;
        pol_tx_l_OUT    : OUT   std_logic;
        pol_rx_l_OUT    : OUT   std_logic;
        pri_OUT         : OUT   std_logic;
        ACK_O           : OUT   std_logic;
        DAT_O           : OUT   std_logic_vector(15 downto 0);
        GIGE_MDC        : out std_logic;
        GIGE_MDIO       : inout std_logic;
        GIGE_TX_CLK     : in std_logic;
        GIGE_nRESET     : out std_logic;
        GIGE_RXD        : in std_logic_vector(7 downto 0);
        GIGE_RX_CLK     : in std_logic;
        GIGE_RX_DV      : in std_logic;
        GIGE_RX_ER      : in std_logic;
        GIGE_TXD        : out std_logic_vector(7 downto 0);
        GIGE_GTX_CLK    : out std_logic;
        GIGE_TX_EN      : out std_logic;
        GIGE_TX_ER      : out std_logic
        );
    END COMPONENT;

    -- slow clocks for LEDs
    signal clk_0_5Hz    : std_logic := '0';
    signal clk_1Hz      : std_logic := '0';
    signal clk_2Hz      : std_logic := '0';
    signal clk_5Hz      : std_logic := '0';
    signal clk_1KHz     : std_logic := '0';

    type buzzer_state_type is (IDLE, START, RUNNING, DONE, FAULT);
    signal buzzer_state : buzzer_state_type := IDLE;

    signal s_beep_flag            : std_logic := '0';
    signal beep_duration_ms     : integer;
    signal beep_duration_counter: integer := 0;
    signal beep_period_ms       : integer;
    signal beep_period_counter  : integer := 0;

begin

    o_LOGIC_HIGH <= '1';
    Inst_gpmc_wb: gpmc_wb
    PORT MAP(
        gpmc_a          => i_GPMC_A,
        gpmc_d          => io_GPMC_D,
        gpmc_clk_i      => i_GPMC_CLK,
        gpmc_n_cs       => i_GPMC_N_CS,
        gpmc_n_we       => i_GPMC_N_WE,
        gpmc_n_oe       => i_GPMC_N_OE,
        gpmc_n_adv_ale  => i_GPMC_N_ADV_ALE,
        sys_clk_P       => i_CLK_P,
        sys_clk_N       => i_CLK_N,
        CLK_400MHz      => s_clk_400MHz,
        CLK_100MHz      => s_clk_100,
        CLK_125MHz      => s_clk_125,
        CLK             => s_clk_wb,
        RST             => s_rst_wb,
        ACK_I           => s_ack,
        ADR_O           => s_adr,
        DAT_I           => s_dat_s2m,
        DAT_O           => s_dat_m2s,
        WE_O            => s_we,
        slave_sel_OUT   => s_slave_sel
    );

    Inst_tcu_fc_reg: tcu_fc_reg
    PORT MAP(
        clk_IN          => s_clk_100,
        clk_125MHz_IN          => s_clk_125,
        -- rst_IN          => s_rst_wb, -- CHECK THIS
        rst_IN          => s_rst_sys, -- CHECK THIS
        trigger_IN      => i_TRIGGER,
        status_OUT      => s_status,
        bias_x_OUT      => o_BIAS_X,
        bias_l_OUT      => o_BIAS_L,
        pol_tx_x_OUT    => o_POL_TX_X,
        pol_tx_l_OUT    => o_POL_TX_L,
        pol_rx_l_OUT    => o_POL_RX_L,
        pri_OUT         => o_PRI,
        CLK_I           => s_clk_wb,
        -- RST_I           => s_rst_wb,
        RST_I           => s_rst_sys,
        STB_I           => s_slave_sel,
        WE_I            => s_we,
        DAT_I           => s_dat_m2s,
        ADR_I           => s_adr,
        ACK_O           => s_ack,
        DAT_O           => s_dat_s2m,
        GIGE_MDC => GIGE_MDC,
        GIGE_MDIO => GIGE_MDIO,
        GIGE_TX_CLK => GIGE_TX_CLK,
        GIGE_nRESET => GIGE_nRESET,
        GIGE_RXD => GIGE_RXD,
        GIGE_RX_CLK => GIGE_RX_CLK,
        GIGE_RX_DV => GIGE_RX_DV,
        GIGE_RX_ER => GIGE_RX_ER,
        GIGE_TXD => GIGE_TXD,
        GIGE_GTX_CLK => GIGE_GTX_CLK,
        GIGE_TX_EN => GIGE_TX_EN,
        GIGE_TX_ER => GIGE_TX_ER
    );

    s_rst_sys  <= not i_RESET;
    --s_rst_sys  <= '0';
    o_LED_RHINO(4 downto 0) <= s_status(4 downto 0);
    with buzzer_state select o_LED_RHINO(7 downto 5) <=
        "001" when START,
        "010" when RUNNING,
        "100" when DONE,
        "111" when OTHERS;

    with s_status select o_TRIGGER <=
        '1' when x"0002",
        '1' when x"0003",
        '1' when x"0004",
        '0' when OTHERS;

    with s_status select o_LED_FMC <=
        clk_0_5Hz&"000"                 when x"0000",
        clk_2Hz&(not clk_2Hz)&"00"      when x"0001",
        clk_5Hz&clk_5Hz&clk_5Hz&clk_5Hz when x"0002",
        clk_5Hz&clk_5Hz&clk_5Hz&clk_5Hz when x"0003",
        clk_5Hz&clk_5Hz&clk_5Hz&clk_5Hz when x"0004",
        "1111"                          when x"0005",
        clk_2Hz &"00"&(not clk_2Hz)     when OTHERS;

    beep_interval : process(clk_1KHz)
    begin
        if rising_edge(clk_1KHz) then
            if beep_period_counter > (beep_period_ms - 1) then
                s_beep_flag <= '1';
                beep_period_counter <= 0;
            else
                s_beep_flag <= '0';
                beep_period_counter <= beep_period_counter + 1;
            end if;
        end if;
    end process beep_interval;

    beep_duration : process(clk_1KHz, s_beep_flag)
    begin
        if rising_edge(clk_1KHz) then
            if s_beep_flag = '1' then
                beep_duration_counter <= 0;
            end if;
            if beep_duration_counter < (beep_duration_ms - 1) then
                o_STATUS_BUZ <= '1';
                beep_duration_counter <= beep_duration_counter + 1;
            else
                o_STATUS_BUZ <= '0';
            end if;
        end if;
    end process beep_duration;


    status_buzzer : process(clk_1KHz)
        variable state_duration_counter : integer := 0;
    begin
        if rising_edge(clk_1KHz) then
            case(buzzer_state) is
                when IDLE =>
                    beep_duration_ms <= 0;
                    beep_period_ms   <= 0;
                    if (s_status =  x"0002") or (s_status =  x"0003") or (s_status =  x"0004") then
                        buzzer_state <= START;
                    else
                        buzzer_state <= IDLE;
                    end if;
                when START =>
                    beep_duration_ms <= 100;
                    beep_period_ms   <= 200;
                    if s_status = x"0000" then
                        buzzer_state <= IDLE;
                    elsif state_duration_counter >= 2000 then
                        buzzer_state <= RUNNING;
                        state_duration_counter := 0;
                    else
                        buzzer_state <= START;
                        state_duration_counter := state_duration_counter + 1;
                    end if;
                when RUNNING =>
                    beep_duration_ms <= 100;
                    beep_period_ms   <= 5000;
                    if s_status = x"0000" then
                        buzzer_state <= IDLE;
                    elsif s_status =  x"0005" then
                        buzzer_state <= DONE;
                    else
                        buzzer_state <= RUNNING;
                    end if;
                when DONE =>
                    beep_duration_ms <= 500;
                    beep_period_ms   <= 1000;
                    if s_status = x"0000" then
                        buzzer_state <= IDLE;
                    elsif state_duration_counter >= 2000 then
                        buzzer_state <= IDLE;
                        state_duration_counter := 0;
                    else
                        buzzer_state <= DONE;
                        state_duration_counter := state_duration_counter + 1;
                    end if;
                when FAULT =>
                    beep_duration_ms <= 2000;
                    beep_period_ms   <= 3000;
                    if s_status = x"0000" then
                        buzzer_state <= IDLE;
                    else
                        buzzer_state <= FAULT;
                    end if;
                when others =>
                    buzzer_state <= FAULT;
            end case;
        end if;
    end process status_buzzer;

    status_leds : process(s_status)
    begin
        case(s_status) is
            when x"0000" =>     -- IDLE
                o_STATUS_LED <= "0001";
            when x"0001" =>     -- ARMED
                o_STATUS_LED <= "0010";
            when x"0002" =>     -- RUNNING
                o_STATUS_LED <= "0100";
            when x"0003" =>     -- RUNNING
                o_STATUS_LED <= "0100";
            when x"0004" =>     -- RUNNING
                o_STATUS_LED <= "0100";
            when x"0005" =>     -- DONE
                o_STATUS_LED <= "0111";
            when others =>      -- FAULT
                o_STATUS_LED <= "1000";
        end case;
    end process status_leds;

        -- slow clock to drive LEDs
        process (s_clk_100)
        variable prescaler_0_5Hz    : integer := 0;
        variable prescaler_1Hz      : integer := 0;
        variable prescaler_2Hz      : integer := 0;
        variable prescaler_5Hz      : integer := 0;
        variable prescaler_1KHz     : integer := 0;
        begin

            if rising_edge(s_clk_100) then
                if prescaler_0_5Hz = 100_000_000 then
                    clk_0_5Hz <= not clk_0_5Hz;
                    prescaler_0_5Hz := 0;
                else
                    prescaler_0_5Hz := prescaler_0_5Hz + 1;
                end if;
                if prescaler_1Hz = 50_000_000 then
                    clk_1Hz <= not clk_1Hz;
                    prescaler_1Hz := 0;
                else
                    prescaler_1Hz := prescaler_1Hz + 1;
                end if;
                if prescaler_2Hz = 25_000_000 then
                    clk_2Hz <= not clk_2Hz;
                    prescaler_2Hz := 0;
                else
                    prescaler_2Hz := prescaler_2Hz + 1;
                end if;
                if prescaler_5Hz = 10_000_000 then
                    clk_5Hz <= not clk_5Hz;
                    prescaler_5Hz := 0;
                else
                    prescaler_5Hz := prescaler_5Hz + 1;
                end if;
                if prescaler_1KHz = 50_000 then
                    clk_1KHz <= not clk_1KHz;
                    prescaler_1KHz := 0;
                else
                    prescaler_1KHz := prescaler_1KHz + 1;
                end if;
            end if;
        end process;

end architecture;
