module raster_top (
    input logic clk,
    input logic rst_n,

    // touch controller (XPT2046) SPI pins
    input logic  T_DO,
    input logic  T_IRQ,
    output logic T_CS,
    output logic T_DIN,
    output logic T_CLK,

    // display controller (ILI9341) SPI pins
    output logic CS,
    output logic RESET,
    output logic DC,
    output logic SDI,
    output logic SCK,
    output logic LED
);

    // ---------------- touchscreen_interface <-> cmd_processor ----------------
    logic [11:0] x_value, y_value;
    logic        touch_ready;

    // ---------------- cmd_processor <-> rasterizer ----------------
    logic [8:0]  x1_in, y1_in, x2_in, y2_in, x3_in, y3_in;
    logic        start;
    logic        raster_done;

    // fixed fill color for now (no color input path from the touchscreen)
    localparam logic [15:0] FILL_COLOR = 16'hFFFF; // white

    // ---------------- rasterizer <-> screen_mem ----------------
    logic        raster_wr_en;
    logic [16:0] raster_addr;
    logic [15:0] raster_data;

    // ---------------- screen_mem <-> display_driver ----------------
    logic [16:0] disp_rd_addr;
    logic [15:0] disp_rd_data;

    touchscreen_interface u_touchscreen_interface (
        .clk      (clk),
        .rst_n    (rst_n),
        .T_DO     (T_DO),
        .T_IRQ    (T_IRQ),
        .T_CS     (T_CS),
        .T_DIN    (T_DIN),
        .T_CLK    (T_CLK),
        .x_value  (x_value),
        .y_value  (y_value),
        .ready    (touch_ready)
    );

    cmd_processor u_cmd_processor (
        .clk     (clk),
        .rst_n   (rst_n),
        .ready   (touch_ready),
        .x_value (x_value),
        .y_value (y_value),
        .x1_in   (x1_in),
        .y1_in   (y1_in),
        .x2_in   (x2_in),
        .y2_in   (y2_in),
        .x3_in   (x3_in),
        .y3_in   (y3_in),
        .start   (start)
    );

    rasterizer u_rasterizer (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (start),
        .x1_in    (x1_in),
        .y1_in    (y1_in),
        .x2_in    (x2_in),
        .y2_in    (y2_in),
        .x3_in    (x3_in),
        .y3_in    (y3_in),
        .color_in (FILL_COLOR),
        .done     (raster_done),
        .wr_en    (raster_wr_en),
        .addr     (raster_addr),
        .data     (raster_data)
    );

    screen_mem u_screen_mem (
        .clk     (clk),
        .wr_en   (raster_wr_en),
        .wr_addr (raster_addr),
        .wr_data (raster_data),
        .rd_addr (disp_rd_addr),
        .rd_data (disp_rd_data)
    );

    display_driver u_display_driver (
        .clk     (clk),
        .rst_n   (rst_n),
        .rd_data (disp_rd_data),
        .rd_addr (disp_rd_addr),
        .CS      (CS),
        .RESET   (RESET),
        .DC      (DC),
        .SDI     (SDI),
        .SCK     (SCK),
        .LED     (LED)
    );

endmodule

/*
    raster_top wires the whole pipeline together:

    touchscreen (SPI) -> touchscreen_interface -> cmd_processor
        -> rasterizer -> screen_mem -> display_driver -> display (SPI)

    Notes / simplifications:
    - Fill color is hardcoded (FILL_COLOR) since there's no color input
      path from the touchscreen; every triangle is drawn white.
    - screen_mem is shared: rasterizer writes to it, display_driver reads
      from it. Since rasterizer only writes occasionally (after a 3-touch
      sequence completes) and display_driver continuously reads/redraws,
      there's no arbitration here -- a write and a read to different
      addresses in the same cycle is fine since screen_mem's write and
      read ports are independent, but a write to the exact address
      display_driver is about to read in the same cycle will show the
      new pixel one frame-scan later than expected. Not a functional bug,
      just a timing/visual nuance worth knowing about.
    - RESET (display hardware reset pin) is driven inside display_driver
      itself: low during RESET_PULSE, high otherwise.
*/
