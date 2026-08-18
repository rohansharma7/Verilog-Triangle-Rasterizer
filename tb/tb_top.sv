// Integration testbench for raster_top: drives a fake XPT2046 touch
// controller (via T_IRQ/T_DO, watching T_CS/T_DIN/T_CLK) to simulate
// three touches, then checks that the triangle they define gets
// rasterized into screen_mem correctly. display_driver's SPI outputs
// are left unchecked here (that's its own concern / future testbench);
// this test focuses on touch -> cmd_processor -> rasterizer -> screen_mem.
module tb_top;
    logic clk = 0;
    logic rst_n;

    logic T_DO, T_IRQ;
    logic T_CS, T_DIN, T_CLK;

    logic CS, RESET, DC, SDI, SCK, LED;

    int errors = 0;

    always #5 clk = ~clk;

    // Simulation overrides: divide-by-2 instead of divide-by-64, and
    // near-instant display power-on holds. At the real hardware values
    // the ILI9341 settle wait alone is 130,000 slow clocks (~8.3M fast
    // clocks) before anything observable happens.
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

    // ------------------------------------------------------------------
    // Fake XPT2046: waits for T_CS low + the 8-bit command byte on
    // T_DIN, then shifts the requested 12-bit result out on T_DO,
    // MSB-first, on each T_CLK falling edge (matching the real chip's
    // behavior and touchscreen_interface's own sampling-on-rising-edge
    // assumption).
    // ------------------------------------------------------------------
    logic [11:0] fake_x = 12'd150;
    logic [11:0] fake_y = 12'd250;

    // Reads the 8-bit command byte off T_DIN, sampling on T_CLK rising
    // edges (each edge captures the value held during the preceding cycle).
    task automatic read_cmd_byte(output logic [7:0] cmd_byte);
        int i;
        cmd_byte = 8'h00;
        for (i = 0; i < 8; i++) begin
            @(posedge T_CLK);
            cmd_byte = {cmd_byte[6:0], T_DIN};
        end
    endtask

    // Shifts a 12-bit result out on T_DO, MSB first, changing it on
    // falling edges so it's stable for the rising edge that samples it.
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

    // Models one complete touch: X conversion then Y conversion, both
    // inside a SINGLE T_CS assertion.
    //
    // Cycle alignment against touchscreen_interface's FSM (cycle 0 is the
    // first SEND_CMD cycle, i.e. when T_CS falls):
    //     cycles  0..7   SEND_CMD    (X command shifted out on T_DIN)
    //     cycles  8..10  ACQUIRE     (chip converting; nothing on the bus)
    //     cycles 11..22  READ_RESULT (X result sampled from T_DO)
    //     cycles 23..30  SEND_CMD    (Y command)
    //     cycles 31..33  ACQUIRE
    //     cycles 34..45  READ_RESULT (Y result)
    //
    // Two things this has to get right, both of which broke earlier
    // versions of this testbench:
    //   - T_CS stays LOW across both conversions (that's what the XPT2046
    //     expects and what the RTL does), so there is no second falling
    //     edge to wait on between X and Y.
    //   - The 3-cycle ACQUIRE gap is real. Skipping it drives the result
    //     bits three cycles early and the captured coordinates come out
    //     shifted.
    task automatic run_fake_touch();
        logic [7:0] cmd_byte;

        @(negedge T_CS);            // transaction starts, cycle 0

        // ---- X conversion ----
        read_cmd_byte(cmd_byte);    // posedges 1..8  <- cycles 0..7
        repeat (3) @(negedge T_CLK);// ACQUIRE, cycles 8..10
        drive_result(result_for(cmd_byte));  // negedges 11..22

        // ---- Y conversion ----
        @(posedge T_CLK);           // posedge 23: FSM re-enters SEND_CMD
        read_cmd_byte(cmd_byte);    // posedges 24..31 <- cycles 23..30
        repeat (3) @(negedge T_CLK);// ACQUIRE, cycles 31..33
        drive_result(result_for(cmd_byte));  // negedges 34..45
    endtask

    // Global watchdog. Without this, a testbench that blocks on an edge
    // that never arrives (e.g. waiting for a T_CS negedge that the RTL
    // never produces) just spins with the clock toggling forever, with
    // no error and no end. Any hang now terminates with a message.
    initial begin
        #1_000_000; // 1us simulated -- vastly more than this test needs
        $display("FAIL: global timeout -- simulation hung");
        $finish;
    end

    initial begin
        T_DO  = 0;
        T_IRQ = 1;
        rst_n = 0;

        // Hold reset long enough for several slow_clk edges, since the
        // submodules use synchronous reset and need clock edges to apply it.
        repeat (20) @(posedge clk);
        rst_n = 1;
        repeat (10) @(posedge clk);

        // These are RAW ADC values, which cmd_processor scales down to
        // screen coordinates. With its default full-range calibration
        // (screen_x = raw*5121>>16, screen_y = raw*3840>>16) these map to:
        //     raw (130,175) -> screen (10,10)
        //     raw (260,175) -> screen (20,10)
        //     raw (260,350) -> screen (20,20)
        // i.e. the same small triangle as before, an 11x11 bounding box so
        // the rasterizer finishes in ~121 cycles rather than ~10,200.
        // --- Touch 1 ---
        fake_x = 12'd130;
        fake_y = 12'd175;
        T_IRQ  = 0; // pen down
        run_fake_touch();
        T_IRQ = 1; // pen up
        // Must be longer than one slow_clk period (64 fast clocks) or the
        // FSM, which samples T_IRQ on slow_clk, may never observe pen-up
        // and would run the three touches together.
        repeat (200) @(posedge clk);

        // --- Touch 2 ---
        fake_x = 12'd260;   // -> screen x 20
        fake_y = 12'd175;   // -> screen y 10
        T_IRQ  = 0;
        run_fake_touch();
        T_IRQ = 1;
        repeat (200) @(posedge clk);

        // --- Touch 3 ---
        fake_x = 12'd260;   // -> screen x 20
        fake_y = 12'd350;   // -> screen y 20
        T_IRQ  = 0;
        run_fake_touch();
        T_IRQ = 1;

        // After 3 touches, cmd_processor pulses start and the rasterizer
        // scans the triangle's bounding box. Wait on the rasterizer's own
        // done signal rather than guessing a cycle count, with a timeout
        // so a hang still terminates the sim.
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

        // let the final write land before reading the framebuffer
        repeat (8) @(posedge clk);

        // (18,16) is strictly inside the triangle; (10,10) is a vertex,
        // which the strict >0 edge test deliberately excludes; (0,0) is
        // far outside the bounding box entirely.
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

    // Reads directly from the DUT's internal screen_mem storage array via
    // hierarchical reference (dut.u_screen_mem.mem[]). This is a
    // read-only peek, not a port connection -- important because
    // screen_mem's rd_addr port is already driven inside raster_top by
    // display_driver's continuous frame-scan; forcing rd_addr from here
    // would create a multi-driver conflict on that port. Peeking at the
    // array directly avoids that.
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
