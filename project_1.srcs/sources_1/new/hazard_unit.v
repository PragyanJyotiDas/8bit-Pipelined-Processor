// =============================================================================
// File: hazard_unit.v
// Description: Detects Load-Use Hazards
// =============================================================================
module hazard_unit (
    input  wire [2:0] id_rs1,
    input  wire [2:0] id_rs2,
    input  wire [2:0] ex_rd,
    input  wire       ex_mem_read,
    output reg        stall
);
    always @(*) begin
        stall = 0;
        if (ex_mem_read && ((ex_rd == id_rs1) || (ex_rd == id_rs2))) begin
            stall = 1;
        end
    end
endmodule