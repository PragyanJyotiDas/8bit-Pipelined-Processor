// =============================================================================
// File: alu.v
// Description: 8-bit Arithmetic Logic Unit
// =============================================================================
`include "defines.v"

module alu (
    input  wire [7:0] A,          // First Operand
    input  wire [7:0] B,          // Second Operand
    input  wire [3:0] ALUControl, // Operation Selector
    output reg  [7:0] Result,     // ALU Output
    output wire       Zero        // Zero Flag
);

    always @(*) begin
        case (ALUControl)
            `ALU_ADD: Result = A + B;
            `ALU_SUB: Result = A - B;
            `ALU_AND: Result = A & B;
            `ALU_OR:  Result = A | B;
            `ALU_XOR: Result = A ^ B;
            default:  Result = 8'b00000000;
        endcase
    end

    // Zero Flag is 1 if Result is 0
    assign Zero = (Result == 8'b0);

endmodule