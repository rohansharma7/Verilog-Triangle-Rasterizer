// sniffs the SPI lines and checks the byte stream against the expected
// init sequence, window sequence, and first couple pixels
module tb_display_driver;
    logic clk = 0;
    logic rst_n;

    logic rd_data;
    logic [16:0] rd_addr;

    logic CS, RESET, DC, SDI, SCK, LED;

    int errors = 0;

    always #5 clk = ~clk;

    // tiny holds so reset/settle resolve fast
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

    // fake framebuffer. pixel 1 is set, everything else clear, so we get one
    // ON and one OFF pixel to check the expansion both ways. registered read
    // to match screen_mem
    always_ff @(posedge clk) begin
        rd_data <= (rd_addr == 17'd1);
    end

    // grab each byte off SDI while CS is low. SCK is just clk here
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
        // has to be @(posedge), not wait(). byte_ready is a 1-cycle pulse and
        // wait() falls straight through if it's still high, which made every
        // check read one byte late
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

        for (int i = 0; i < NUM_EXPECTED_INIT; i++) begin
            check_next_byte(expected_init[i], $sformatf("init[%0d]", i));
        end

        for (int i = 0; i < NUM_EXPECTED_WINDOW; i++) begin
            check_next_byte(expected_window[i], $sformatf("window[%0d]", i));
        end

        // pixel 0 is clear -> 0x0000
        check_next_byte({1'b1, 8'h00}, "pixel0_hi");
        check_next_byte({1'b1, 8'h00}, "pixel0_lo");

        // pixel 1 is set -> 0xFFFF
        check_next_byte({1'b1, 8'hFF}, "pixel1_hi");
        check_next_byte({1'b1, 8'hFF}, "pixel1_lo");

        if (errors == 0) begin
            $display("ALL TESTS PASSED");
        end else begin
            $display("%0d TEST(S) FAILED", errors);
        end

        $finish;
    end

endmodule
