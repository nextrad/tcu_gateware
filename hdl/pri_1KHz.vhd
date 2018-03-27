-- pri_1KHz.vhd
-- synthesizing a pri signal toggling at 1000.0Hz
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity pri_1KHz is
    port (
        clk_IN  : in  std_logic;
        pri_OUT : out std_logic
    );
end entity;

architecture rtl of pri_1KHz is

signal clk_sig      : std_logic := '0';
signal pri_sig      : std_logic := '0';
signal counter      : unsigned(15 downto 0) := (others => '0');

-- constant PRESCALER  : unsigned(15 downto 0) := 50000; -- 100MHz
constant PRESCALER  : unsigned(15 downto 0) := 5000; -- 10MHz

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
            if counter = PRESCALER then
                pri_sig <= not pri_sig;
                counter <= (others => '0');
            end if;
            counter <= counter + 1;
        end if;
    end process;

    pri_OUT <= pri_sig;

end architecture;
