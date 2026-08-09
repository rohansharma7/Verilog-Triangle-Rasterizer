module cmd_processor (
    input logic clk,
    input logic rst_n,
    input logic ready,
    input logic [11:0] x_value, y_value,

    output logic [8 : 0] x1_in, y1_in, x2_in, y2_in, x3_in, y3_in,
    output logic start
);

logic [8:0] x1, y1, x2, y2, x3, y3;
assign x1_in = x1;
assign y1_in = y1;
assign x2_in = x2;
assign y2_in = y2;
assign x3_in = x3;
assign y3_in = y3;



typedef enum logic[1:0] {
    IDLE,
    READ1,
    READ2,
    READ3
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
        start <= 0;
    end
    READ1: begin
        if(ready) begin
            x1 <= x_value;
            y1 <= y_value;
        end
        start <= 0;
    end

    READ2: begin
        if(ready) begin
            x2 <= x_value;
            y2 <= y_value;
        end
        start <= 0;
    end

    READ3: begin
        if(ready) begin
            x3 <= x_value;
            y3 <= y_value;
            start <= 1;
        end else begin
            start <= 0;
        end
    end
    endcase
end

always_comb begin
    next_state = state;

    case (state)
    IDLE: begin
        next_state = READ1;
    end
    READ1: begin
        if(ready) begin
            next_state = READ2;
        end else begin
            next_state = READ1;
        end
    end

    READ2: begin
        if(ready) begin
            next_state = READ3;
        end else begin
            next_state = READ2;
        end
    end

    READ3: begin
        if(ready) begin
            next_state = READ1;
        end else begin
            next_state = READ3;
        end
    end
    endcase
end

endmodule