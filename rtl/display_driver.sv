module display_driver #(
    // Overridable so testbenches can shrink these from real-hardware
    // timing (>=10us reset pulse, >=120ms settle) down to something a
    // simulation can actually finish in reasonable wall-clock time.
    parameter logic [19:0] RESET_HOLD_CYCLES  = 20'd1000,
    parameter logic [19:0] SETTLE_HOLD_CYCLES = 20'd1_000_000
) (
    input logic clk,
    input logic rst_n,

    // framebuffer read port (from screen_mem)
    input logic [15:0] rd_data,
    output logic [16:0] rd_addr,

    // ILI9341 SPI interface
    output logic CS,
    output logic RESET,
    output logic DC,
    output logic SDI,
    output logic SCK,
    output logic LED
);

    // ------------------------------------------------------------------
    // Init command table: each entry is {DC bit, byte to send}.
    // DC = 0 -> command byte, DC = 1 -> data byte for the previous command.
    // Sequence: SWRESET, MADCTL, COLMOD(0x55 = 16bpp/RGB565), SLPOUT, DISPON
    // ------------------------------------------------------------------
    localparam int NUM_INIT_BYTES = 8;
    logic [8:0] init_rom [0:NUM_INIT_BYTES-1]; // bit8 = DC, bits[7:0] = data

    initial begin
        init_rom[0] = {1'b0, 8'h01}; // SWRESET
        init_rom[1] = {1'b0, 8'h36}; // MADCTL
        init_rom[2] = {1'b1, 8'h48}; // MADCTL data: MX=1,BGR=1 (adjust for orientation)
        init_rom[3] = {1'b0, 8'h3A}; // COLMOD
        init_rom[4] = {1'b1, 8'h55}; // COLMOD data: 16bpp / RGB565
        init_rom[5] = {1'b0, 8'h11}; // SLPOUT
        init_rom[6] = {1'b0, 8'h29}; // DISPON
        init_rom[7] = {1'b0, 8'h2C}; // RAMWR (start of first frame; window defaults to full screen)
    end

    localparam int NUM_WINDOW_BYTES = 10;
    // CASET (0x2A) + 4 bytes (0,0,319,0) then PASET (0x2B) + 4 bytes (0,0,0,239)
    logic [8:0] window_rom [0:NUM_WINDOW_BYTES-1];
    initial begin
        window_rom[0] = {1'b0, 8'h2A};        // CASET
        window_rom[1] = {1'b1, 8'h00};        // start col hi
        window_rom[2] = {1'b1, 8'h00};        // start col lo
        window_rom[3] = {1'b1, 8'h01};        // end col hi   (319 = 0x013F)
        window_rom[4] = {1'b1, 8'h3F};        // end col lo
        window_rom[5] = {1'b0, 8'h2B};        // PASET
        window_rom[6] = {1'b1, 8'h00};        // start row hi
        window_rom[7] = {1'b1, 8'h00};        // start row lo
        window_rom[8] = {1'b1, 8'h00};        // end row hi   (239 = 0x00EF)
        window_rom[9] = {1'b1, 8'hEF};        // end row lo
    end

    localparam logic [16:0] LAST_PIXEL = 17'd76799; // 320*240 - 1

    logic [3:0]  init_idx;
    logic [3:0]  window_idx;
    logic [3:0]  bit_count;   // counts 0..7 while shifting a byte out
    logic [7:0]  shift_reg;
    logic        dc_reg;
    logic [15:0] pixel_reg;   // latched pixel data being shifted (RAMWR phase)
    logic        pixel_byte_sel; // 0 = high byte, 1 = low byte

    // Hold counter for reset-low pulse and the post-reset settle wait.
    // RESET_HOLD_CYCLES/SETTLE_HOLD_CYCLES are module parameters (see
    // above) so a testbench can override them to small values instead
    // of waiting out real->hardware timing in simulation.
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
                    if (hold_count == RESET_HOLD_CYCLES) begin
                        hold_count <= 0;
                    end else begin
                        hold_count <= hold_count + 1;
                    end
                end

                RESET_SETTLE: begin
                    if (hold_count == SETTLE_HOLD_CYCLES) begin
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
                    // rd_addr already valid; screen_mem registers rd_data next cycle
                end

                FETCH_WAIT: begin
                    // wait one extra cycle for screen_mem's registered read
                end

                PIXEL_LOAD: begin
                    pixel_reg      <= rd_data;
                    dc_reg         <= 1'b1;
                    shift_reg      <= rd_data[15:8];
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
                            if (rd_addr == LAST_PIXEL) begin
                                rd_addr <= 0; // wrap to redraw next frame
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
        CS = 1'b1;

        case (state)
            RESET_PULSE: begin
                if (hold_count == RESET_HOLD_CYCLES) begin
                    next_state = RESET_SETTLE;
                end else begin
                    next_state = RESET_PULSE;
                end
            end

            RESET_SETTLE: begin
                if (hold_count == SETTLE_HOLD_CYCLES) begin
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
                    if (init_idx == NUM_INIT_BYTES - 1) begin
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
                    if (window_idx == NUM_WINDOW_BYTES - 1) begin
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
    display_driver drives an ILI9341 over 4-wire SPI (CS, DC, SDI, SCK).

    Flow:
    1. RESET_PULSE / INIT_LOAD / INIT_SHIFT: send the fixed power-on
       command sequence (SWRESET, MADCTL, COLMOD=0x55 for RGB565, SLPOUT,
       DISPON, then the RAMWR opcode that starts the first frame write).
    2. WINDOW_LOAD / WINDOW_SHIFT: send CASET + PASET to set the full-screen
       320x239 address window (only needs to happen once here, since RAMWR
       auto-increments through the whole window and this design free-runs
       forever redrawing the same window).
    3. FETCH / FETCH_WAIT / PIXEL_LOAD / PIXEL_SHIFT: read one pixel from
       screen_mem (1-cycle registered read latency, hence FETCH_WAIT),
       then shift its 16 bits out MSB-first as two bytes with DC=1.
       Loops back to FETCH after each pixel, wrapping rd_addr back to 0
       after the last pixel (76799) to continuously redraw the frame.

    Known simplification: no power/gamma tuning commands are sent (only
    the minimum required to get a picture up), and MADCTL's data byte
    (0x48) picks one particular orientation/color-order -- may need
    adjusting once tested against the real panel.
*/
