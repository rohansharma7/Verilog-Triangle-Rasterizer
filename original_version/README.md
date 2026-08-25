# original version

this is the old version from before i added the 8 pixel parallel stuff and
pipelining. it checks one pixel each clock. i kept it here so i could compare
the timing and resource usage against the new version.

Triangle rasterizer on an Altera Cyclone IV (DueProLogic board). Touch the
screen three times, it fills in the triangle those points make.

Flow is: touchscreen -> touchscreen_interface -> touch_commands -> rasterizer
-> screen_mem -> display_interface -> screen.

rtl files

- screen_mem.sv - the framebuffer. 320x240, 1 bit per pixel. one write port
  for the rasterizer and one registered read port for the display. it's
  1bpp because RGB565 would need 1.2Mbit and the EP4CE6 only has ~276kbit.

- rasterizer.sv - takes 3 vertices, works out the bounding box, then walks it
  one pixel at a time, testing each point with three edge functions and
  writing the pixels inside the triangle.

- touch_commands.sv - collects three touches into a triangle and pulses start.
  also scales the raw 12-bit ADC values down to screen coordinates.

- touchscreen_interface.sv - SPI master for the XPT2046 touch controller.
  waits for the pen interrupt, then reads X and Y.

- display_interface.sv - SPI master for the ILI9341. runs the power-on init
  sequence, sets the address window, then loops forever streaming the
  framebuffer out. expands each 1bpp pixel back to RGB565.

- raster_top.sv - wires it all together, plus the clock divider (66MHz down
  to ~1MHz, needed because the XPT2046 tops out around 2MHz).

testbenches

all five are self-checking, they print ALL TESTS PASSED or a count of
failures. tb_top is the integration one and has a fake XPT2046 in it.

golden_model.java is a separate reference implementation of the fill
algorithm, just for checking the RTL. not part of the hardware.

quartus/

raster_top.qsf has the pin assignments, raster_top.sdc has timing
constraints.

still todo

- calibrate the touch panel. the scaling logic in touch_commands assumes
  the full 0-4095 ADC range, which isn't what a real panel gives. need to
  measure the actual min/max and plug them in.
- rst_n should go through a 2-flop synchronizer.
- full frame redraw takes ~1.4s. would need a faster clock for the display
  half, or fewer cycles per pixel.
