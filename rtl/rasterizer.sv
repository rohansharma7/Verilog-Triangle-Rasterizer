module rasterizer (
    input logic clk,
    input logic rst_n,
    input logic start,
    input logic [8 : 0] x1_in, y1_in, x2_in, y2_in, x3_in, y3_in,
    input logic color_in,   // 1bpp now, so just set/clear

    output logic done,
    output logic wr_en,
    output logic  [16 : 0] addr,
    output logic data
);



    logic signed [9 : 0] max_x, min_x, max_y, min_y;
    logic signed [9 : 0] current_x, current_y;
    logic box_count;
    logic signed [9 : 0] x1, y1, x2, y2, x3, y3;
    logic color;
    
    assign data = color;
    assign addr = (320 * current_y) + current_x;


    typedef enum logic [1 : 0] {
        IDLE,
        BOX,
        RASTERIZE,
        DONE
    } rasterizer_fsm;
    rasterizer_fsm current_state, next_state;

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            current_state <= IDLE;
        else begin
            current_state <= next_state;

            case(current_state)
                IDLE: begin
                    current_x <= 0;
                    current_y <= 0;
                    box_count <= 0;

                    x1 <= x1_in;
                    x2 <= x2_in;
                    x3 <= x3_in;
                    y1 <= y1_in;
                    y2 <= y2_in;
                    y3 <= y3_in;
                    color <= color_in;
                end
                BOX: begin
                    current_x <= min_x;
                    current_y <= min_y;
                    box_count <= box_count + 1;
                end
                RASTERIZE: begin
                    if (current_x < max_x) begin
                        current_x <= current_x + 1;
                    end else begin
                        current_x <= min_x;
                        current_y <= current_y + 1;
                    end


                end
                DONE: begin

                end
            endcase
        end
    end

    // pulled out of the BOX case branch - only assigning these in one state
    // left the others undriven and Quartus flagged it as a latch
    always_comb begin
        if ((x1 > x2) && (x1 > x3)) begin
            max_x = x1;
        end else if (x2 > x3) begin
            max_x = x2;
        end else begin
            max_x = x3;
        end

        if ((x1 < x2) && (x1 < x3)) begin
            min_x = x1;
        end else if (x2 < x3) begin
            min_x = x2;
        end else begin
            min_x = x3;
        end

        if ((y1 > y2) && (y1 > y3)) begin
            max_y = y1;
        end else if (y2 > y3) begin
            max_y = y2;
        end else begin
            max_y = y3;
        end

        if ((y1 < y2) && (y1 < y3)) begin
            min_y = y1;
        end else if (y2 < y3) begin
            min_y = y2;
        end else begin
            min_y = y3;
        end
    end

    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE: begin

                done = 0;
                if(start) begin
                    next_state = BOX;
                end
                wr_en = 0;
            end

            BOX: begin
                if (box_count == 1) begin
                    next_state = RASTERIZE;
                end
                done = 0;
                wr_en = 0;
            end

            RASTERIZE: begin
                if ((((x2 - x1) * (current_y - y1) - (y2 - y1) * (current_x - x1)) > 0)
                        && (((x3 - x2) * (current_y - y2) - (y3 - y2) * (current_x - x2)) > 0)
                        && (((x1 - x3) * (current_y - y3) - (y1 - y3) * (current_x - x3)) > 0)) begin
                    wr_en = 1;
                end else begin
                    wr_en = 0;
                end

                if ((current_x == max_x) && (current_y == max_y)) begin
                    next_state = DONE;
                end else begin
                    next_state = RASTERIZE;
                end

                done = 0;
            end

            DONE: begin
                next_state = IDLE;
                done = 1;
                wr_en = 0;
            end
        endcase
    end


endmodule



/*
    IDLE


    BOX
    - finds max and min x and y values

    RASTERIZE
    - Iterates through points as if its a 2D array from min to max x and y, 
    and sees if cross product > 0 for all three sides for each point.
*/