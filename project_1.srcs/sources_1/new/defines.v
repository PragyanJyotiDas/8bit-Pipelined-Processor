// =============================================================================
// File: defines.v
// Description: Global constants for the 8-bit Processor
// =============================================================================

`ifndef DEFINES_V
`define DEFINES_V

// --- Opcode Definitions (4 bits) ---
`define OP_NOP   4'b0000 // No Operation
`define OP_ADD   4'b0001 // Addition
`define OP_SUB   4'b0010 // Subtraction
`define OP_AND   4'b0011 // Bitwise AND
`define OP_OR    4'b0100 // Bitwise OR
`define OP_XOR   4'b0101 // Bitwise XOR
`define OP_LOAD  4'b0110 // Load from Memory
`define OP_STORE 4'b0111 // Store to Memory
`define OP_LDI   4'b1000 // Load Immediate
`define OP_BEQ   4'b1001 // Branch if Equal
`define OP_JUMP  4'b1010 // Unconditional Jump

// --- ALU Control Signals ---
`define ALU_ADD  4'b0001
`define ALU_SUB  4'b0010
`define ALU_AND  4'b0011
`define ALU_OR   4'b0100
`define ALU_XOR  4'b0101

`endif // DEFINES_V