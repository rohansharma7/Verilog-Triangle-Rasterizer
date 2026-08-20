// integration test: fake touch controller drives 3 touches, then check the
// triangle landed in screen_mem. doesn't check display_driver's SPI output,
// tb_display_driver does that
module tb_top;
    logic clk = 0;
    logic rst_n;

    logic T_DO, T_IRQ;
    logic T_CS, T_DIN, T_CLK;

    logic CS, RESET, DC, SDI, SCK, LED;

    int errors = 0;

    always #5 clk = ~clk;

    // sim overrides: divide by 2 not 64, and skip the real 130k settle wait
    raster_top #(
        .CLK_DIV_HALF                (1),
        .DISPLAY_RESET_HOLD_CYCLES   (20'd2),
        .DISPLAY_SETTLE_HOLD_CYCLES  (20'd4)
    ) dut (
        .clk   (clk),
        .rst_n (rst_n),

        .T_DO  (T_DO),
        .T_IRQ (T_IRQ),
        .T_CS  (T_CS),
        .T_DIN (T_DIN),
        .T_CLK (T_CLK),

        .CS    (CS),
        .RESET (RESET),
        .DC    (DC),
        .SDI   (SDI),
        .SCK   (SCK),
        .LED   (LED)
    );

    logic [11:0] fake_x = 12'd150;
    logic [11:0] fake_y = 12'd250;

    task automatic read_cmd_byte(output logic [7:0] cmd_byte);
        int i;
        cmd_byte = 8'h00;
        for (i = 0; i < 8; i++) begin
            @(posedge T_CLK);
            cmd_byte = {cmd_byte[6:0], T_DIN};
        end
    endtask

    // change T_DO on falling edges so it's stable for the rising edge
    task automatic drive_result(input logic [11:0] result);
        int i;
        for (i = 11; i >= 0; i--) begin
            @(negedge T_CLK);
            T_DO = result[i];
        end
    endtask

    function automatic logic [11:0] result_for(input logic [7:0] cmd_byte);
        if (cmd_byte == 8'hD0)      return fake_x;
        else if (cmd_byte == 8'h90) return fake_y;
        else                        return 12'h000;
    endfunction

    // one touch = X conversion then Y, both inside one T_CS assertion.
    // cycle 0 is when T_CS falls:
    //   0..7 SEND_CMD, 8..10 ACQUIRE, 11..22 READ_RESULT (X)
    //   23..30 SEND_CMD, 31..33 ACQUIRE, 34..45 READ_RESULT (Y)
    // T_CS does NOT go high between X and Y, don't wait for a second negedge.
    // the 3 ACQUIRE cycles are real, skipping them shifts the data
    task automatic run_fake_touch();
        logic [7:0] cmd_byte;

        @(negedge T_CS);

        read_cmd_byte(cmd_byte);
        repeat (3) @(negedge T_CLK);
        drive_result(result_for(cmd_byte));

        @(posedge T_CLK);           // FSM re-enters SEND_CMD for Y
        read_cmd_byte(cmd_byte);
        repeat (3) @(negedge T_CLK);
        drive_result(result_for(cmd_byte));
    endtask

    // watchdog, otherwise a missed edge just spins forever with no error
    initial begin
        #1_000_000;
        $display("FAIL: global timeout -- simulation hung");
        $finish;
    end

    initial begin
        T_DO  = 0;
        T_IRQ = 1;
        rst_n = 0;

        // hold reset for a few slow_clk edges, submodules use sync reset
        repeat (20) @(posedge clk);
        rst_n = 1;
        repeat (10) @(posedge clk);

        // raw ADC values. cmd_processor scales them, so these map to
        // screen (10,10) (20,10) (20,20) - small bbox to keep the sim short
        fake_x = 12'd130;
        fake_y = 12'd175;
        T_IRQ  = 0;
        run_fake_touch();
        T_IRQ = 1;
        // needs to be longer than one slow_clk or the FSM never sees pen-up
        repeat (200) @(posedge clk);

        fake_x = 12'd260;
        fake_y = 12'd175;
        T_IRQ  = 0;
        run_fake_touch();
        T_IRQ = 1;
        repeat (200) @(posedge clk);

        fake_x = 12'd260;
        fake_y = 12'd350;
        T_IRQ  = 0;
        run_fake_touch();
        T_IRQ = 1;

        // wait on done rather than guessing a cycle count
        fork
            begin
                wait (dut.raster_done);
            end
            begin
                repeat (200_000) @(posedge clk);
                $display("FAIL: timed out waiting for rasterizer to finish");
                errors++;
            end
        join_any
        disable fork;

        repeat (8) @(posedge clk);

        // (10,10) is a vertex, strict >0 excludes it
        check_pixel(18, 16, 1);
        check_pixel(10, 10, 0);
        check_pixel(0,  0,  0);

        if (errors == 0) begin
            $display("ALL TESTS PASSED");
        end else begin
            $display("%0d TEST(S) FAILED", errors);
        end

        $finish;
    end

    // peek at mem[] directly instead of driving rd_addr - display_driver
    // already drives that port, would be a multi-driver conflict
    task automatic check_pixel(input int x, input int y, input bit expect_filled);
        logic [16:0] addr;
        logic        value;
        addr  = (320 * y) + x;
        value = dut.u_screen_mem.mem[addr];
        if (expect_filled) begin
            if (value !== 1'b1) begin
                $display("FAIL: pixel (%0d,%0d) expected filled, got %b", x, y, value);
                errors++;
            end
        end else begin
            if (value === 1'b1) begin
                $display("FAIL: pixel (%0d,%0d) unexpectedly filled", x, y);
                errors++;
            end
        end
    endtask

endmodule
