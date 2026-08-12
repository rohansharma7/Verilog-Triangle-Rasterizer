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

    raster_top dut (
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

    task automatic run_fake_touch_controller();
        logic [7:0] cmd_byte;
        logic [11:0] result;
        int i;

        // wait for T_CS to go low (start of a transaction)
        @(negedge T_CS);

        // shift in the 8-bit command byte, MSB first, sampled on T_CLK rising edge
        cmd_byte = 8'h00;
        for (i = 0; i < 8; i++) begin
            @(posedge T_CLK);
            cmd_byte = {cmd_byte[6:0], T_DIN};
        end

        if (cmd_byte == 8'hD0) begin
            result = fake_x;
        end else if (cmd_byte == 8'h90) begin
            result = fake_y;
        end else begin
            result = 12'h000;
        end

        // shift result out MSB first on falling edges (matches how
        // touchscreen_interface captures T_DO on the following rising edge)
        for (i = 11; i >= 0; i--) begin
            @(negedge T_CLK);
            T_DO = result[i];
        end
    endtask

    initial begin
        T_DO  = 0;
        T_IRQ = 1;
        rst_n = 0;

        @(posedge clk);
        @(posedge clk);
        rst_n = 1;

        // --- Touch 1 ---
        fake_x = 12'd100;
        fake_y = 12'd120;
        T_IRQ  = 0; // pen down
        fork
            run_fake_touch_controller(); // X phase
        join
        fork
            run_fake_touch_controller(); // Y phase
        join
        T_IRQ = 1; // pen up
        repeat (5) @(posedge clk);

        // --- Touch 2 ---
        fake_x = 12'd200;
        fake_y = 12'd120;
        T_IRQ  = 0;
        fork
            run_fake_touch_controller();
        join
        fork
            run_fake_touch_controller();
        join
        T_IRQ = 1;
        repeat (5) @(posedge clk);

        // --- Touch 3 ---
        fake_x = 12'd200;
        fake_y = 12'd220;
        T_IRQ  = 0;
        fork
            run_fake_touch_controller();
        join
        fork
            run_fake_touch_controller();
        join
        T_IRQ = 1;

        // after 3 touches, cmd_processor should pulse start and the
        // rasterizer should run; give it generous time to finish
        // (raster over the (100,120),(200,120),(200,220) bounding box)
        repeat (2000) @(posedge clk);

        // Read back a pixel we expect to be filled: a point clearly
        // inside the triangle, e.g. (180, 200), and a point clearly
        // outside, e.g. (0, 0).
        check_pixel(180, 200, 1);
        check_pixel(0, 0, 0);

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
        logic [15:0] value;
        addr  = (320 * y) + x;
        value = dut.u_screen_mem.mem[addr];
        if (expect_filled) begin
            if (value !== 16'hFFFF) begin
                $display("FAIL: pixel (%0d,%0d) expected filled, got %h", x, y, value);
                errors++;
            end
        end else begin
            if (value === 16'hFFFF) begin
                $display("FAIL: pixel (%0d,%0d) unexpectedly filled", x, y);
                errors++;
            end
        end
    endtask

endmodule
