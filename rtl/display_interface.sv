module display_interface (
    input logic clk,
    input logic rst_n,

    input logic rd_data,          // 1bpp, expanded to RGB565 below
    output logic [16:0] rd_addr,

    output logic CS,
    output logic RESET,
    output logic DC,
    output logic SDI,
    output logic SCK,
    output logic LED
);

    // each entry is {DC, byte}. DC=0 command, DC=1 data
    logic [8:0] init_rom [0:7];

    initial begin
        init_rom[0] = {1'b0, 8'h01}; // SWRESET
        init_rom[1] = {1'b0, 8'h36}; // MADCTL
        init_rom[2] = {1'b1, 8'h48}; // MX=1,BGR=1, may need changing on real panel
        init_rom[3] = {1'b0, 8'h3A}; // COLMOD
        init_rom[4] = {1'b1, 8'h55}; // 16bpp RGB565
        init_rom[5] = {1'b0, 8'h11}; // SLPOUT
        init_rom[6] = {1'b0, 8'h29}; // DISPON
        init_rom[7] = {1'b0, 8'h2C}; // RAMWR
    end

    logic [8:0] window_rom [0:9];
    initial begin
        window_rom[0] = {1'b0, 8'h2A};  // CASET
        window_rom[1] = {1'b1, 8'h00};
        window_rom[2] = {1'b1, 8'h00};
        window_rom[3] = {1'b1, 8'h01};  // 319 = 0x013F
        window_rom[4] = {1'b1, 8'h3F};
        window_rom[5] = {1'b0, 8'h2B};  // PASET
        window_rom[6] = {1'b1, 8'h00};
        window_rom[7] = {1'b1, 8'h00};
        window_rom[8] = {1'b1, 8'h00};  // 239 = 0x00EF
        window_rom[9] = {1'b1, 8'hEF};
    end

    logic [15:0] pixel_expanded;
    assign pixel_expanded = rd_data ? 16'hFFFF : 16'h0000;

    logic [3:0]  init_idx;
    logic [3:0]  window_idx;
    logic [3:0]  bit_count;
    logic [7:0]  shift_reg;
    logic        dc_reg;
    logic [15:0] pixel_reg;
    logic        pixel_byte_sel;  // 0 = high byte, 1 = low byte
    logic [19:0] hold_count;

    typedef enum logic [3:0] {
        RESET_PULSE,
        RESET_SETTLE,
        INIT_LOAD,
        INIT_SHIFT,
        WINDOW_LOAD,
        WINDOW_SHIFT,
        FETCH,
        FETCH_WAIT,
        PIXEL_LOAD,
        PIXEL_SHIFT
    } state_t;

    state_t state, next_state;

    assign SCK   = clk;
    assign LED   = 1'b1;
    assign DC    = dc_reg;
    assign RESET = (state == RESET_PULSE) ? 1'b0 : 1'b1;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state      <= RESET_PULSE;
            init_idx   <= 0;
            window_idx <= 0;
            rd_addr    <= 0;
            hold_count <= 0;
        end else begin
            state <= next_state;

            case (state)
                RESET_PULSE: begin
                    init_idx <= 0;
                    if (hold_count == 20'd100) begin
                        hold_count <= 0;
                    end else begin
                        hold_count <= hold_count + 1;
                    end
                end

                RESET_SETTLE: begin
                    if (hold_count == 20'd130_000) begin
                        hold_count <= 0;
                    end else begin
                        hold_count <= hold_count + 1;
                    end
                end

                INIT_LOAD: begin
                    dc_reg    <= init_rom[init_idx][8];
                    shift_reg <= init_rom[init_idx][7:0];
                    bit_count <= 0;
                end

                INIT_SHIFT: begin
                    shift_reg <= shift_reg << 1;
                    if (bit_count == 7) begin
                        bit_count <= 0;
                        init_idx  <= init_idx + 1;
                    end else begin
                        bit_count <= bit_count + 1;
                    end
                end

                WINDOW_LOAD: begin
                    dc_reg    <= window_rom[window_idx][8];
                    shift_reg <= window_rom[window_idx][7:0];
                    bit_count <= 0;
                end

                WINDOW_SHIFT: begin
                    shift_reg <= shift_reg << 1;
                    if (bit_count == 7) begin
                        bit_count  <= 0;
                        window_idx <= window_idx + 1;
                    end else begin
                        bit_count <= bit_count + 1;
                    end
                end

                FETCH: begin
                end

                FETCH_WAIT: begin
                    // screen_mem read is registered, so wait a cycle
                end

                PIXEL_LOAD: begin
                    pixel_reg      <= pixel_expanded;
                    dc_reg         <= 1'b1;
                    shift_reg      <= pixel_expanded[15:8];
                    bit_count      <= 0;
                    pixel_byte_sel <= 0;
                end

                PIXEL_SHIFT: begin
                    shift_reg <= shift_reg << 1;
                    if (bit_count == 7) begin
                        bit_count <= 0;
                        if (pixel_byte_sel == 0) begin
                            shift_reg      <= pixel_reg[7:0];
                            pixel_byte_sel <= 1;
                        end else begin
                            pixel_byte_sel <= 0;
                            if (rd_addr == 17'd76799) begin
                                rd_addr <= 0;   // wrap, redraw next frame
                            end else begin
                                rd_addr <= rd_addr + 1;
                            end
                        end
                    end else begin
                        bit_count <= bit_count + 1;
                    end
                end

                default: ;
            endcase
        end
    end

    always_comb begin
        next_state = state;
        CS  = 1'b1;
        SDI = 1'b0;   // default, else latch

        case (state)
            RESET_PULSE: begin
                if (hold_count == 20'd100) begin
                    next_state = RESET_SETTLE;
                end else begin
                    next_state = RESET_PULSE;
                end
            end

            RESET_SETTLE: begin
                if (hold_count == 20'd130_000) begin
                    next_state = INIT_LOAD;
                end else begin
                    next_state = RESET_SETTLE;
                end
            end

            INIT_LOAD: begin
                next_state = INIT_SHIFT;
            end

            INIT_SHIFT: begin
                CS   = 1'b0;
                SDI  = shift_reg[7];
                if (bit_count == 7) begin
                    if (init_idx == 7) begin
                        next_state = WINDOW_LOAD;
                    end else begin
                        next_state = INIT_LOAD;
                    end
                end else begin
                    next_state = INIT_SHIFT;
                end
            end

            WINDOW_LOAD: begin
                next_state = WINDOW_SHIFT;
            end

            WINDOW_SHIFT: begin
                CS   = 1'b0;
                SDI  = shift_reg[7];
                if (bit_count == 7) begin
                    if (window_idx == 9) begin
                        next_state = FETCH;
                    end else begin
                        next_state = WINDOW_LOAD;
                    end
                end else begin
                    next_state = WINDOW_SHIFT;
                end
            end

            FETCH: begin
                next_state = FETCH_WAIT;
            end

            FETCH_WAIT: begin
                next_state = PIXEL_LOAD;
            end

            PIXEL_LOAD: begin
                next_state = PIXEL_SHIFT;
            end

            PIXEL_SHIFT: begin
                CS  = 1'b0;
                SDI = shift_reg[7];
                if (bit_count == 7 && pixel_byte_sel == 1) begin
                    next_state = FETCH;
                end else begin
                    next_state = PIXEL_SHIFT;
                end
            end

            default: next_state = RESET_PULSE;
        endcase
    end

endmodule

/*
    ILI9341 over 4-wire SPI.

    reset -> init command sequence -> CASET/PASET to set full screen window
    -> then loop forever reading one pixel from screen_mem and shifting it
    out as 2 bytes. wraps back to addr 0 after the last pixel.

    only sends the minimum init commands, no gamma/power tuning.
*/
