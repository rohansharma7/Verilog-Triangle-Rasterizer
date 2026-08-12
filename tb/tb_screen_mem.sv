module tb_screen_mem;
    logic clk = 0;
    logic wr_en;
    logic [16:0] wr_addr;
    logic [15:0] wr_data;
    logic [16:0] rd_addr;
    logic [15:0] rd_data;

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

        // --- Write pair 1: addr 5 <= 0xABCD ---
        wr_en   = 1;
        wr_addr = 5;
        wr_data = 16'hABCD;
        @(posedge clk);
        wr_en   = 0;

        // --- Write pair 2: addr 100 <= 0x1234 ---
        @(posedge clk);
        wr_en   = 1;
        wr_addr = 100;
        wr_data = 16'h1234;
        @(posedge clk);
        wr_en   = 0;

        // give screen_mem's registered write a cycle to land, then
        // read back both addresses (registered read has 1-cycle latency,
        // so we assert rd_addr, wait a cycle, then check rd_data)
        @(posedge clk);

        rd_addr = 5;
        @(posedge clk);
        if (rd_data !== 16'hABCD) begin
            $display("FAIL: addr 5 expected %h, got %h", 16'hABCD, rd_data);
            errors++;
        end else begin
            $display("PASS: addr 5 = %h", rd_data);
        end

        rd_addr = 100;
        @(posedge clk);
        if (rd_data !== 16'h1234) begin
            $display("FAIL: addr 100 expected %h, got %h", 16'h1234, rd_data);
            errors++;
        end else begin
            $display("PASS: addr 100 = %h", rd_data);
        end

        // sanity check: an address we never wrote should not equal either
        // written value (best-effort check; simulation memory is X by
        // default so this mainly guards against address-decoding bugs)
        rd_addr = 5000;
        @(posedge clk);
        if (rd_data === 16'hABCD || rd_data === 16'h1234) begin
            $display("FAIL: unwritten addr 5000 unexpectedly matched a written value: %h", rd_data);
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
