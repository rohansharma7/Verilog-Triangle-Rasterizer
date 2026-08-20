Triangle rasterizer on an Altera Cyclone IV (DueProLogic board). Touch the
screen three times, it fills in the triangle those points make.

Flow is: touchscreen -> touchscreen_interface -> cmd_processor -> rasterizer
-> screen_mem -> display_driver -> screen.

rtl files

- screen_mem.sv - the framebuffer. 320x240, 1 bit per pixel. one write port
  for the rasterizer, one registered read port for the display driver. it's
  1bpp because RGB565 would need 1.2Mbit and the EP4CE6 only has ~276kbit.

- rasterizer.sv - takes 3 vertices, works out the bounding box, then walks it
  testing each pixel with the edge function (cross product) and writing the
  ones inside.

- cmd_processor.sv - collects three touches into a triangle and pulses start.
  also scales the raw 12-bit ADC values down to screen coordinates.

- touchscreen_interface.sv - SPI master for the XPT2046 touch controller.
  waits for the pen interrupt, then reads X and Y.

- display_driver.sv - SPI master for the ILI9341. runs the power-on init
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

- calibrate the touch panel. the scaling parameters in cmd_processor assume
  the full 0-4095 ADC range, which isn't what a real panel gives. need to
  measure the actual min/max and plug them in.
- rst_n should go through a 2-flop synchronizer.
- full frame redraw takes ~1.4s. would need a faster clock for the display
  half, or fewer cycles per pixel.
