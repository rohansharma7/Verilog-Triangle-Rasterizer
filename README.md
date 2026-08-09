screen_mem.sv — The framebuffer memory: one write port for the rasterizer to draw pixels into, and one registered read port for reading the picture back out. Holds one 8-bit color value per pixel across the full 64x64 canvas.

cmd_processor.sv — Receives the incoming stream of drawing commands and assembles each multi-beat "draw triangle" command into a single complete triangle descriptor. Hands off each finished triangle to the rasterizer via a valid/ready handshake.

rasterizer.sv — Takes one triangle at a time and determines which pixels fall inside it using the bounding-box + edge-function (cross-product) method. Writes the triangle's color into the framebuffer for every pixel that passes the inside test.

raster_top.sv — Wires cmd_processor, rasterizer, and screen_mem together into the complete system. Exposes the external command stream interface and a framebuffer readback port for testing.

golden_model.java — An independent reference implementation of the triangle-fill algorithm, used to check the RTL's output for correctness. Not part of the hardware design itself — purely a verification tool.





rasterizer
- takes three coordinates and then iterates through all pixels and draws them in

screen mem
- register that holds pixel values

spi_interface
- gets x and y coordinates from touchscreen then 




