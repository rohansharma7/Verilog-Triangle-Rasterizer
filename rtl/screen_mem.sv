module screen_mem (
    input logic clk,
    input logic wr_en,
    input logic [16 : 0] wr_addr,
    input logic [15 : 0] wr_data,
    input logic [16 : 0] rd_addr,
    output logic [15 : 0] rd_data
);

logic[15 : 0] mem [76799 : 0];

always_ff @(posedge clk) begin
    rd_data <= mem[rd_addr];
    if (wr_en) begin
        mem[wr_addr] <= wr_data;
    end
end


endmodule