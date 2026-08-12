// Testbench for display_driver: pre-loads a small fake screen_mem with
// known pixel values, then sniffs the SPI lines (CS/DC/SDI, sampled on
// SCK rising edge like a real ILI9341 would) and checks the byte stream
// against the expected init sequence, address-window sequence, and the
// first couple of pixels.
module tb_display_driver;
    logic clk = 0;
    logic rst_n;

    logic [15:0] rd_data;
    logic [16:0] rd_addr;

    logic CS, RESET, DC, SDI, SCK, LED;

    int errors = 0;

    always #5 clk = ~clk;

    // Small hold counts so the reset/settle states resolve quickly in sim.
    display_driver #(
        .RESET_HOLD_CYCLES  (20'd5),
        .SETTLE_HOLD_CYCLES (20'd10)
    ) dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .rd_data (rd_data),
        .rd_addr (rd_addr),
        .CS      (CS),
        .RESET   (RESET),
        .DC      (DC),
        .SDI     (SDI),
        .SCK     (SCK),
        .LED     (LED)
    );

    // Fake framebuffer: respond to rd_addr with a simple pattern
    // (pixel value = address, truncated to 16 bits) with the same
    // 1-cycle registered-read latency screen_mem has, so display_driver's
    // FETCH_WAIT state assumption holds here too.
    always_ff @(posedge clk) begin
        rd_data <= rd_addr[15:0];
    end

    // ------------------------------------------------------------------
    // SPI sniffer: captures each byte shifted out on SDI while CS is low,
    // sampling on SCK's rising edge (SCK is tied directly to clk in
    // display_driver, so this is just "sample on posedge clk while CS=0").
    // Also records the DC value latched at the start of each byte.
    // ------------------------------------------------------------------
    logic [7:0] captured_byte;
    logic       captured_dc;
    int         bit_pos = 0;
    logic       byte_ready = 0;

    always_ff @(posedge clk) begin
        byte_ready <= 0;
        if (!CS) begin
            captured_byte <= {captured_byte[6:0], SDI};
            if (bit_pos == 0) begin
                captured_dc <= DC;
            end
            if (bit_pos == 7) begin
                bit_pos    <= 0;
                byte_ready <= 1;
            end else begin
                bit_pos <= bit_pos + 1;
            end
        end else begin
            bit_pos <= 0;
        end
    end

    // Expected init sequence: {dc, byte}, matching display_driver's
    // init_rom exactly (SWRESET, MADCTL, MADCTL data, COLMOD, COLMOD
    // data, SLPOUT, DISPON, RAMWR).
    localparam int NUM_EXPECTED_INIT = 8;
    logic [8:0] expected_init [0:NUM_EXPECTED_INIT-1] = '{
        {1'b0, 8'h01},
        {1'b0, 8'h36},
        {1'b1, 8'h48},
        {1'b0, 8'h3A},
        {1'b1, 8'h55},
        {1'b0, 8'h11},
        {1'b0, 8'h29},
        {1'b0, 8'h2C}
    };

    // Expected window sequence: CASET + 4 bytes, PASET + 4 bytes.
    localparam int NUM_EXPECTED_WINDOW = 10;
    logic [8:0] expected_window [0:NUM_EXPECTED_WINDOW-1] = '{
        {1'b0, 8'h2A},
        {1'b1, 8'h00},
        {1'b1, 8'h00},
        {1'b1, 8'h01},
        {1'b1, 8'h3F},
        {1'b0, 8'h2B},
        {1'b1, 8'h00},
        {1'b1, 8'h00},
        {1'b1, 8'h00},
        {1'b1, 8'hEF}
    };

    task automatic check_next_byte(input logic [8:0] expected, input string label);
        // byte_ready is a registered pulse (one clk cycle wide). Using a
        // level-sensitive wait() here is the bug that caused every check
        // to read one byte late: if byte_ready is still 1 on the very
        // edge we resume on, wait() falls through immediately without
        // waiting for a fresh pulse. @(posedge byte_ready) only fires on
        // the 0->1 transition, so it can't double-trigger this way.
        @(posedge byte_ready);
        if (captured_dc !== expected[8] || captured_byte !== expected[7:0]) begin
            $display("FAIL: %s expected {dc=%b, byte=%h}, got {dc=%b, byte=%h}",
                      label, expected[8], expected[7:0], captured_dc, captured_byte);
            errors++;
        end else begin
            $display("PASS: %s = {dc=%b, byte=%h}", label, captured_dc, captured_byte);
        end
    endtask

    initial begin
        rst_n = 0;
        @(posedge clk);
        @(posedge clk);
        rst_n = 1;

        // Walk through the expected init sequence
        for (int i = 0; i < NUM_EXPECTED_INIT; i++) begin
            check_next_byte(expected_init[i], $sformatf("init[%0d]", i));
        end

        // Walk through the expected address-window sequence
        for (int i = 0; i < NUM_EXPECTED_WINDOW; i++) begin
            check_next_byte(expected_window[i], $sformatf("window[%0d]", i));
        end

        // First pixel: rd_addr should have been 0 when FETCH first ran,
        // so the fake framebuffer returns 16'h0000 -> expect two data
        // bytes {dc=1, 8'h00} and {dc=1, 8'h00}.
        check_next_byte({1'b1, 8'h00}, "pixel0_hi");
        check_next_byte({1'b1, 8'h00}, "pixel0_lo");

        // Second pixel: rd_addr should now be 1 -> 16'h0001 -> bytes
        // {dc=1, 8'h00} and {dc=1, 8'h01}.
        check_next_byte({1'b1, 8'h00}, "pixel1_hi");
        check_next_byte({1'b1, 8'h01}, "pixel1_lo");

        if (errors == 0) begin
            $display("ALL TESTS PASSED");
        end else begin
            $display("%0d TEST(S) FAILED", errors);
        end

        $finish;
    end

endmodule
