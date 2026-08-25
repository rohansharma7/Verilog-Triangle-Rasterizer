// basic 320x240 framebuffer with 1 bit for each pixel
module screen_mem (
    input logic clk,
    input logic wr_en,
    input logic [16:0] wr_addr,
    input logic wr_data,
    input logic [16:0] rd_addr,
    output logic rd_data
);

logic mem [0:76799];

always_ff @(posedge clk) begin
    rd_data <= mem[rd_addr];
    if (wr_en)
        mem[wr_addr] <= wr_data;
end
endmodule
