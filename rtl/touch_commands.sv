module touch_commands (
    input logic clk,
    input logic rst_n,
    input logic ready,
    input logic [11:0] x_value, y_value,

    output logic [8 : 0] x1_in, y1_in, x2_in, y2_in, x3_in, y3_in,
    output logic start
);

// turn the raw 0-4095 values into 320x240 screen coordinates
logic [20:0] scaled_x_math;
logic [19:0] scaled_y_math;
logic [8:0] scaled_x, scaled_y;
// scale the 4096 possible raw values to 320 x coordinates and 240 y coordinates
always_comb begin
    scaled_x_math = (x_value * 21'd320) >> 12;
    scaled_y_math = (y_value * 20'd240) >> 12;

    scaled_x = scaled_x_math[8:0];

    scaled_y = scaled_y_math[8:0];
end

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
            x1 <= scaled_x;
            y1 <= scaled_y;
        end
        start <= 0;
    end

    READ2: begin
        if(ready) begin
            x2 <= scaled_x;
            y2 <= scaled_y;
        end
        start <= 0;
    end

    READ3: begin
        if(ready) begin
            x3 <= scaled_x;
            y3 <= scaled_y;
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
