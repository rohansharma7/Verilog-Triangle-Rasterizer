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

    // one-cycle ready pulse, same as what touchscreen_interface does
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

        // touch 3, this one triggers start
        do_touch(12'd450, 12'd500);

        // start is only high for this one cycle - don't add another
        // @(posedge clk) here or it's already back to 0
        #1;
        if (start !== 1'b1) begin
            $display("FAIL: expected start=1 after third touch, got %b", start);
            errors++;
        end

        // expected = raw scaled by the default calibration.
        // x*5121>>16 and y*3840>>16, worked out by hand
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

        // FSM is back in READ1 now, so 3 more touches load another triangle.
        // feed the ADC extremes and check they clamp to the canvas corners,
        // that's what stops addr running past the framebuffer
        @(posedge clk);
        do_touch(12'd4095, 12'd4095);
        @(posedge clk);
        do_touch(12'd0,    12'd0);
        @(posedge clk);
        do_touch(12'd2048, 12'd2048);
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
