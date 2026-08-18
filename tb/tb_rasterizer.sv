module tb_rasterizer;
    logic clk = 0;
    logic wr_en;
    logic [16:0] wr_addr;
    logic wr_data;
    logic [16:0] rd_addr;
    logic rd_data;

    logic rst_n, start;
    logic [8:0] x1_in, y1_in, x2_in, y2_in, x3_in, y3_in;
    logic color_in;

    logic done;

    int errors = 0;

    // Expected set of filled pixels for triangle (0,0),(6,0),(6,6),
    // computed independently (Python re-implementation of the same
    // edge-function/winding logic) -- see conversation history.
    localparam int NUM_EXPECTED = 10;
    int expected_x [0:NUM_EXPECTED-1] = '{2, 3, 3, 4, 4, 4, 5, 5, 5, 5};
    int expected_y [0:NUM_EXPECTED-1] = '{1, 1, 2, 1, 2, 3, 1, 2, 3, 4};

    always #5 clk = ~clk;

    screen_mem dut_mem (
        .clk     (clk),
        .wr_en   (wr_en),
        .wr_addr (wr_addr),
        .wr_data (wr_data),
        .rd_addr (rd_addr),
        .rd_data (rd_data)
    );

    rasterizer dut_raster (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (start),
        .x1_in    (x1_in),
        .y1_in    (y1_in),
        .x2_in    (x2_in),
        .y2_in    (y2_in),
        .x3_in    (x3_in),
        .y3_in    (y3_in),
        .color_in (color_in),

        .done   (done),
        .wr_en  (wr_en),
        .addr   (wr_addr),
        .data   (wr_data)
    );

    function automatic bit is_expected(int x, int y);
        for (int i = 0; i < NUM_EXPECTED; i++) begin
            if (expected_x[i] == x && expected_y[i] == y) begin
                return 1;
            end
        end
        return 0;
    endfunction

    initial begin
        rst_n    = 0;
        start    = 0;
        rd_addr  = 0;
        x1_in    = 0; y1_in = 0;
        x2_in    = 0; y2_in = 0;
        x3_in    = 0; y3_in = 0;
        color_in = 0;

        @(posedge clk);
        @(posedge clk);
        rst_n = 1;

        @(posedge clk);
        color_in = 1'b1;
        x1_in = 0; y1_in = 0;
        x2_in = 6; y2_in = 0;
        x3_in = 6; y3_in = 6;
        start = 1;

        @(posedge clk);
        start = 0;

        // wait for the rasterizer to finish (with a timeout so a broken
        // FSM can't hang the simulation forever)
        fork
            begin
                wait (done);
            end
            begin
                repeat (1000) @(posedge clk);
                $display("FAIL: timed out waiting for done");
                errors++;
            end
        join_any
        disable fork;

        @(posedge clk); // let the last write settle before reading back

        // Read back the full bounding box (0..6, 0..6) and compare
        // against the expected set. screen_mem's read has 1-cycle
        // registered latency, so assert rd_addr then check rd_data
        // one cycle later.
        for (int x = 0; x <= 6; x++) begin
            for (int y = 0; y <= 6; y++) begin
                rd_addr = (320 * y) + x;
                @(posedge clk);
                // screen_mem's always_ff and this testbench are both
                // triggered by the same posedge clk. Without this #1,
                // this process can resume and read rd_data BEFORE
                // screen_mem's own nonblocking update for this same edge
                // has landed -- a classic same-edge race between two
                // independent processes. The #1 delay pushes the read
                // into a later time step, after all NBA updates for this
                // edge (across every module) have definitely settled.
                #1;
                if (is_expected(x, y)) begin
                    if (rd_data !== 1'b1) begin
                        $display("FAIL: pixel (%0d,%0d) expected filled (1), got %b", x, y, rd_data);
                        errors++;
                    end
                end else begin
                    if (rd_data === 1'b1) begin
                        $display("FAIL: pixel (%0d,%0d) unexpectedly filled", x, y);
                        errors++;
                    end
                end
            end
        end

        if (errors == 0) begin
            $display("ALL TESTS PASSED (%0d pixels verified filled, rest verified empty)", NUM_EXPECTED);
        end else begin
            $display("%0d TEST(S) FAILED", errors);
        end

        $finish;
    end

endmodule
