// 1-bit-per-pixel framebuffer for a 320x240 display.
//
// Sized this way because the EP4CE6 only has 30 M9K blocks (~276,480
// bits) total. A 16bpp RGB565 framebuffer at this resolution would need
// 320*240*16 = 1,228,800 bits -- roughly 4.5x more RAM than the chip
// physically has. At 1bpp it's 76,800 bits (~10 blocks), which fits with
// plenty of headroom. display_driver expands each bit to a full RGB565
// pixel on its way out to the panel.
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
