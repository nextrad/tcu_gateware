-- ------------------------------------------------------------------------------------------------
-- NAME:             tcu_registers.vhd
-- Description:      skeleton VHDL for IPCore
--
-- VHDL code autogenerated by FPGA-CPU-HYBRID-FRAMEWORKv0.1
-- Autogenerated at 23:27:27 on 03-03-2018
-- For more information about this framework visit: <URL TO Github Repo>
-- ------------------------------------------------------------------------------------------------


LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
LIBRARY UNISIM;
USE UNISIM.VComponents.ALL;

ENTITY tcu_registers IS
GENERIC (
    WB_DATA_BUS_WIDTH    : POSITIVE := 16;
    WB_ADDRESS_BUS_WIDTH : NATURAL := 8
    );
PORT (
    -- ------------------------------------------------------------------------------------------------
    -- USER-DEFINED PORTS
    -- ------------------------------------------------------------------------------------------------
    clk_IN              : in    STD_LOGIC;
    rst_IN              : in    STD_LOGIC;
    pulse_index_IN      : in    STD_LOGIC_VECTOR(4 DOWNTO 0);
    status_IN           : in    STD_LOGIC_VECTOR(15 DOWNTO 0);
    status_OUT          : out   STD_LOGIC_VECTOR(15 DOWNTO 0);
    instruction_OUT     : out   STD_LOGIC_VECTOR(15 DOWNTO 0);
    num_pulses_OUT      : out   STD_LOGIC_VECTOR(15 DOWNTO 0);
    num_repeats_OUT     : out   STD_LOGIC_VECTOR(31 DOWNTO 0);
    x_amp_delay_OUT     : out   STD_LOGIC_VECTOR(15 DOWNTO 0);
    l_amp_delay_OUT     : out   STD_LOGIC_VECTOR(15 DOWNTO 0);
    rex_delay_OUT       : out   STD_LOGIC_VECTOR(15 DOWNTO 0);
    pre_pulse_OUT       : out   STD_LOGIC_VECTOR(15 DOWNTO 0);
    pri_pulse_width_OUT : out   STD_LOGIC_VECTOR(31 DOWNTO 0);
    pulse_params_OUT    : out   STD_LOGIC_VECTOR(79 DOWNTO 0);

    -- ------------------------------------------------------------------------------------------------
    -- WISHBONE PORTS - DO NOT MODIFY
    -- ------------------------------------------------------------------------------------------------
    CLK_I   : IN    STD_LOGIC;
    RST_I   : IN    STD_LOGIC;
    STB_I   : IN    STD_LOGIC;
    WE_I    : IN    STD_LOGIC;
    DAT_I   : IN    STD_LOGIC_VECTOR(WB_DATA_BUS_WIDTH - 1 DOWNTO 0);
    ADR_I   : IN    STD_LOGIC_VECTOR(WB_ADDRESS_BUS_WIDTH - 1 DOWNTO 0);
    ACK_O   : OUT   STD_LOGIC;
    DAT_O   : OUT   STD_LOGIC_VECTOR(WB_DATA_BUS_WIDTH - 1 DOWNTO 0)
    );
END tcu_registers;

ARCHITECTURE behavioral OF tcu_registers IS

    ---------------------------------------------------------------------------------------
    -- REGISTER DECLARTIONS
    ---------------------------------------------------------------------------------------

    --  TODO:   add address bases for other registers
    --          add version register

    CONSTANT REGISTER_PULSE_PARAMS_BASE    :   NATURAL := 7;
    CONSTANT REGISTER_PULSE_PARAMS_END     :   NATURAL := 166;

    TYPE array_type IS ARRAY (INTEGER RANGE <>) OF STD_LOGIC_VECTOR(15 DOWNTO 0);

    SIGNAL num_pulses_reg       : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"0001";        -- 1 pulses
    SIGNAL num_repeats_reg      : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"ffffffff";    --  repeats
    SIGNAL pre_pulse_reg        : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"0bb8";        -- 30.0us
    SIGNAL pri_pulse_width_reg  : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"0000c350";    -- 500.0us
    SIGNAL x_amp_delay_reg      : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"015e";        -- 3.5us
    SIGNAL l_amp_delay_reg      : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"0064";        -- 1.0us
    SIGNAL rex_delay_reg        : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"0096";        -- 1.5us

    SIGNAL pulse_params_reg     : array_type(0 to (REGISTER_PULSE_PARAMS_END - REGISTER_PULSE_PARAMS_BASE)) :=
    (
        -- <p. width>, <pri_lower>, <pri_upper>, <mode>, <freq>
        -- pulse 0
        x"03e8", x"7700", x"0001", x"0000", x"1405",
        others => x"ffff"
    );
    SIGNAL status_reg           : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
    SIGNAL instruction_reg      : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');

    SIGNAL dat_o_sig            : STD_LOGIC_VECTOR(WB_DATA_BUS_WIDTH - 1 DOWNTO 0) := (OTHERS => 'Z');

    ---------------------------------------------------------------------------------------
    -- IP CORE SPECIFIC SIGNALS
    ---------------------------------------------------------------------------------------
    -- TODO: declare your signals here
    signal pulse_index : integer range 0 to 31 := 0;

BEGIN

    -- ------------------------------------------------------------------------------------------------
    -- WISHBONE FSM - DO NOT MODIFY
    -- ------------------------------------------------------------------------------------------------

    process (CLK_I, RST_I, ADR_I)
    VARIABLE address_int : INTEGER := 0; -- TODO: could define a range, or leave as 32bits...
    begin
        address_int := TO_INTEGER(UNSIGNED(ADR_I));
        IF RISING_EDGE(CLK_I) THEN
            if RST_I = '1' THEN
                num_pulses_reg <= (OTHERS =>'0');
                num_repeats_reg <= (OTHERS =>'0');
                x_amp_delay_reg <= (OTHERS =>'0');
                l_amp_delay_reg <= (OTHERS =>'0');
                pri_pulse_width_reg <= (OTHERS =>'0');
                -- pulse_params_reg <= (OTHERS => (OTHERS => '1'));
                instruction_reg <= (OTHERS =>'0');
                rex_delay_reg <= (OTHERS =>'0');
            elsif STB_I = '1' then
            -- if STB_I = '1' then
                case TO_INTEGER(UNSIGNED(ADR_I)) is
                    -- ------------------------------------------------------------------------------------------------
                    -- REGISTER: num_pulses    SIZE: 2 bytes    PERMISSIONS: read and write
                    -- ------------------------------------------------------------------------------------------------
                    when 0 =>
                        if WE_I = '1' THEN
                            num_pulses_reg(15 downto 0) <= DAT_I;
                        else
                            dat_o_sig <= num_pulses_reg(15 downto 0);
                        end if;
                    -- ------------------------------------------------------------------------------------------------
                    -- REGISTER: num_repeats    SIZE: 4 bytes    PERMISSIONS: read and write
                    -- ------------------------------------------------------------------------------------------------
                    when 1 =>
                        if WE_I = '1' THEN
                            num_repeats_reg(15 downto 0) <= DAT_I;
                        else
                            dat_o_sig <= num_repeats_reg(15 downto 0);
                        end if;
                    when 2 =>
                        if WE_I = '1' THEN
                            num_repeats_reg(31 downto 16) <= DAT_I;
                        else
                            dat_o_sig <= num_repeats_reg(31 downto 16);
                        end if;
                    -- ------------------------------------------------------------------------------------------------
                    -- REGISTER: x_amp_delay    SIZE: 2 bytes    PERMISSIONS: read and write
                    -- ------------------------------------------------------------------------------------------------
                    when 3 =>
                        if WE_I = '1' THEN
                            x_amp_delay_reg(15 downto 0) <= DAT_I;
                        else
                            dat_o_sig <= x_amp_delay_reg(15 downto 0);
                        end if;
                    -- ------------------------------------------------------------------------------------------------
                    -- REGISTER: l_amp_delay    SIZE: 2 bytes    PERMISSIONS: read and write
                    -- ------------------------------------------------------------------------------------------------
                    when 4 =>
                        if WE_I = '1' THEN
                            l_amp_delay_reg(15 downto 0) <= DAT_I;
                        else
                            dat_o_sig <= l_amp_delay_reg(15 downto 0);
                        end if;
                    -- ------------------------------------------------------------------------------------------------
                    -- REGISTER: pri_pulse_width    SIZE: 4 bytes    PERMISSIONS: read and write
                    -- ------------------------------------------------------------------------------------------------
                    when 5 =>
                        if WE_I = '1' THEN
                            pri_pulse_width_reg(15 downto 0) <= DAT_I;
                        else
                            dat_o_sig <= pri_pulse_width_reg(15 downto 0);
                        end if;
                    when 6 =>
                        if WE_I = '1' THEN
                            pri_pulse_width_reg(31 downto 16) <= DAT_I;
                        else
                            dat_o_sig <= pri_pulse_width_reg(31 downto 16);
                        end if;
                    -- ------------------------------------------------------------------------------------------------
                    -- REGISTER: pulse_params    SIZE: 320 bytes    PERMISSIONS: read and write
                    -- ------------------------------------------------------------------------------------------------
                          -- 7 - 166
                    when REGISTER_PULSE_PARAMS_BASE to REGISTER_PULSE_PARAMS_END =>
                        if WE_I = '1' then
                            pulse_params_reg(address_int - REGISTER_PULSE_PARAMS_BASE) <= DAT_I;
                        else
                            dat_o_sig <= pulse_params_reg(address_int - REGISTER_PULSE_PARAMS_BASE);
                        end if;
                    -- ------------------------------------------------------------------------------------------------
                    -- REGISTER: status    SIZE: 2 bytes    PERMISSIONS: read only
                    -- ------------------------------------------------------------------------------------------------
                    when 167 =>
                        if WE_I = '1' THEN
                            null;
                        else
                            dat_o_sig <= status_reg(15 downto 0);
                        end if;
                    -- ------------------------------------------------------------------------------------------------
                    -- REGISTER: instruction    SIZE: 2 bytes    PERMISSIONS: read and write
                    -- ------------------------------------------------------------------------------------------------
                    when 168 =>
                        if WE_I = '1' THEN
                            instruction_reg(15 downto 0) <= DAT_I;
                        else
                            dat_o_sig <= instruction_reg(15 downto 0);
                        end if;
                    -- ------------------------------------------------------------------------------------------------
                    -- REGISTER: pre_pulse    SIZE: 2 bytes    PERMISSIONS: read and write
                    -- ------------------------------------------------------------------------------------------------
                    when 169 =>
                        if WE_I = '1' THEN
                            pre_pulse_reg(15 downto 0) <= DAT_I;
                        else
                            dat_o_sig <= pre_pulse_reg(15 downto 0);
                        end if;
                    -- ------------------------------------------------------------------------------------------------
                    -- REGISTER: pre_pulse    SIZE: 2 bytes    PERMISSIONS: read and write
                    -- ------------------------------------------------------------------------------------------------
                    when 170 =>
                        if WE_I = '1' THEN
                            rex_delay_reg(15 downto 0) <= DAT_I;
                        else
                            dat_o_sig <= rex_delay_reg(15 downto 0);
                        end if;
                    when others =>
                        null;
                end case;
            else
                num_pulses_reg      <= num_pulses_reg;
                num_repeats_reg     <= num_repeats_reg;
                x_amp_delay_reg     <= x_amp_delay_reg;
                l_amp_delay_reg     <= l_amp_delay_reg;
                pri_pulse_width_reg <= pri_pulse_width_reg;
                pre_pulse_reg       <= pre_pulse_reg;
					 rex_delay_reg			<= rex_delay_reg;
                -- pulse_params_reg <= pulse_params_reg;
            end if;
        END IF;
    end process;

    DAT_O <= dat_o_sig when STB_I = '1' else (others => 'Z');
    ACK_O <= '1' when STB_I = '1' else 'Z';

    ---------------------------------------------------------------------------------------
    -- IP CORE SPECIFIC LOGIC
    ---------------------------------------------------------------------------------------

    process(clk_IN)
    begin
        if rising_edge(clk_IN) then
            status_reg          <= status_IN;
            pulse_params_OUT    <= pulse_params_reg((5 * pulse_index) + 4) & -- frequency      [79 - 64]
                                   pulse_params_reg((5 * pulse_index) + 3) & -- mode           [63 - 48]
                                   pulse_params_reg((5 * pulse_index) + 2) & -- pri_upper      [47 - 32]
                                   pulse_params_reg((5 * pulse_index) + 1) & -- pri_lower      [31 - 16]
                                   pulse_params_reg((5 * pulse_index) + 0) ; -- rf_pulse_width [15 - 0]
        end if;
    end process;

        pulse_index         <= to_integer(unsigned(pulse_index_IN)); -- input port
        status_OUT          <=  status_reg; -- output port
        instruction_OUT     <= instruction_reg; -- output port
        num_pulses_OUT      <= num_pulses_reg; -- output port
        num_repeats_OUT     <= num_repeats_reg(31 downto 16) & num_repeats_reg(15 downto 0); -- output port
        x_amp_delay_OUT     <= x_amp_delay_reg; -- output port
        l_amp_delay_OUT     <= l_amp_delay_reg; -- output port
        rex_delay_OUT     	 <= rex_delay_reg; -- output port
        pre_pulse_OUT       <= pre_pulse_reg; -- output port
        pri_pulse_width_OUT <= pri_pulse_width_reg(31 downto 16) & pri_pulse_width_reg(15 downto 0); -- output port

END behavioral;
