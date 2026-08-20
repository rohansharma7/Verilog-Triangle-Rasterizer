// 1bpp framebuffer, 320x240. had to drop from RGB565 because that needs
// 1.2Mbit and the EP4CE6 only has ~276kbit. display_driver expands it back
module screen_mem (
    input logic clk,
    input logic wr_en,
    input logic [16 : 0] wr_addr,
    input logic wr_data,
    input logic [16 : 0] rd_addr,
    output logic rd_data
);

logic mem [76799 : 0];

always_ff @(posedge clk) begin
    rd_data <= mem[rd_addr];
    if (wr_en) begin
        mem[wr_addr] <= wr_data;
    end
end


endmodule
