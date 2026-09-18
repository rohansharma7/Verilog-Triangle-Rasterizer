Triangle rasterizer on an Altera Cyclone IV FPGA.
The FPGA is connected to a touchscreen.
Touch the screen three times, and it fills in the triangle those points make on the screen.

Flow is: touchscreen -> touchscreen_interface -> touch_commands -> rasterizer -> screen_mem -> display_interface -> screen.

rtl files

- screen_mem.sv - 320x240 framebuffer, 1 bit per pixel. I split it into 8
  banks so the rasterizer can write 8 pixels in one clock. The display still
  reads one pixel at a time.

- rasterizer.sv - Takes 3 points, finds the bounding box, then checks 8 pixels
  at a time. It has a 2 stage pipeline so it can work on the next group while
  the last group is being checked and written.

- touch_commands.sv - Collects three touches into a triangle and pulses start.
  Also scales the raw 12-bit ADC values down to screen coordinates.

- touchscreen_interface.sv - SPI master for the XPT2046 touch controller.
  Waits for the interrupt from the touchscreen being touched, then reads X and Y.

- display_interface.sv - SPI master for the ILI9341. runs the power-on init
  sequence, sets the address window, then loops forever streaming the
  framebuffer out.

- raster_top.sv - Wires everything together and has the clock divider (66MHz
  down to ~1MHz, needed because the XPT2046 tops out around 2MHz).

testbenches

All five are self-checking. They print ALL TESTS PASSED or a count of
failures, so they can be run without eyeballing waveforms.

- tb_screen_mem.sv - Writes single pixels through the bank mask at a few
  addresses, then reads them back. Writes a 0 as well as 1s so a pass can't
  come from uninitialized X. Also reads an address that was never written and
  fails if it comes back set, which catches address decode aliasing onto a
  written location.

- tb_rasterizer.sv - Instantiates the rasterizer against a real screen_mem.
  Starts with one directed triangle, (0,0) (6,0) (6,6), whose ten filled
  pixels were worked out by hand rather than taken from the RTL. Then runs 20
  constrained-random triangles in a 64x64 window. Each
  random triangle is scored against an edge-function model computed in the
  testbench, and the whole 64x64 area is checked every pass, so leftover
  pixels from an earlier triangle count as failures.

- tb_touch_commands.sv - Feeds three touches and checks the FSM pulses start
  for exactly one cycle, and that the scaled coordinates match the default
  calibration. Then feeds the ADC extremes, 0 and 4095, and checks they clamp
  to (0,0) and (319,239). That clamp is what keeps the write address inside
  the framebuffer.

- tb_top.sv - Has a fake XPT2046 in it that answers the D0
  and D1 conversion commands with canned X and Y, so three touches drive the
  whole chain from pen interrupt to framebuffer. Checks one pixel that should
  be inside the resulting triangle and two that should not, reading the memory
  banks directly.

golden_model.java is a separate reference implementation of the fill
algorithm for checking the RTL.

quartus/

raster_top.qsf has the pin assignments, raster_top.sdc has timing
constraints.