module tb_top;
    logic clk = 0;
    logic rst_n;
    logic T_DO;
    logic T_IRQ;
    logic T_CS;
    logic T_DIN;
    logic T_CLK;
    logic CS;
    logic RESET;
    logic DC;
    logic SDI;
    logic SCK;
    logic LED;

    logic [7:0] command;
    logic [11:0] fake_x;
    logic [11:0] fake_y;
    logic [11:0] result;
    integer errors = 0;
    integer touch_number;
    integer command_number;
    integer bit_number;

    always #5 clk = ~clk;

    raster_top dut (
        .clk   (clk),
        .rst_n (rst_n),
        .T_DO  (T_DO),
        .T_IRQ (T_IRQ),
        .T_CS  (T_CS),
        .T_DIN (T_DIN),
        .T_CLK (T_CLK),
        .CS    (CS),
        .RESET (RESET),
        .DC    (DC),
        .SDI   (SDI),
        .SCK   (SCK),
        .LED   (LED)
    );

    initial begin
        T_DO = 0;
        T_IRQ = 1;
        rst_n = 0;

        repeat (3) @(posedge T_CLK);
        rst_n = 1;
        repeat (2) @(posedge T_CLK);

        for (touch_number = 0; touch_number < 3; touch_number = touch_number + 1) begin
            if (touch_number == 0) begin
                fake_x = 12'd130;
                fake_y = 12'd175;
            end
            if (touch_number == 1) begin
                fake_x = 12'd260;
                fake_y = 12'd175;
            end
            if (touch_number == 2) begin
                fake_x = 12'd260;
                fake_y = 12'd350;
            end

            T_IRQ = 0;
            @(negedge T_CS);

            for (command_number = 0; command_number < 2; command_number = command_number + 1) begin
                command = 0;
                for (bit_number = 0; bit_number < 8; bit_number = bit_number + 1) begin
                    @(posedge T_CLK);
                    command = {command[6:0], T_DIN};
                end

                repeat (3) @(negedge T_CLK);

                if (command == 8'hD0)
                    result = fake_x;
                else
                    result = fake_y;

                for (bit_number = 11; bit_number >= 0; bit_number = bit_number - 1) begin
                    @(negedge T_CLK);
                    T_DO = result[bit_number];
                end

                if (command_number == 0)
                    @(posedge T_CLK);
            end

            T_IRQ = 1;
            if (touch_number < 2)
                repeat (200) @(posedge clk);
        end

        wait (dut.raster_done);
        repeat (8) @(posedge clk);

        if (dut.u_screen_mem.mem2[642] !== 1'b1) begin
            $display("FAIL: pixel (18,16) should be filled");
            errors = errors + 1;
        end

        if (dut.u_screen_mem.mem2[401] === 1'b1) begin
            $display("FAIL: pixel (10,10) should not be filled");
            errors = errors + 1;
        end

        if (dut.u_screen_mem.mem0[0] === 1'b1) begin
            $display("FAIL: pixel (0,0) should not be filled");
            errors = errors + 1;
        end

        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d TEST(S) FAILED", errors);

        $finish;
    end
endmodule
