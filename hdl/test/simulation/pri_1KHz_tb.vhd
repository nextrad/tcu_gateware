--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   12:37:52 05/11/2018
-- Design Name:   
-- Module Name:   /home/brad/nextrad/tcu_gateware/hdl/simulation/pri_1KHz_tb.vhd
-- Project Name:  pri_1KHz_RHINO
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: pri_1KHz
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY pri_1KHz_tb IS
END pri_1KHz_tb;
 
ARCHITECTURE behavior OF pri_1KHz_tb IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT pri_1KHz
    PORT(
         clk_P_IN : IN  std_logic;
         clk_N_IN : IN  std_logic;
         pri_OUT : OUT  std_logic;
         logic_high : OUT  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal clk_P_IN : std_logic := '0';
   signal clk_N_IN : std_logic := '0';

 	--Outputs
   signal pri_OUT : std_logic;
   signal logic_high : std_logic;

   -- Clock period definitions
   constant clk_P_IN_period : time := 10 ns;
   constant clk_N_IN_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: pri_1KHz PORT MAP (
          clk_P_IN => clk_P_IN,
          clk_N_IN => clk_N_IN,
          pri_OUT => pri_OUT,
          logic_high => logic_high
        );

   -- Clock process definitions
   clk_P_IN_process :process
   begin
		clk_P_IN <= '0';
		clk_N_IN <= '1';
		wait for clk_P_IN_period/2;
		clk_P_IN <= '1';
		clk_N_IN <= '0';
		wait for clk_P_IN_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
      wait for 100 ns;	

      wait for clk_P_IN_period*10;

      -- insert stimulus here 

      wait;
   end process;

END;
