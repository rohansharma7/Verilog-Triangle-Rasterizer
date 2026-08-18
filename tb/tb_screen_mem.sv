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

        // --- Write 1: addr 5 <= 1 ---
        wr_en   = 1;
        wr_addr = 5;
        wr_data = 1'b1;
        @(posedge clk);
        wr_en   = 0;

        // --- Write 2: addr 100 <= 1 ---
        @(posedge clk);
        wr_en   = 1;
        wr_addr = 100;
        wr_data = 1'b1;
        @(posedge clk);
        wr_en   = 0;

        // --- Write 3: addr 200 <= 0 (explicit clear, so we're testing
        //     that a 0 write actually lands and isn't just unwritten X) ---
        @(posedge clk);
        wr_en   = 1;
        wr_addr = 200;
        wr_data = 1'b0;
        @(posedge clk);
        wr_en   = 0;

        // give screen_mem's registered write a cycle to land, then
        // read back each address (registered read has 1-cycle latency,
        // so we assert rd_addr, wait a cycle, then check rd_data)
        @(posedge clk);

        rd_addr = 5;
        @(posedge clk);
        #1; // let screen_mem's same-edge nonblocking update settle (see tb_rasterizer.sv for why)
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

        // sanity check: an address we never wrote should still be X,
        // guarding against address-decoding bugs that would alias it
        // onto one of the written locations.
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
