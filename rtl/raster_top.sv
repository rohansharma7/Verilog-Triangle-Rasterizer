module raster_top #(
    // slow_clk toggles every CLK_DIV_HALF fast clocks, so divide by 2x this
    parameter int CLK_DIV_HALF = 32,

    // testbenches override these, real values take 130k cycles to sim
    parameter logic [19:0] DISPLAY_RESET_HOLD_CYCLES  = 20'd100,
    parameter logic [19:0] DISPLAY_SETTLE_HOLD_CYCLES = 20'd130_000
) (
    input logic clk,
    input logic rst_n,

    input logic  T_DO,
    input logic  T_IRQ,
    output logic T_CS,
    output logic T_DIN,
    output logic T_CLK,

    output logic CS,
    output logic RESET,
    output logic DC,
    output logic SDI,
    output logic SCK,
    output logic LED
);

    // 66MHz -> ~1MHz. needed because T_CLK is tied to this clock and the
    // XPT2046 maxes out around 2MHz. also makes timing closure a non-issue.
    // downside: ~1.4s to redraw a full frame.
    //
    // not reset by rst_n on purpose. submodules use sync reset, so if this
    // stopped during reset they'd never actually reset.
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

    logic [11:0] x_value, y_value;
    logic        touch_ready;

    logic [8:0]  x1_in, y1_in, x2_in, y2_in, x3_in, y3_in;
    logic        start;
    logic        raster_done;

    // 1bpp, so this is just set/clear. actual color lives in display_driver
    localparam logic FILL_COLOR = 1'b1;

    logic        raster_wr_en;
    logic [16:0] raster_addr;
    logic        raster_data;

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
    touchscreen -> touchscreen_interface -> cmd_processor -> rasterizer
    -> screen_mem -> display_driver -> display

    framebuffer is 1bpp because RGB565 at 320x240 needs 1.2Mbit and the
    EP4CE6 only has ~276kbit. display_driver expands each bit back to
    RGB565 on the way out, so the panel still runs 16bpp.

    no arbitration on screen_mem. rasterizer only writes after 3 touches,
    display_driver reads constantly. a write to the address being read that
    same cycle just shows up one frame later.
*/
