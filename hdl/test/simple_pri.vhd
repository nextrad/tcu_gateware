-- simple_pri.vhd
-- synthesizing a simple pri signal toggling at 1525.9Hz
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity simple_pri is
    port (
--        clk_IN  : in  std_logic;
        clk_P_IN  : in  std_logic;
        clk_N_IN  : in  std_logic;
        pri_OUT : out std_logic;
		  logic_high : out std_logic  -- supply power to J1 P40 to feed ext clock converter
    );
end entity;

architecture rtl of simple_pri is

signal clk_sig : std_logic := '0';
signal counter : unsigned(31 downto 0) := (others => '0');

begin
	logic_high <= '1'; -- supply power to J1 P40 to feed ext clock converter
--    IBUFG_inst : IBUFG
--    generic map (
--        IBUF_LOW_PWR => FALSE,
--        IOSTANDARD => "DEFAULT"
--    )
--    port map (
--        O => clk_sig,
--        I => clk_IN
--    );

	 IBUFGDS_sys_clk: IBUFGDS
	generic map
	(
		IOSTANDARD => "LVDS_25",
		DIFF_TERM => TRUE,
		IBUF_LOW_PWR => FALSE
	)
	port map
	(
		I => clk_P_IN,
		IB => clk_N_IN,
		O => clk_sig
	);

    process(clk_sig)
    begin
        if rising_edge(clk_sig) then
            counter <= counter + 1;
        end if;
    end process;

	 pri_OUT <= counter(15); -- 1525.9Hz (100MHz clk)
    --pri_OUT <= counter(12); -- 1220.7Hz (10MHz clk)

end architecture;
