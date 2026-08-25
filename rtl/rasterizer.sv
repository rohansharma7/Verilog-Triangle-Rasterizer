module rasterizer (
    input logic clk, rst_n, start,
    input logic [8:0] x1_in, y1_in, x2_in, y2_in, x3_in, y3_in,
    input logic color_in,
    output logic done, wr_en,
    output logic [7:0] wr_mask,
    output logic [13:0] addr,
    output logic data
);

    logic signed [9:0] max_x, min_x, max_y, min_y;
    logic signed [9:0] current_x, current_y;
    logic signed [9:0] x1, y1, x2, y2, x3, y3;
    logic color, box_count;
    logic signed [9:0] dx1, dy1, dx2, dy2, dx3, dy3;
    logic signed [9:0] delta_y1, delta_y2, delta_y3;
    logic signed [9:0] delta_x1, delta_x2, delta_x3;
    logic signed [9:0] lane_x [0:7];
    logic signed [19:0] product1a, product1b;
    logic signed [19:0] product2a, product2b;
    logic signed [19:0] product3a, product3b;
    logic signed [20:0] base_edge1, base_edge2, base_edge3;
    logic signed [20:0] edge1 [0:7];
    logic signed [20:0] edge2 [0:7];
    logic signed [20:0] edge3 [0:7];
    logic pipe_valid;
    logic signed [9:0] pipe_x, pipe_min_x, pipe_max_x;
    logic signed [9:0] pipe_dy1, pipe_dy2, pipe_dy3;
    logic signed [20:0] pipe_edge1, pipe_edge2, pipe_edge3;
    logic [13:0] pipe_addr;
    logic pipe_color;

    assign data = pipe_color;
    assign addr = pipe_addr;
    assign wr_en = pipe_valid && (|wr_mask);

    typedef enum logic [2:0] {IDLE, BOX, RASTERIZE, DRAIN, DONE} rasterizer_fsm;
    rasterizer_fsm current_state, next_state;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            pipe_valid <= 1'b0;
        end else begin
            current_state <= next_state;
            pipe_valid <= (current_state == RASTERIZE);

            if (current_state == RASTERIZE) begin
                pipe_x <= current_x;
                pipe_min_x <= min_x;
                pipe_max_x <= max_x;
                pipe_dy1 <= dy1;
                pipe_dy2 <= dy2;
                pipe_dy3 <= dy3;
                pipe_edge1 <= base_edge1;
                pipe_edge2 <= base_edge2;
                pipe_edge3 <= base_edge3;
                pipe_addr <= (40 * current_y) + (current_x >>> 3);
                pipe_color <= color;
            end

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
                    current_x <= {min_x[9:3], 3'b000};
                    current_y <= min_y;
                    box_count <= box_count + 1'b1;
                end
                RASTERIZE: begin
                    if ((current_x + 7) < max_x)
                        current_x <= current_x + 8;
                    else begin
                        current_x <= {min_x[9:3], 3'b000};
                        current_y <= current_y + 1;
                    end
                end
                DRAIN: begin
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

    // first part of the pipeline. get the edge values for the first pixel
    always_comb begin
        dx1 = x2 - x1; dy1 = y2 - y1;
        dx2 = x3 - x2; dy2 = y3 - y2;
        dx3 = x1 - x3; dy3 = y1 - y3;

        delta_y1 = current_y - y1;
        delta_y2 = current_y - y2;
        delta_y3 = current_y - y3;
        delta_x1 = current_x - x1;
        delta_x2 = current_x - x2;
        delta_x3 = current_x - x3;

        product1a = dx1 * delta_y1;
        product1b = dy1 * delta_x1;
        product2a = dx2 * delta_y2;
        product2b = dy2 * delta_x2;
        product3a = dx3 * delta_y3;
        product3b = dy3 * delta_x3;
        base_edge1 = product1a - product1b;
        base_edge2 = product2a - product2b;
        base_edge3 = product3a - product3b;
    end

    // second part. use offsets to check all 8 pixels while the first part is
    // already working on the next group
    always_comb begin
        wr_mask = 8'b0;
        for (int i = 0; i < 8; i++) begin
            lane_x[i] = pipe_x + i;
            edge1[i] = pipe_edge1 - (pipe_dy1 * i);
            edge2[i] = pipe_edge2 - (pipe_dy2 * i);
            edge3[i] = pipe_edge3 - (pipe_dy3 * i);

            if (pipe_valid &&
                (lane_x[i] >= pipe_min_x) && (lane_x[i] <= pipe_max_x) &&
                (edge1[i] > 0) && (edge2[i] > 0) && (edge3[i] > 0))
                wr_mask[i] = 1'b1;
        end
    end

    always_comb begin
        next_state = current_state;
        done = 1'b0;
        case (current_state)
            IDLE: if (start) next_state = BOX;
            BOX: if (box_count == 1) next_state = RASTERIZE;
            RASTERIZE: begin
                if (((current_x + 7) >= max_x) && (current_y == max_y))
                    next_state = DRAIN;
            end
            DRAIN: begin
                next_state = DONE;
            end
            DONE: begin
                done = 1'b1;
                next_state = IDLE;
            end
        endcase
    end
endmodule
