module tb_rasterizer;
    logic clk = 0;
    logic wr_en;
    logic [11 : 0] wr_addr;
    logic [7 : 0] wr_data;
    logic [11 : 0] rd_addr;

    logic [7 : 0] rd_data;


    logic rst_n, start;
    logic [7 : 0] x1_in, y1_in, x2_in, y2_in, x3_in, y3_in, color_in;

    logic done;


    always #5 clk = ~clk;

    screen_mem dut (
    .clk(clk),
    .wr_en(wr_en),
    .wr_addr(wr_addr),
    .wr_data(wr_data),
    .rd_addr(rd_addr),
    .rd_data(rd_data)
    );

    rasterizer dut1 (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .x1_in(x1_in),
    .y1_in(y1_in),
    .x2_in(x2_in),
    .y2_in(y2_in),
    .x3_in(x3_in),
    .y3_in(y3_in),
    .color_in(color_in),

    .done(done),
    .wr_en(wr_en),
    .addr(wr_addr),
    .data(wr_data)
    );

    initial begin
        @(posedge clk);

       
        rd_addr = 0;
        rst_n = 0;

        @(posedge clk);
        @(posedge clk);

        rst_n = 1;
        color_in = 8'hFF;

        @(posedge clk);
        @(posedge clk);

        start = 1;
        x1_in = 0;
        y1_in = 0;
        x2_in = 6;
        y2_in = 0;
        x3_in = 6;
        y3_in = 6;
        @(posedge clk);
        start = 0;
        @(posedge clk);
        @(posedge clk);


       // $finish;

    end

endmodule