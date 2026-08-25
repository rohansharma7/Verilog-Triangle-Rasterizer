// split into 8 banks so the rasterizer can write 8 pixels in one clock
module screen_mem (
    input logic clk, wr_en,
    input logic [7:0] wr_mask,
    input logic [13:0] wr_addr,
    input logic wr_data,
    input logic [16:0] rd_addr,
    output logic rd_data
);

logic mem0 [0:9599];
logic mem1 [0:9599];
logic mem2 [0:9599];
logic mem3 [0:9599];
logic mem4 [0:9599];
logic mem5 [0:9599];
logic mem6 [0:9599];
logic mem7 [0:9599];
logic rd0, rd1, rd2, rd3, rd4, rd5, rd6, rd7;
logic [2:0] rd_bit;

always_ff @(posedge clk) begin
    rd_bit <= rd_addr[2:0];
    rd0 <= mem0[rd_addr[16:3]];
    rd1 <= mem1[rd_addr[16:3]];
    rd2 <= mem2[rd_addr[16:3]];
    rd3 <= mem3[rd_addr[16:3]];
    rd4 <= mem4[rd_addr[16:3]];
    rd5 <= mem5[rd_addr[16:3]];
    rd6 <= mem6[rd_addr[16:3]];
    rd7 <= mem7[rd_addr[16:3]];

    if (wr_en && wr_mask[0]) mem0[wr_addr] <= wr_data;
    if (wr_en && wr_mask[1]) mem1[wr_addr] <= wr_data;
    if (wr_en && wr_mask[2]) mem2[wr_addr] <= wr_data;
    if (wr_en && wr_mask[3]) mem3[wr_addr] <= wr_data;
    if (wr_en && wr_mask[4]) mem4[wr_addr] <= wr_data;
    if (wr_en && wr_mask[5]) mem5[wr_addr] <= wr_data;
    if (wr_en && wr_mask[6]) mem6[wr_addr] <= wr_data;
    if (wr_en && wr_mask[7]) mem7[wr_addr] <= wr_data;
end

always_comb begin
    case (rd_bit)
        3'd0: rd_data = rd0;
        3'd1: rd_data = rd1;
        3'd2: rd_data = rd2;
        3'd3: rd_data = rd3;
        3'd4: rd_data = rd4;
        3'd5: rd_data = rd5;
        3'd6: rd_data = rd6;
        default: rd_data = rd7;
    endcase
end
endmodule
