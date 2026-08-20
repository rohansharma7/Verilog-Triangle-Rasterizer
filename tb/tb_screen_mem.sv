module tb_screen_mem;
    logic clk = 0;
    logic wr_en;
    logic [16:0] wr_addr;
    logic wr_data;
    logic [16:0] rd_addr;
    logic rd_data;

    int errors = 0;

    always #5 clk = ~clk;

    screen_mem dut (
        .clk     (clk),
        .wr_en   (wr_en),
        .wr_addr (wr_addr),
        .wr_data (wr_data),
        .rd_addr (rd_addr),
        .rd_data (rd_data)
    );

    initial begin
        wr_en   = 0;
        wr_addr = 0;
        wr_data = 0;
        rd_addr = 0;

        @(posedge clk);

        wr_en   = 1;
        wr_addr = 5;
        wr_data = 1'b1;
        @(posedge clk);
        wr_en   = 0;

        @(posedge clk);
        wr_en   = 1;
        wr_addr = 100;
        wr_data = 1'b1;
        @(posedge clk);
        wr_en   = 0;

        // write a 0 too, so we're not just checking 1-vs-X
        @(posedge clk);
        wr_en   = 1;
        wr_addr = 200;
        wr_data = 1'b0;
        @(posedge clk);
        wr_en   = 0;

        @(posedge clk);

        rd_addr = 5;
        @(posedge clk);
        #1; // same-edge race, see tb_rasterizer
        if (rd_data !== 1'b1) begin
            $display("FAIL: addr 5 expected 1, got %b", rd_data);
            errors++;
        end else begin
            $display("PASS: addr 5 = %b", rd_data);
        end

        rd_addr = 100;
        @(posedge clk);
        #1;
        if (rd_data !== 1'b1) begin
            $display("FAIL: addr 100 expected 1, got %b", rd_data);
            errors++;
        end else begin
            $display("PASS: addr 100 = %b", rd_data);
        end

        rd_addr = 200;
        @(posedge clk);
        #1;
        if (rd_data !== 1'b0) begin
            $display("FAIL: addr 200 expected 0, got %b", rd_data);
            errors++;
        end else begin
            $display("PASS: addr 200 = %b", rd_data);
        end

        // an address we never wrote should still be X, catches address
        // decoding aliasing onto a written location
        rd_addr = 5000;
        @(posedge clk);
        #1;
        if (rd_data === 1'b1) begin
            $display("FAIL: unwritten addr 5000 unexpectedly reads as 1");
            errors++;
        end

        if (errors == 0) begin
            $display("ALL TESTS PASSED");
        end else begin
            $display("%0d TEST(S) FAILED", errors);
        end

        $finish;
    end

endmodule
