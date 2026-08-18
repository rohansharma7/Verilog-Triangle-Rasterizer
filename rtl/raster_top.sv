module raster_top #(
    // Clock divider: slow_clk toggles every CLK_DIV_HALF fast clocks,
    // so the division ratio is 2*CLK_DIV_HALF. Default 32 -> divide by
    // 64 -> 66MHz becomes ~1.03MHz (see the divider block below).
    parameter int CLK_DIV_HALF = 32,

    // ILI9341 power-on timing, in slow_clk cycles. Defaults match the
    // datasheet at ~1.03MHz. Testbenches override these with tiny values
    // -- at the real setting the settle wait alone is 130,000 slow clocks
    // (~8.3 million fast clocks), which makes simulation impractically slow.
    parameter logic [19:0] DISPLAY_RESET_HOLD_CYCLES  = 20'd100,
    parameter logic [19:0] DISPLAY_SETTLE_HOLD_CYCLES = 20'd130_000
) (
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

    // ---------------------------------------------------------------------
    // Clock divider: 66MHz -> ~1.03MHz (divide by 64).
    //
    // This is not just a timing-closure convenience -- it's required for
    // correctness. T_CLK and SCK are tied directly to the system clock
    // inside touchscreen_interface / display_driver, and the XPT2046's
    // max DCLK is around 2MHz. Running the whole design at 66MHz would
    // drive the touch controller ~30x past its rated clock speed.
    //
    // The ~1us period also means every combinational path in the design
    // has enormous slack, so timing closure stops being a concern.
    //
    // TRADEOFF: display_driver takes 19 clocks per pixel (FETCH,
    // FETCH_WAIT, PIXEL_LOAD, + 16 shift cycles), so a full 76,800-pixel
    // frame is ~1.46M clocks = ~1.4 seconds at this rate. The image is
    // static between touches, so this shows up as the screen visibly
    // painting in rather than flickering -- fine for a demo, but it's
    // the main thing to speed up later (either a faster clock for the
    // display half only, or fewer overhead cycles per pixel).
    //
    // NOTE ON STYLE: deriving a clock in logic like this and feeding it
    // to submodules is convenient but not best practice -- the textbook
    // approach is to keep one clock and use clock-enable signals, or to
    // use a PLL. Quartus will generally still route this onto a global
    // clock network at these speeds, but it's worth knowing this is the
    // pragmatic choice rather than the rigorous one.
    // ---------------------------------------------------------------------
    // Deliberately NOT reset by rst_n. The submodules all use synchronous
    // reset, which requires a clock edge to take effect -- so if slow_clk
    // stopped while rst_n was low, their resets would never be applied and
    // their state registers would stay uninitialized. A clock that halts
    // during reset is a bug regardless; clock generation should free-run.
    //
    // The `= 0` initializers set the power-up value (Cyclone IV registers
    // come up at 0), which is what gets these started deterministically
    // without needing a reset.
    logic [15:0] clk_div_count = 0;
    logic        slow_clk      = 0;

    always_ff @(posedge clk) begin
        if (clk_div_count >= CLK_DIV_HALF - 1) begin
            clk_div_count <= 0;
            slow_clk      <= ~slow_clk;
        end else begin
            clk_div_count <= clk_div_count + 1;
        end
    end

    // ---------------- touchscreen_interface <-> cmd_processor ----------------
    logic [11:0] x_value, y_value;
    logic        touch_ready;

    // ---------------- cmd_processor <-> rasterizer ----------------
    logic [8:0]  x1_in, y1_in, x2_in, y2_in, x3_in, y3_in;
    logic        start;
    logic        raster_done;

    // 1bpp framebuffer: rasterizer writes a 1 for filled pixels.
    // The actual on-screen color is chosen in display_driver
    // (PIXEL_COLOR_ON / PIXEL_COLOR_OFF), not here.
    localparam logic FILL_COLOR = 1'b1;

    // ---------------- rasterizer <-> screen_mem ----------------
    logic        raster_wr_en;
    logic [16:0] raster_addr;
    logic        raster_data;

    // ---------------- screen_mem <-> display_driver ----------------
    logic [16:0] disp_rd_addr;
    logic        disp_rd_data;

    touchscreen_interface u_touchscreen_interface (
        .clk      (slow_clk),
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
        .clk     (slow_clk),
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
        .clk      (slow_clk),
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
        .clk     (slow_clk),
        .wr_en   (raster_wr_en),
        .wr_addr (raster_addr),
        .wr_data (raster_data),
        .rd_addr (disp_rd_addr),
        .rd_data (disp_rd_data)
    );

    display_driver #(
        .RESET_HOLD_CYCLES  (DISPLAY_RESET_HOLD_CYCLES),
        .SETTLE_HOLD_CYCLES (DISPLAY_SETTLE_HOLD_CYCLES)
    ) u_display_driver (
        .clk     (slow_clk),
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
    - The framebuffer is 1 bit per pixel, not RGB565. This is a hard
      constraint of the EP4CE6: it has 30 M9K blocks (~276,480 bits),
      while a 320x240 RGB565 framebuffer would need 1,228,800 bits
      (~4.5x more than the chip has). At 1bpp it's 76,800 bits (~10
      blocks). display_driver expands each bit to a full RGB565 pixel
      on output, so the panel still runs in its native 16bpp mode.
    - Fill color is therefore chosen in display_driver
      (PIXEL_COLOR_ON/OFF), not per-pixel in the framebuffer; every
      triangle is drawn in the same color.
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
