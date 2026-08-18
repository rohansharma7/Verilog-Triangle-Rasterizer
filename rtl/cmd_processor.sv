module cmd_processor #(
    // Raw XPT2046 ADC range this panel actually produces. The defaults
    // assume the full 12-bit span, which is NOT what a real resistive
    // panel gives -- measured usable ranges are typically more like
    // 200..3900, and they differ per panel and per axis. Measure yours
    // and narrow these; that's the calibration step.
    parameter int X_RAW_MIN = 0,
    parameter int X_RAW_MAX = 4095,
    parameter int Y_RAW_MIN = 0,
    parameter int Y_RAW_MAX = 4095,

    parameter int SCREEN_W = 320,
    parameter int SCREEN_H = 240
) (
    input logic clk,
    input logic rst_n,
    input logic ready,
    input logic [11:0] x_value, y_value,

    output logic [8 : 0] x1_in, y1_in, x2_in, y2_in, x3_in, y3_in,
    output logic start
);

// ---------------------------------------------------------------------
// Touch coordinate scaling.
//
// The XPT2046 returns 12-bit ADC readings (0..4095) but the canvas is
// only 320x240. Previously these were just truncated to 9 bits, which
// wrapped modulo 512 -- a raw 600 landed at 88 -- so touches mapped to
// meaningless screen positions. Scaling also guarantees coordinates stay
// in range, which matters because rasterizer computes addr = 320*y + x
// with no bounds check: a y of 511 would address ~163,000, well past the
// end of the 76,800-entry framebuffer.
//
// The divides below are on parameters only, so they're evaluated at
// elaboration time by the synthesis tool -- no divider in hardware. What
// remains is a constant multiply and a shift.
// ---------------------------------------------------------------------
localparam int X_SCALE = (SCREEN_W * 65536) / (X_RAW_MAX - X_RAW_MIN);
localparam int Y_SCALE = (SCREEN_H * 65536) / (Y_RAW_MAX - Y_RAW_MIN);

function automatic logic [8:0] scale_x(input logic [11:0] raw);
    int unsigned t;
    if (raw <= X_RAW_MIN) return 9'd0;
    t = ((raw - X_RAW_MIN) * X_SCALE) >> 16;
    if (t >= SCREEN_W) return 9'(SCREEN_W - 1);
    return 9'(t);
endfunction

function automatic logic [8:0] scale_y(input logic [11:0] raw);
    int unsigned t;
    if (raw <= Y_RAW_MIN) return 9'd0;
    t = ((raw - Y_RAW_MIN) * Y_SCALE) >> 16;
    if (t >= SCREEN_H) return 9'(SCREEN_H - 1);
    return 9'(t);
endfunction

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
            x1 <= scale_x(x_value);
            y1 <= scale_y(y_value);
        end
        start <= 0;
    end

    READ2: begin
        if(ready) begin
            x2 <= scale_x(x_value);
            y2 <= scale_y(y_value);
        end
        start <= 0;
    end

    READ3: begin
        if(ready) begin
            x3 <= scale_x(x_value);
            y3 <= scale_y(y_value);
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