// sniffs the SPI lines and checks the byte stream against the expected
// init sequence, window sequence, and first couple pixels
module tb_display_interface;
    logic clk = 0;
    logic rst_n;

    logic rd_data;
    logic [16:0] rd_addr;

    logic CS, RESET, DC, SDI, SCK, LED;

    int errors = 0;

    always #5 clk = ~clk;

    display_interface dut (
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
    always @(posedge clk) begin
        rd_data <= (rd_addr == 17'd1);
    end

    // grab each byte off SDI while CS is low. SCK is just clk here
    logic [7:0] captured_byte;
    logic       captured_dc;
    int         bit_pos = 0;
    logic       byte_ready = 0;

    always @(posedge clk) begin
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

    logic expected_dc;
    logic [7:0] expected_byte;
    integer byte_number;

    initial begin
        rst_n = 0;
        @(posedge clk);
        @(posedge clk);
        rst_n = 1;

        for (byte_number = 0; byte_number < 22; byte_number = byte_number + 1) begin
            case (byte_number)
                0:  begin expected_dc = 0; expected_byte = 8'h01; end
                1:  begin expected_dc = 0; expected_byte = 8'h36; end
                2:  begin expected_dc = 1; expected_byte = 8'h48; end
                3:  begin expected_dc = 0; expected_byte = 8'h3A; end
                4:  begin expected_dc = 1; expected_byte = 8'h55; end
                5:  begin expected_dc = 0; expected_byte = 8'h11; end
                6:  begin expected_dc = 0; expected_byte = 8'h29; end
                7:  begin expected_dc = 0; expected_byte = 8'h2C; end
                8:  begin expected_dc = 0; expected_byte = 8'h2A; end
                9:  begin expected_dc = 1; expected_byte = 8'h00; end
                10: begin expected_dc = 1; expected_byte = 8'h00; end
                11: begin expected_dc = 1; expected_byte = 8'h01; end
                12: begin expected_dc = 1; expected_byte = 8'h3F; end
                13: begin expected_dc = 0; expected_byte = 8'h2B; end
                14: begin expected_dc = 1; expected_byte = 8'h00; end
                15: begin expected_dc = 1; expected_byte = 8'h00; end
                16: begin expected_dc = 1; expected_byte = 8'h00; end
                17: begin expected_dc = 1; expected_byte = 8'hEF; end
                18: begin expected_dc = 1; expected_byte = 8'h00; end
                19: begin expected_dc = 1; expected_byte = 8'h00; end
                20: begin expected_dc = 1; expected_byte = 8'hFF; end
                default: begin expected_dc = 1; expected_byte = 8'hFF; end
            endcase

            @(posedge byte_ready);
            if (captured_dc !== expected_dc || captured_byte !== expected_byte) begin
                $display("FAIL: byte %0d expected %b %h, got %b %h",
                         byte_number, expected_dc, expected_byte,
                         captured_dc, captured_byte);
                errors++;
            end
        end

        if (errors == 0) begin
            $display("ALL TESTS PASSED");
        end else begin
            $display("%0d TEST(S) FAILED", errors);
        end

        $finish;
    end

endmodule
