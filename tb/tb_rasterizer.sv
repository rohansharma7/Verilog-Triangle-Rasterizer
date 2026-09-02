class random_triangle;
    rand int x1, y1;
    rand int x2, y2;
    rand int x3, y3;

    constraint on_test_screen {
        x1 inside {[0:63]};
        y1 inside {[0:63]};
        x2 inside {[0:63]};
        y2 inside {[0:63]};
        x3 inside {[0:63]};
        y3 inside {[0:63]};
    }
endclass

module tb_rasterizer;
    logic clk = 0;
    logic [16:0] rd_addr;
    logic rd_data;

    logic rst_n, start;
    logic [8:0] x1_in, y1_in, x2_in, y2_in, x3_in, y3_in;
    logic color_in;

    logic done;

    int errors = 0;

    // pixels that should be filled for triangle (0,0),(6,0),(6,6).
    // worked these out separately, not from the RTL
    int expected_x [0:9] = '{2, 3, 3, 4, 4, 4, 5, 5, 5, 5};
    int expected_y [0:9] = '{1, 1, 2, 1, 2, 3, 1, 2, 3, 4};
    bit expected_mem [0:4095];
    random_triangle triangle;
    rasterizer_interface raster_if();

    always #5 clk = ~clk;

    screen_mem dut_mem (
        .clk     (clk),
        .wr_en   (raster_if.wr_en),
        .wr_mask (raster_if.wr_mask),
        .wr_addr (raster_if.wr_addr),
        .wr_data (raster_if.wr_data),
        .rd_addr (rd_addr),
        .rd_data (rd_data)
    );

    rasterizer dut_raster (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (start),
        .x1_in    (x1_in),
        .y1_in    (y1_in),
        .x2_in    (x2_in),
        .y2_in    (y2_in),
        .x3_in    (x3_in),
        .y3_in    (y3_in),
        .color_in (color_in),

        .done   (done),
        .wr_en  (raster_if.wr_en),
        .wr_mask(raster_if.wr_mask),
        .addr   (raster_if.wr_addr),
        .data   (raster_if.wr_data)
    );

    task automatic reset_test;
        rst_n = 0;
        start = 0;
        rd_addr = 0;
        x1_in = 0; y1_in = 0;
        x2_in = 0; y2_in = 0;
        x3_in = 0; y3_in = 0;
        color_in = 0;

        for (int i = 0; i < 4096; i++)
            expected_mem[i] = 0;

        repeat (2) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
    endtask

    task automatic draw_triangle(
        input int ax, ay, bx, by, cx, cy
    );
        @(posedge clk);
        #1;
        x1_in = ax; y1_in = ay;
        x2_in = bx; y2_in = by;
        x3_in = cx; y3_in = cy;
        color_in = 1'b1;
        start = 1'b1;
        @(posedge clk);
        #1;
        start = 1'b0;
    endtask

    task automatic generate_triangle(
        output int ax, ay, bx, by, cx, cy
    );
        int area;
        int swap_x, swap_y;

        area = 0;
        while (area == 0) begin
            triangle.randomize();

            ax = triangle.x1; ay = triangle.y1;
            bx = triangle.x2; by = triangle.y2;
            cx = triangle.x3; cy = triangle.y3;
            area = ((bx-ax)*(cy-ay)) - ((by-ay)*(cx-ax));
        end

        // the rtl currently expects this winding direction
        if (area < 0) begin
            swap_x = bx; swap_y = by;
            bx = cx; by = cy;
            cx = swap_x; cy = swap_y;
        end
    endtask

    task automatic check_triangle;
        bit expected;
        for (int x = 0; x <= 6; x++) begin
            for (int y = 0; y <= 6; y++) begin
                expected = 0;
                for (int i = 0; i < 10; i++) begin
                    if ((expected_x[i] == x) && (expected_y[i] == y))
                        expected = 1;
                end
                if (expected)
                    expected_mem[(64 * y) + x] = 1;

                rd_addr = (320 * y) + x;
                @(posedge clk);
                #1;

                if ((expected && (rd_data != 1'b1)) ||
                    (!expected && (rd_data == 1'b1))) begin
                    $display("FAIL: directed pixel (%0d,%0d) expected %b got %b",
                             x, y, expected, rd_data);
                    errors++;
                end
            end
        end
    endtask

    task automatic add_expected_triangle(
        input int ax, ay, bx, by, cx, cy
    );
        int e1, e2, e3;
        for (int y = 0; y < 64; y++) begin
            for (int x = 0; x < 64; x++) begin
                e1 = ((bx-ax)*(y-ay)) - ((by-ay)*(x-ax));
                e2 = ((cx-bx)*(y-by)) - ((cy-by)*(x-bx));
                e3 = ((ax-cx)*(y-cy)) - ((ay-cy)*(x-cx));
                if ((e1 > 0) && (e2 > 0) && (e3 > 0))
                    expected_mem[(64 * y) + x] = 1;
            end
        end
    endtask

    task automatic check_test_area(input int test_num);
        for (int y = 0; y < 64; y++) begin
            for (int x = 0; x < 64; x++) begin
                rd_addr = (320 * y) + x;
                @(posedge clk);
                #1;

                if ((expected_mem[(64 * y) + x] && (rd_data != 1'b1)) ||
                    (!expected_mem[(64 * y) + x] && (rd_data == 1'b1))) begin
                    $display("FAIL: random %0d pixel (%0d,%0d) expected %b got %b",
                             test_num, x, y, expected_mem[(64 * y) + x], rd_data);
                    errors++;
                end
            end
        end
    endtask

    initial begin
        int rx1, ry1, rx2, ry2, rx3, ry3;

        // setup and known triangle
        reset_test();
        draw_triangle(0, 0, 6, 0, 6, 6);
        wait (done);
        @(posedge clk); // let the last framebuffer write finish
        check_triangle();

        triangle = new();

        for (int test_num = 0; test_num < 20; test_num++) begin
            generate_triangle(rx1, ry1, rx2, ry2, rx3, ry3);

            $display("random %0d: (%0d,%0d) (%0d,%0d) (%0d,%0d)", test_num, rx1, ry1, rx2, ry2, rx3, ry3);

            draw_triangle(rx1, ry1, rx2, ry2, rx3, ry3);
            wait (done);
            @(posedge clk);
            add_expected_triangle(rx1, ry1, rx2, ry2, rx3, ry3);
            check_test_area(test_num);
        end

        if (errors == 0) begin
            $display("ALL TESTS PASSED (directed test plus 20 random triangles)");
        end else begin
            $display("%0d TEST(S) FAILED", errors);
        end

        $finish;
    end

endmodule
