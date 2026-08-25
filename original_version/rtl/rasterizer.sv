module rasterizer (
    input logic clk,
    input logic rst_n,
    input logic start,
    input logic [8:0] x1_in, y1_in, x2_in, y2_in, x3_in, y3_in,
    input logic color_in,
    output logic done,
    output logic wr_en,
    output logic [16:0] addr,
    output logic data
);

    logic signed [9:0] max_x, min_x, max_y, min_y;
    logic signed [9:0] current_x, current_y;
    logic signed [9:0] x1, y1, x2, y2, x3, y3;
    logic color;
    logic box_count;

    assign data = color;
    assign addr = (320 * current_y) + current_x;

    typedef enum logic [1:0] {IDLE, BOX, RASTERIZE, DONE} rasterizer_fsm;
    rasterizer_fsm current_state, next_state;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_state <= IDLE;
        else begin
            current_state <= next_state;
            case (current_state)
                IDLE: begin
                    current_x <= 0;
                    current_y <= 0;
                    box_count <= 0;
                    x1 <= x1_in; x2 <= x2_in; x3 <= x3_in;
                    y1 <= y1_in; y2 <= y2_in; y3 <= y3_in;
                    color <= color_in;
                end
                BOX: begin
                    current_x <= min_x;
                    current_y <= min_y;
                    box_count <= box_count + 1'b1;
                end
                RASTERIZE: begin
                    if (current_x < max_x)
                        current_x <= current_x + 1;
                    else begin
                        current_x <= min_x;
                        current_y <= current_y + 1;
                    end
                end
                DONE: begin
                end
            endcase
        end
    end

    always_comb begin
        if ((x1 > x2) && (x1 > x3)) max_x = x1;
        else if (x2 > x3) max_x = x2;
        else max_x = x3;

        if ((x1 < x2) && (x1 < x3)) min_x = x1;
        else if (x2 < x3) min_x = x2;
        else min_x = x3;

        if ((y1 > y2) && (y1 > y3)) max_y = y1;
        else if (y2 > y3) max_y = y2;
        else max_y = y3;

        if ((y1 < y2) && (y1 < y3)) min_y = y1;
        else if (y2 < y3) min_y = y2;
        else min_y = y3;
    end

    always_comb begin
        next_state = current_state;
        done = 1'b0;
        wr_en = 1'b0;

        case (current_state)
            IDLE: if (start) next_state = BOX;
            BOX: if (box_count == 1) next_state = RASTERIZE;
            RASTERIZE: begin
                if ((((x2 - x1) * (current_y - y1) -
                      (y2 - y1) * (current_x - x1)) > 0) &&
                    (((x3 - x2) * (current_y - y2) -
                      (y3 - y2) * (current_x - x2)) > 0) &&
                    (((x1 - x3) * (current_y - y3) -
                      (y1 - y3) * (current_x - x3)) > 0))
                    wr_en = 1'b1;

                if ((current_x == max_x) && (current_y == max_y))
                    next_state = DONE;
            end
            DONE: begin
                done = 1'b1;
                next_state = IDLE;
            end
        endcase
    end
endmodule
