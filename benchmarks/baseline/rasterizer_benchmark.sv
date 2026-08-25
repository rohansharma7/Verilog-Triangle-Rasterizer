module rasterizer_benchmark (
    input logic clk,
    input logic rst_n,
    input logic start,
    input logic [8:0] x1, y1, x2, y2, x3, y3,
    output logic done,
    output logic pixel_out
);

    logic wr_en;
    logic [16:0] wr_addr;
    logic wr_data;
    logic [16:0] rd_addr;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_addr <= 0;
        else if (rd_addr == 17'd76799)
            rd_addr <= 0;
        else
            rd_addr <= rd_addr + 1'b1;
    end

    rasterizer u_rasterizer (
        .clk(clk), .rst_n(rst_n), .start(start),
        .x1_in(x1), .y1_in(y1), .x2_in(x2), .y2_in(y2),
        .x3_in(x3), .y3_in(y3), .color_in(1'b1),
        .done(done), .wr_en(wr_en), .addr(wr_addr), .data(wr_data)
    );

    screen_mem u_screen_mem (
        .clk(clk), .wr_en(wr_en), .wr_addr(wr_addr), .wr_data(wr_data),
        .rd_addr(rd_addr), .rd_data(pixel_out)
    );
endmodule
