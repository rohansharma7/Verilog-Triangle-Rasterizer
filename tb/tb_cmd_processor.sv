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

        // touch 3 -- this is the one that triggers start
        do_touch(12'd450, 12'd500);

        // do_touch returns immediately after the clock edge on which READ3
        // sampled `ready`. start <= 1 was scheduled at that edge, so start
        // is high during THIS cycle only -- the next edge returns the FSM
        // to READ1, which drives start back to 0. Waiting another
        // @(posedge clk) before checking (as an earlier version of this
        // testbench did) therefore always observed 0.
        #1; // let the same-edge nonblocking updates settle
        if (start !== 1'b1) begin
            $display("FAIL: expected start=1 after third touch, got %b", start);
            errors++;
        end

        // Expected values are the RAW touch readings after cmd_processor's
        // scaling, using its default full-range calibration:
        //   X_SCALE = 320*65536/4095 = 5121, screen_x = (raw*5121) >> 16
        //   Y_SCALE = 240*65536/4095 = 3840, screen_y = (raw*3840) >> 16
        // so raw x 100/300/450 -> 7/23/35 and raw y 200/400/500 -> 11/23/29.
        // These were computed independently rather than by re-running the
        // DUT's own formula, so this actually checks the scaling.
        if (x1_in !== 9'd7 || y1_in !== 9'd11) begin
            $display("FAIL: point1 expected (7,11), got (%0d,%0d)", x1_in, y1_in);
            errors++;
        end
        if (x2_in !== 9'd23 || y2_in !== 9'd23) begin
            $display("FAIL: point2 expected (23,23), got (%0d,%0d)", x2_in, y2_in);
            errors++;
        end
        if (x3_in !== 9'd35 || y3_in !== 9'd29) begin
            $display("FAIL: point3 expected (35,29), got (%0d,%0d)", x3_in, y3_in);
            errors++;
        end

        // start should drop back to 0 the cycle after
        @(posedge clk);
        #1;
        if (start !== 1'b0) begin
            $display("FAIL: expected start to deassert, still %b", start);
            errors++;
        end

        // ------------------------------------------------------------------
        // Scaling boundary check: the FSM is now back in READ1, so three
        // more touches load a second triangle. Feed the ADC extremes and
        // confirm they land exactly on the canvas corners rather than
        // overflowing -- this is what keeps rasterizer's unbounded
        // addr = 320*y + x from running past the framebuffer.
        // ------------------------------------------------------------------
        @(posedge clk);
        do_touch(12'd4095, 12'd4095); // max ADC -> bottom-right corner
        @(posedge clk);
        do_touch(12'd0,    12'd0);    // min ADC -> top-left corner
        @(posedge clk);
        do_touch(12'd2048, 12'd2048); // mid-scale
        #1;

        if (x1_in !== 9'd319 || y1_in !== 9'd239) begin
            $display("FAIL: max ADC expected (319,239), got (%0d,%0d)", x1_in, y1_in);
            errors++;
        end
        if (x2_in !== 9'd0 || y2_in !== 9'd0) begin
            $display("FAIL: min ADC expected (0,0), got (%0d,%0d)", x2_in, y2_in);
            errors++;
        end
        if (x3_in > 9'd319 || y3_in > 9'd239) begin
            $display("FAIL: mid ADC out of canvas: (%0d,%0d)", x3_in, y3_in);
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
