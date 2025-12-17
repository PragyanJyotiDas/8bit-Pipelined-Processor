// =============================================================================
// File: control_unit.v
// Description: Decodes Opcode into Control Signals
// =============================================================================
`include "defines.v"

module control_unit (
    input  wire [3:0] opcode,
    output reg        RegWrite, MemRead, MemWrite, ALUSrc, MemToReg, Branch, Jump,
    output reg [3:0]  ALUControl
);

    always @(*) begin
        // Default: All Off
        RegWrite = 0; MemRead = 0; MemWrite = 0; 
        ALUSrc = 0; MemToReg = 0; Branch = 0; Jump = 0;
        ALUControl = `ALU_ADD;

        case (opcode)
            `OP_ADD: begin RegWrite = 1; ALUControl = `ALU_ADD; end
            `OP_SUB: begin RegWrite = 1; ALUControl = `ALU_SUB; end
            `OP_AND: begin RegWrite = 1; ALUControl = `ALU_AND; end
            `OP_OR:  begin RegWrite = 1; ALUControl = `ALU_OR;  end
            `OP_XOR: begin RegWrite = 1; ALUControl = `ALU_XOR; end

            `OP_LDI: begin 
                RegWrite = 1; ALUSrc = 1; ALUControl = `ALU_ADD; 
            end
            `OP_LOAD: begin
                RegWrite = 1; MemRead = 1; ALUSrc = 1; MemToReg = 1; ALUControl = `ALU_ADD;
            end
            `OP_STORE: begin
                MemWrite = 1; ALUSrc = 1; ALUControl = `ALU_ADD;
            end
            `OP_BEQ: begin
                Branch = 1; ALUControl = `ALU_SUB;
            end
            `OP_JUMP: begin
                Jump = 1;
            end
        endcase
    end
endmodule