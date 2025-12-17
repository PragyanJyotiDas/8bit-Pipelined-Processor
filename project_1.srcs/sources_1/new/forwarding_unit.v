// =============================================================================
// File: forwarding_unit.v
// Description: Solves Data Hazards
// =============================================================================
module forwarding_unit (
    input  wire [2:0] rs1, rs2, ex_mem_rd, mem_wb_rd,
    input  wire       ex_mem_regwrite, mem_wb_regwrite,
    output reg [1:0]  forward_a, forward_b
);

    always @(*) begin
        forward_a = 2'b00;
        forward_b = 2'b00;

        // EX/MEM Forwarding
        if (ex_mem_regwrite && (ex_mem_rd != 0) && (ex_mem_rd == rs1)) forward_a = 2'b10;
        if (ex_mem_regwrite && (ex_mem_rd != 0) && (ex_mem_rd == rs2)) forward_b = 2'b10;

        // MEM/WB Forwarding
        if (mem_wb_regwrite && (mem_wb_rd != 0) && (mem_wb_rd == rs1) && 
            !(ex_mem_regwrite && (ex_mem_rd != 0) && (ex_mem_rd == rs1))) forward_a = 2'b01;
            
        if (mem_wb_regwrite && (mem_wb_rd != 0) && (mem_wb_rd == rs2) && 
            !(ex_mem_regwrite && (ex_mem_rd != 0) && (ex_mem_rd == rs2))) forward_b = 2'b01;
    end
endmodule