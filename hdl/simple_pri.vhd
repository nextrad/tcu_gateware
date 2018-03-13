-- simple_pri.vhd
-- synthesizing a simple pri signal toggling at 1525.9Hz
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity simple_pri is
    port (
        clk_IN  : in  std_logic;
        pri_OUT : out std_logic
    );
end entity;

architecture rtl of simple_pri is

signal clk_sig : std_logic := '0';
signal counter : unsigned(31 downto 0) := (others => '0');

begin

    IBUFG_inst : IBUFG
    generic map (
        IBUF_LOW_PWR => FALSE,
        IOSTANDARD => "DEFAULT"
    )
    port map (
        O => clk_sig,
        I => clk_IN
    );

    process(clk_sig)
    begin
        if rising_edge(clk_sig) then
            counter <= counter + 1;
        end if;
    end process;

    pri_OUT <= counter(15);

end architecture;
