# without this file Quartus does no timing analysis at all, so a design can
# compile clean and still fail on hardware

# 66MHz board oscillator. almost nothing actually runs at this rate, only
# the divider counter
create_clock -name {clk} -period 15.152 [get_ports {clk}]

# the ~1MHz divided clock everything else runs on. declaring it here is what
# makes the analyzer check against ~970ns instead of 15ns
create_generated_clock -name {slow_clk} -source [get_ports {clk}] -divide_by 64 [get_registers {slow_clk}]

# T_CLK and SCK are tied straight to slow_clk, so they're generated clocks
# going off-chip, not independent ones
create_generated_clock -name {T_CLK_out} -source [get_registers {slow_clk}] [get_ports {T_CLK}]
create_generated_clock -name {SCK_out}   -source [get_registers {slow_clk}] [get_ports {SCK}]

derive_clock_uncertainty

# loose placeholder numbers, not from the XPT2046/ILI9341 datasheets. both
# peripherals are slow enough that it doesn't matter yet. tighten if I ever
# run the SPI near its real limits
set_input_delay  -clock {slow_clk} -max 5.0 [get_ports {T_DO T_IRQ}]
set_input_delay  -clock {slow_clk} -min 1.0 [get_ports {T_DO T_IRQ}]

set_output_delay -clock {slow_clk} -max 5.0 [get_ports {T_CS T_DIN CS RESET DC SDI LED}]
set_output_delay -clock {slow_clk} -min 1.0 [get_ports {T_CS T_DIN CS RESET DC SDI LED}]

# rst_n is an async pushbutton, timing it against clk is meaningless.
# TODO: should really go through a 2-flop synchronizer, this just hides it
set_false_path -from [get_ports {rst_n}]
