// =============================================================================
// File: reg_file.v
// Description: 8 x 8-bit Register File
// =============================================================================
module reg_file (
    input  wire       clk,
    input  wire       we,           // Write Enable
    input  wire [2:0] read_addr1,   // Address of Source Reg 1
    input  wire [2:0] read_addr2,   // Address of Source Reg 2
    input  wire [2:0] write_addr,   // Address to write to
    input  wire [7:0] write_data,   // Data to write
    output wire [7:0] read_data1,   // Output of Source Reg 1
    output wire [7:0] read_data2    // Output of Source Reg 2
);

    reg [7:0] registers [7:0];
    integer i;

    initial begin
        for (i = 0; i < 8; i = i + 1)
            registers[i] = 8'b0;
    end

    always @(posedge clk) begin
        if (we && write_addr != 3'b000) begin
            registers[write_addr] <= write_data;
        end
    end

    assign read_data1 = registers[read_addr1];
    assign read_data2 = registers[read_addr2];

endmodule