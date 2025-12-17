// =============================================================================
// File: data_memory.v
// Description: Data Memory (RAM)
// =============================================================================
module data_memory (
    input  wire       clk,
    input  wire       we,
    input  wire [7:0] addr,
    input  wire [7:0] write_data,
    output wire [7:0] read_data
);

    reg [7:0] ram [255:0];
    integer i;

    initial begin
        for (i = 0; i < 256; i = i + 1)
            ram[i] = 8'b0;
    end

    always @(posedge clk) begin
        if (we)
            ram[addr] <= write_data;
    end

    assign read_data = ram[addr];

endmodule