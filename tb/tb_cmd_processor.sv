module tb_cmd_processor;
    logic clk = 0;
    logic rst_n;
    logic ready;
    logic [11:0] x_value, y_value;

    logic [8:0] x1_in, y1_in, x2_in, y2_in, x3_in, y3_in;
    logic start;

    int errors = 0;

    always #5 clk = ~clk;

    cmd_processor dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .ready   (ready),
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

    // Drives a single one-cycle "touch" pulse: puts x/y on the bus and
    // pulses ready for exactly one clock, mirroring how
    // touchscreen_interface's own `ready` output behaves.
    task automatic do_touch(input [11:0] x, input [11:0] y);
        x_value = x;
        y_value = y;
        ready   = 1;
        @(posedge clk);
        ready   = 0;
        x_value = 0;
        y_value = 0;
    endtask

    initial begin
        rst_n   = 0;
        ready   = 0;
        x_value = 0;
        y_value = 0;

        @(posedge clk);
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // touch 1
        do_touch(12'd100, 12'd200);
        @(posedge clk);

        // touch 2
        do_touch(12'd300, 12'd400);
        @(posedge clk);

        // touch 3 -- should trigger start on the following cycle
        do_touch(12'd500, 12'd600);

        // start is asserted combinationally-registered one cycle after
        // the third ready pulse is captured (see cmd_processor.sv:
        // start <= 1 happens in the same always_ff cycle READ3 sees
        // ready), so check it right away.
        @(posedge clk);
        if (start !== 1'b1) begin
            $display("FAIL: expected start=1 after third touch, got %b", start);
            errors++;
        end

        if (x1_in !== 9'd100 || y1_in !== 9'd200) begin
            $display("FAIL: point1 expected (100,200), got (%0d,%0d)", x1_in, y1_in);
            errors++;
        end
        if (x2_in !== 9'd300 || y2_in !== 9'd400) begin
            $display("FAIL: point2 expected (300,400), got (%0d,%0d)", x2_in, y2_in);
            errors++;
        end
        if (x3_in !== 9'd500 || y3_in !== 9'd600) begin
            $display("FAIL: point3 expected (500,600), got (%0d,%0d)", x3_in, y3_in);
            errors++;
        end

        // start should drop back to 0 the cycle after
        @(posedge clk);
        if (start !== 1'b0) begin
            $display("FAIL: expected start to deassert, still %b", start);
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
