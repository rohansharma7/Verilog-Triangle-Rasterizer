# =====================================================================
# Timing constraints for raster_top on the DueProLogic Cyclone IV board.
#
# Without this file Quartus runs no timing analysis at all (it emits
# "Critical Warning (332012): Synopsys Design Constraints File not
# found" and then "Timing requirements not specified"), which means a
# design can compile cleanly and still fail on real hardware because
# some combinational path doesn't close.
# =====================================================================

# ---------------------------------------------------------------------
# Base clock: 66MHz onboard oscillator on PIN_23 -> 15.152 ns period.
#
# Note that almost nothing runs at this rate: raster_top immediately
# divides it by 64 down to ~1.03MHz, and every submodule runs on that
# divided clock. Only the divider's own counter is clocked at 66MHz.
# ---------------------------------------------------------------------
create_clock -name {clk} -period 15.152 [get_ports {clk}]

# ---------------------------------------------------------------------
# The ~1.03MHz divided clock that actually drives the design (~970ns
# period). Declaring it as a generated clock is what makes the timing
# analyzer check the real logic against the slow rate rather than
# against the 66MHz source -- which is the whole point of dividing:
# at ~970ns, every combinational path in this design (including the
# rasterizer's multiplier chain) has enormous slack.
# ---------------------------------------------------------------------
create_generated_clock -name {slow_clk} -source [get_ports {clk}] -divide_by 64 [get_registers {slow_clk}]

# ---------------------------------------------------------------------
# T_CLK and SCK are tied combinationally straight to the divided clock
# inside touchscreen_interface / display_driver, so they're generated
# clocks leaving the chip, not independent clocks. At ~1.03MHz both sit
# comfortably under their peripherals' limits (XPT2046 DCLK max ~2MHz,
# ILI9341 well above that) -- which is the correctness reason for the
# divider, independent of timing closure.
# ---------------------------------------------------------------------
create_generated_clock -name {T_CLK_out} -source [get_registers {slow_clk}] [get_ports {T_CLK}]
create_generated_clock -name {SCK_out}   -source [get_registers {slow_clk}] [get_ports {SCK}]

derive_clock_uncertainty

# ---------------------------------------------------------------------
# I/O constraints.
#
# Both SPI peripherals here are slow relative to the FPGA (the XPT2046
# tops out in the low MHz, the ILI9341 well under the 66MHz core clock),
# and neither has tight source-synchronous requirements at these rates.
# These are deliberately loose placeholder values rather than values
# derived from the peripherals' datasheet setup/hold specs -- they exist
# so the paths are constrained rather than ignored. If you later run the
# SPI links near their real speed limits, tighten these using the actual
# XPT2046 / ILI9341 timing numbers.
# ---------------------------------------------------------------------
set_input_delay  -clock {slow_clk} -max 5.0 [get_ports {T_DO T_IRQ}]
set_input_delay  -clock {slow_clk} -min 1.0 [get_ports {T_DO T_IRQ}]

set_output_delay -clock {slow_clk} -max 5.0 [get_ports {T_CS T_DIN CS RESET DC SDI LED}]
set_output_delay -clock {slow_clk} -min 1.0 [get_ports {T_CS T_DIN CS RESET DC SDI LED}]

# ---------------------------------------------------------------------
# rst_n is an asynchronous pushbutton input (SW1). It is not
# synchronous to clk, so timing it against clk is meaningless.
#
# NOTE: this design uses rst_n directly rather than passing it through
# a two-flop synchronizer, which is what you'd normally do for an
# asynchronous, mechanically-bouncy input. Cutting the timing path here
# silences the analyzer but does not remove the underlying metastability
# risk -- adding a proper reset synchronizer is the real fix, and is
# worth doing before relying on this in anything but a demo.
# ---------------------------------------------------------------------
set_false_path -from [get_ports {rst_n}]
