Triangle rasterizer on an Altera Cyclone IV FPGA.
The FPGA is connected to a touchscreen.
Touch the screen three times, and it fills in the triangle those points make on the screen.

Flow is: touchscreen -> touchscreen_interface -> touch_commands -> rasterizer -> screen_mem -> display_interface -> screen.

I pipelined the rasterizer and added 8-pixel parallel processing, but it cannot reach the benchmark speed on the actual hardware because all modules share the slower clock needed by the touchscreen interface.

I got it to work on an actual FPGA with the original version a couple times until the port on the FPGA stopped working and I couldn't flash it anymore and had to return it :(

rtl files

- screen_mem.sv - 320x240 framebuffer, 1 bit per pixel. I split it into 8
  banks so the rasterizer can write 8 pixels in one clock. The display still
  reads one pixel at a time.

- rasterizer.sv - Takes 3 points, finds the bounding box, then checks 8 pixels
  at a time. It has a 2 stage pipeline so it can work on the next group while
  the last group is being checked and written.

- touch_commands.sv - Collects three touches into a triangle and pulses start.
  Scales raw values from 0-4095 using x * 320 / 4096 and y * 240 / 4096,
  rounded down. This gives x coordinates from 0-319 and y from 0-239.

- touchscreen_interface.sv - SPI master for the XPT2046 touch controller.
  Waits for the interrupt from the touchscreen being touched, then reads X and Y.
  Sends 0xD0 for X and 0x90 for Y.

- display_interface.sv - SPI master for the ILI9341. runs the power-on init
  sequence, sets the address window, then loops forever streaming the
  framebuffer out.

- raster_top.sv - Wires everything together and has the clock divider (66MHz
  down to ~1MHz, needed because the XPT2046 tops out around 2MHz).

testbenches

- tb_rasterizer.sv - Main testbench. Instantiates the rasterizer against a real screen_mem.
  Starts with one directed triangle, (0,0) (6,0) (6,6), whose ten filled
  pixels were worked out by hand rather than taken from the RTL. Then runs 20
  constrained-random triangles in a 64x64 window. Each
  random triangle is scored against an edge-function model computed in the
  testbench, and the whole 64x64 area is checked every pass. The expected
  framebuffer keeps pixels from earlier triangles too, since drawing a new
  triangle does not clear the old ones.

- tb_screen_mem.sv - Writes single pixels through the bank mask at a few
  addresses, then reads them back. Writes a 0 as well as 1s so a pass can't
  come from uninitialized X. Also reads an address that was never written and
  fails if it comes back set, which catches address decode aliasing onto a
  written location.

- tb_touch_commands.sv - Feeds three touches and checks the FSM pulses start
  for exactly one cycle and that the scaled coordinates are correct. Then
  feeds the ADC extremes, 0 and 4095, and checks they map to (0,0) and
  (319,239). The scaling already stays in range, so no clamp is needed.

- tb_display_interface.sv - Captures the SPI bytes and command/data bit.
  Checks the 18 startup bytes, including the address window, and the first
  two pixels. Uses a fake framebuffer with a registered read to check that
  black becomes 0x0000 and white becomes 0xFFFF.

- tb_top.sv - Has a fake XPT2046 that returns canned X for 0xD0 and
  canned Y for the other command. Three touches drive the
  whole chain from pen interrupt to framebuffer. Checks one pixel that should
  be inside the resulting triangle and two that should not, reading the memory
  banks directly.

golden_model.java is a separate reference implementation of the fill
algorithm for checking the RTL.

quartus/

raster_top.qsf has the pin assignments, raster_top.sdc has timing
constraints.