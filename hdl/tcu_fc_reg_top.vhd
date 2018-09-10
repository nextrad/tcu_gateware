library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

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
        i_TRIGGER       : in  std_logic;
        o_BIAS_X        : out std_logic;
        o_BIAS_L        : out std_logic;
        o_POL_TX_X      : out std_logic;
        o_POL_TX_L      : out std_logic;
        o_POL_RX_L      : out std_logic;
        o_PRI           : out std_logic;
        o_TRIGGER       : out std_logic;
        o_STATUS        : out std_logic;

        -- LED indicator ports
        o_LED_RHINO     : out   std_logic_vector(7 downto 0);
        o_LED_FMC       : out   std_logic_vector(3 downto 0)

        -- TODO: 1Gbps ethernet ports
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
        CLK             : OUT   std_logic;
        RST             : OUT   std_logic;
        DAT_O           : OUT   std_logic_vector(15 downto 0);
        WE_O            : OUT   std_logic;
        slave_sel_OUT   : OUT   std_logic
        );
    END COMPONENT;

    -- Interconnecting signals


    signal s_clk_100    : std_logic;
    signal s_rst_sys    : std_logic;
    signal s_clk_wb     : std_logic;
    signal s_rst_wb     : std_logic;
    signal s_ack        : std_logic;
    signal s_dat_m2s    : std_logic_vector(15 downto 0);
    signal s_dat_s2m    : std_logic_vector(15 downto 0);
    signal s_adr        : std_logic_vector(7 downto 0);
    signal s_we         : std_logic;
    signal s_slave_sel  : std_logic;
    signal s_clk_400MHz  : std_logic;

    signal s_status : std_logic_vector(15 downto 0);

    COMPONENT tcu_fc_reg
    PORT(
         -- control_INOUT : inout std_logic_vector(35 downto 0);

        clk_IN          : IN    std_logic;
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
        DAT_O           : OUT   std_logic_vector(15 downto 0)
        );
    END COMPONENT;

    -- slow clocks for LEDs
    signal clk_0_5Hz    : std_logic := '0';
    signal clk_1Hz      : std_logic := '0';
    signal clk_2Hz      : std_logic := '0';
    signal clk_5Hz      : std_logic := '0';
    signal clk_1KHz     : std_logic := '0';

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
        rst_IN          => s_rst_sys,
        trigger_IN      => i_TRIGGER,
        status_OUT      => s_status,
        bias_x_OUT      => o_BIAS_X,
        bias_l_OUT      => o_BIAS_L,
        pol_tx_x_OUT    => o_POL_TX_X,
        pol_tx_l_OUT    => o_POL_TX_L,
        pol_rx_l_OUT    => o_POL_RX_L,
        pri_OUT         => o_PRI,
        CLK_I           => s_clk_wb,
        RST_I           => s_rst_wb,
        STB_I           => s_slave_sel,
        WE_I            => s_we,
        DAT_I           => s_dat_m2s,
        ADR_I           => s_adr,
        ACK_O           => s_ack,
        DAT_O           => s_dat_s2m
    );

    o_LED_RHINO <= s_status(7 downto 0);

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

    with s_status select o_STATUS <=
        clk_1Hz   when x"0000",
        clk_2Hz   when x"0001",
        clk_5Hz   when x"0002",
        clk_5Hz   when x"0003",
        clk_5Hz   when x"0004",
        '1'       when x"0005",
        clk_0_5Hz when OTHERS;

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
