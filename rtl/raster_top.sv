module raster_top (
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


    logic [15:0] clk_div_count = 0;
    logic        slow_clk      = 0;

    always_ff @(posedge clk) begin
        if (clk_div_count >= 31) begin
            clk_div_count <= 0;
            slow_clk      <= ~slow_clk;
        end else begin
            clk_div_count <= clk_div_count + 1;
        end
    end


    logic rst_n_meta, rst_n_sync;

    always_ff @(posedge slow_clk or negedge rst_n) begin
        if (!rst_n) begin
            rst_n_meta <= 1'b0;
            rst_n_sync <= 1'b0;
        end else begin
            rst_n_meta <= 1'b1;
            rst_n_sync <= rst_n_meta;
        end
    end

    logic [11:0] x_value, y_value;
    logic        touch_ready;

    logic [8:0]  x1_in, y1_in, x2_in, y2_in, x3_in, y3_in;
    logic        start;
    logic        raster_done;

    // 1bpp, so this is just set/clear. actual color lives in display_interface
    logic        raster_wr_en;
    logic [7:0]  raster_wr_mask;
    logic [13:0] raster_addr;
    logic        raster_data;

    logic [16:0] disp_rd_addr;
    logic        disp_rd_data;

    touchscreen_interface u_touchscreen_interface (
        .clk      (slow_clk),
        .rst_n    (rst_n_sync),
        .T_DO     (T_DO),
        .T_IRQ    (T_IRQ),
        .T_CS     (T_CS),
        .T_DIN    (T_DIN),
        .T_CLK    (T_CLK),
        .x_value  (x_value),
        .y_value  (y_value),
        .ready    (touch_ready)
    );

    touch_commands u_touch_commands (
        .clk     (slow_clk),
        .rst_n   (rst_n_sync),
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
        .rst_n    (rst_n_sync),
        .start    (start),
        .x1_in    (x1_in),
        .y1_in    (y1_in),
        .x2_in    (x2_in),
        .y2_in    (y2_in),
        .x3_in    (x3_in),
        .y3_in    (y3_in),
        .color_in (1'b1),
        .done     (raster_done),
        .wr_en    (raster_wr_en),
        .wr_mask  (raster_wr_mask),
        .addr     (raster_addr),
        .data     (raster_data)
    );

    screen_mem u_screen_mem (
        .clk     (slow_clk),
        .wr_en   (raster_wr_en),
        .wr_mask (raster_wr_mask),
        .wr_addr (raster_addr),
        .wr_data (raster_data),
        .rd_addr (disp_rd_addr),
        .rd_data (disp_rd_data)
    );

    display_interface u_display_interface (
        .clk     (slow_clk),
        .rst_n   (rst_n_sync),
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
    touchscreen -> touchscreen_interface -> touch_commands -> rasterizer
    -> screen_mem -> display_interface -> display

    display_interface reads constantly. a write to the address being read that
    same cycle just shows up one frame later.
*/
