module display_interface (
    input logic clk,
    input logic rst_n,

    input logic rd_data,
    output logic [16:0] rd_addr,

    output logic CS,
    output logic RESET,
    output logic DC,
    output logic SDI,
    output logic SCK,
    output logic LED
);

    logic [8:0] init_entry;

    logic [15:0] pixel_expanded;
    // FFFF is white and 0000 is black
    assign pixel_expanded = rd_data ? 16'hFFFF : 16'h0000;

    logic [4:0]  init_idx; // picks between the 18 initialization values
    logic [3:0]  bit_count;
    logic [7:0]  shift_reg;
    logic        dc_reg;
    logic [15:0] pixel_reg;
    logic        pixel_byte_sel;
    logic [19:0] hold_count;

    // values for initializing display
    always_comb begin
        case (init_idx)
            0: init_entry = {1'b0, 8'h01}; // SWRESET
            1: init_entry = {1'b0, 8'h36}; // MADCTL
            2: init_entry = {1'b1, 8'h48}; // MX=1, BGR=1
            3: init_entry = {1'b0, 8'h3A}; // COLMOD
            4: init_entry = {1'b1, 8'h55}; // RGB565
            5: init_entry = {1'b0, 8'h11}; // SLPOUT
            6: init_entry = {1'b0, 8'h29}; // DISPON
            7: init_entry = {1'b0, 8'h2C}; // RAMWR
            8: init_entry = {1'b0, 8'h2A}; // CASET
            9: init_entry = {1'b1, 8'h00}; // Column start high
            10: init_entry = {1'b1, 8'h00}; // Column start low
            11: init_entry = {1'b1, 8'h01}; // Column end high: 319
            12: init_entry = {1'b1, 8'h3F}; // Column end low
            13: init_entry = {1'b0, 8'h2B}; // PASET
            14: init_entry = {1'b1, 8'h00}; // Row start high
            15: init_entry = {1'b1, 8'h00}; // Row start low
            16: init_entry = {1'b1, 8'h00}; // Row end high: 239
            17: init_entry = {1'b1, 8'hEF}; // Row end low
            default: init_entry = 9'b0;
        endcase
    end

    typedef enum logic [3:0] {
        RESET_PULSE,
        RESET_SETTLE,
        INIT_LOAD,
        INIT_SHIFT,
        FETCH,
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
                    dc_reg    <= init_entry[8];
                    shift_reg <= init_entry[7:0];
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

                FETCH: begin
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
                                rd_addr <= 0; 
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
        SDI = 1'b0;  

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
                    if (init_idx == 17) begin
                        next_state = FETCH;
                    end else begin
                        next_state = INIT_LOAD;
                    end
                end else begin
                    next_state = INIT_SHIFT;
                end
            end

            FETCH: begin
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
