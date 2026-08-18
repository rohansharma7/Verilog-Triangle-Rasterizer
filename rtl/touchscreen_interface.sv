module touchscreen_interface (
    input logic clk,
    input logic T_DO,
    input logic T_IRQ,
    input logic rst_n,
    
    output logic T_CS,
    output logic T_DIN,
    output logic T_CLK,

    output logic [11:0] x_value, y_value,
    output logic ready
);

    logic axis; //0 = x, 1 = y
    logic [7:0] shift_out_reg;
    logic [11:0] shift_in_reg;
    logic [3:0] bit_count;
    logic [11:0] final_x_value, final_y_value;

    assign x_value = final_x_value;
    assign y_value = final_y_value;
    assign T_CLK = clk;


    typedef enum logic [1:0] {
        IDLE,
        SEND_CMD,
        ACQUIRE,
        READ_RESULT
     } state_t;

    state_t state, next_state;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end

        case (state)
            IDLE: begin
                axis <= 0;
                bit_count <= 0;
                shift_out_reg <= 8'hD0;
                ready <= 0;
            end

            SEND_CMD: begin
                shift_out_reg <= shift_out_reg << 1;
                if (bit_count == 7) begin
                    bit_count <= 0;
                end else begin
                    bit_count <= bit_count + 1;
                end
                ready <= 0;
            end

            ACQUIRE: begin
                if (bit_count == 2) begin
                    bit_count <= 0;
                end else begin
                    bit_count <= bit_count + 1;
                end
                ready <= 0;
            end

            READ_RESULT: begin
                shift_in_reg <= {shift_in_reg[10:0], T_DO};
                if (bit_count == 11) begin
                    bit_count <= 0;
                    if (axis == 0) begin
                        final_x_value <= {shift_in_reg[10:0], T_DO};
                        axis <= 1;
                        ready <= 0;
                    end else begin
                        final_y_value <= {shift_in_reg[10:0], T_DO};
                        ready <= 1;
                    end
                end else begin
                    bit_count <= bit_count + 1;
                    ready <= 0;
                end

                shift_out_reg <= 8'h90;
            end
        endcase

    end



    always_comb begin
        next_state = state;
        T_DIN = 1'b0; // default so every path drives T_DIN (avoids latch inference)

        case (state)
            IDLE: begin
                if(T_IRQ == 0) begin
                    next_state = SEND_CMD;
                end else begin
                    next_state = IDLE;
                end

                T_CS = 1;
            end

            SEND_CMD: begin
                if(bit_count == 7) begin
                    next_state = ACQUIRE;
                end else begin
                    next_state = SEND_CMD;
                end

                T_CS = 0;
                T_DIN = shift_out_reg[7];

            end
            ACQUIRE: begin
                if (bit_count == 2) begin
                    next_state = READ_RESULT;
                end else begin
                    next_state = ACQUIRE;
                end

                T_CS = 0;
            end
            READ_RESULT: begin
                if (bit_count == 11) begin
                    if (axis == 0) begin
                        next_state = SEND_CMD;
                    end else begin
                        next_state = IDLE;
                    end
                end
                T_CS = 0;
            end
        endcase        
    end

endmodule