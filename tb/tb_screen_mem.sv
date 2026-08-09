module tb_screen_mem;
    logic clk = 0;
    logic wr_en;
    logic [11 : 0] wr_addr;
    logic [7 : 0] wr_data;
    logic [11 : 0] rd_addr;
    logic [7 : 0] rd_data;

    always #5 clk = ~clk;

    screen_mem dut (
    .clk(clk),
    .wr_en(wr_en),
    .wr_addr(wr_addr),
    .wr_data(wr_data),
    .rd_addr(rd_addr),
    .rd_data(rd_data)
    );

    initial begin
        @(posedge clk);

        wr_en = 0;
        wr_addr = 0;
        wr_data = 0;
        rd_addr = 0;

        @(posedge clk);
        @(posedge clk);
        wr_en = 1;
        wr_addr = 5;
        wr_data = 8'hFF;
        @(posedge clk);

        rd_addr = 5;
        @(posedge clk);

        wr_data = 10;
        wr_addr = 5;
        rd_addr = 5;
        
        @(posedge clk);
        rd_addr = 5;
        if(rd_data == 8'hFF) begin
            $display("PASS");
        end else begin
          $display("FAIL: expected %h, got %h", 8'h0A, rd_data);
        end

        $finish;

    end

endmodule