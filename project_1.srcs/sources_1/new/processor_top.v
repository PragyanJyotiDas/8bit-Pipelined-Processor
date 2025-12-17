// =============================================================================
// File: processor_top.v
// Description: Top-Level Pipelined Processor
// =============================================================================
`include "defines.v"

module processor_top (
    input wire clk,
    input wire reset,
    output wire [7:0] result_out
);

    // --- Wires ---
    reg  [7:0] pc_current;
    wire [7:0] pc_next, pc_plus_1;
    wire pc_stall, pc_branch_taken;
    wire [15:0] if_instr, id_instr;
    wire [7:0]  id_pc, branch_target;

    // Decode Wires
    wire [3:0] id_opcode = id_instr[15:12];
    wire [2:0] id_rd     = id_instr[11:9];
    wire [2:0] id_rs1    = id_instr[8:6];
    wire [2:0] id_rs2    = id_instr[5:3];
    wire [7:0] id_imm    = {2'b00, id_instr[5:0]};
    wire id_reg_write, id_mem_read, id_mem_write, id_alu_src, id_mem_to_reg, id_branch, id_jump;
    wire [3:0] id_alu_control;
    wire [7:0] id_read_data1, id_read_data2;

    // ID/EX Wires
    wire ex_reg_write, ex_mem_read, ex_mem_write, ex_alu_src, ex_mem_to_reg;
    wire [3:0] ex_alu_control;
    wire [7:0] ex_pc, ex_read_data1, ex_read_data2, ex_imm;
    wire [2:0] ex_rs1, ex_rs2, ex_rd;
    wire [7:0] alu_operand_a, alu_operand_b, alu_temp_b, ex_alu_result;
    wire ex_zero;
    wire [1:0] forward_a, forward_b;

    // EX/MEM Wires
    wire mem_reg_write, mem_mem_read, mem_mem_write, mem_mem_to_reg;
    wire [7:0] mem_alu_result, mem_write_data, mem_read_data_ram;
    wire [2:0] mem_rd;

    // MEM/WB Wires
    wire wb_reg_write, wb_mem_to_reg;
    wire [7:0] wb_mem_data, wb_alu_result, wb_write_data;
    wire [2:0] wb_rd;

    // --- FETCH STAGE ---
    assign pc_plus_1 = pc_current + 1;
    assign pc_next = (pc_branch_taken) ? branch_target : pc_plus_1;

    always @(posedge clk or posedge reset) begin
        if (reset) pc_current <= 0;
        else if (!pc_stall) pc_current <= pc_next;
    end

    instr_memory imem (.addr(pc_current), .instr(if_instr));

    if_id_reg if_id (
        .clk(clk), .reset(reset), .flush(pc_branch_taken), .stall(pc_stall),
        .pc_in(pc_current), .instr_in(if_instr),
        .pc_out(id_pc), .instr_out(id_instr)
    );

    // --- DECODE STAGE ---
    control_unit ctrl (
        .opcode(id_opcode),
        .RegWrite(id_reg_write), .MemRead(id_mem_read), .MemWrite(id_mem_write),
        .ALUSrc(id_alu_src), .MemToReg(id_mem_to_reg), .Branch(id_branch), .Jump(id_jump),
        .ALUControl(id_alu_control)
    );

    reg_file rf (
        .clk(clk), .we(wb_reg_write),
        .read_addr1(id_rs1), .read_addr2(id_rs2),
        .write_addr(wb_rd), .write_data(wb_write_data),
        .read_data1(id_read_data1), .read_data2(id_read_data2)
    );

    hazard_unit hazard (
        .id_rs1(id_rs1), .id_rs2(id_rs2),
        .ex_rd(ex_rd), .ex_mem_read(ex_mem_read),
        .stall(pc_stall)
    );

    wire branch_cond = (id_read_data1 == id_read_data2);
    assign pc_branch_taken = (id_branch && branch_cond) || id_jump;
    assign branch_target = (id_jump) ? {3'b0, id_instr[8:0]} : (id_pc + 1 + id_imm); 

    id_ex_reg id_ex (
        .clk(clk), .reset(reset || pc_stall),
        .reg_write_in(id_reg_write), .mem_read_in(id_mem_read), .mem_write_in(id_mem_write),
        .alu_src_in(id_alu_src), .mem_to_reg_in(id_mem_to_reg), .alu_control_in(id_alu_control),
        .pc_in(id_pc), .reg1_data_in(id_read_data1), .reg2_data_in(id_read_data2),
        .imm_in(id_imm), .rs1_addr_in(id_rs1), .rs2_addr_in(id_rs2), .rd_addr_in(id_rd),
        .reg_write_out(ex_reg_write), .mem_read_out(ex_mem_read), .mem_write_out(ex_mem_write),
        .alu_src_out(ex_alu_src), .mem_to_reg_out(ex_mem_to_reg), .alu_control_out(ex_alu_control),
        .pc_out(ex_pc), .reg1_data_out(ex_read_data1), .reg2_data_out(ex_read_data2),
        .imm_out(ex_imm), .rs1_addr_out(ex_rs1), .rs2_addr_out(ex_rs2), .rd_addr_out(ex_rd)
    );

    // --- EXECUTE STAGE ---
    forwarding_unit fwd (
        .rs1(ex_rs1), .rs2(ex_rs2),
        .ex_mem_rd(mem_rd), .ex_mem_regwrite(mem_reg_write),
        .mem_wb_rd(wb_rd), .mem_wb_regwrite(wb_reg_write),
        .forward_a(forward_a), .forward_b(forward_b)
    );

    assign alu_operand_a = (forward_a == 2'b10) ? mem_alu_result : 
                           (forward_a == 2'b01) ? wb_write_data : ex_read_data1;

    assign alu_temp_b    = (forward_b == 2'b10) ? mem_alu_result : 
                           (forward_b == 2'b01) ? wb_write_data : ex_read_data2;

    assign alu_operand_b = (ex_alu_src) ? ex_imm : alu_temp_b;

    alu main_alu (
        .A(alu_operand_a), .B(alu_operand_b),
        .ALUControl(ex_alu_control),
        .Result(ex_alu_result), .Zero(ex_zero)
    );

    ex_mem_reg ex_mem (
        .clk(clk), .reset(reset),
        .reg_write_in(ex_reg_write), .mem_read_in(ex_mem_read), .mem_write_in(ex_mem_write),
        .mem_to_reg_in(ex_mem_to_reg), .alu_result_in(ex_alu_result), .write_data_in(alu_temp_b),
        .rd_addr_in(ex_rd),
        .reg_write_out(mem_reg_write), .mem_read_out(mem_mem_read), .mem_write_out(mem_mem_write),
        .mem_to_reg_out(mem_mem_to_reg), .alu_result_out(mem_alu_result), .write_data_out(mem_write_data),
        .rd_addr_out(mem_rd)
    );

    // --- MEMORY STAGE ---
    data_memory dmem (
        .clk(clk), .we(mem_mem_write), .addr(mem_alu_result),
        .write_data(mem_write_data), .read_data(mem_read_data_ram)
    );

    mem_wb_reg mem_wb (
        .clk(clk), .reset(reset),
        .reg_write_in(mem_reg_write), .mem_to_reg_in(mem_mem_to_reg),
        .mem_data_in(mem_read_data_ram), .alu_result_in(mem_alu_result),
        .rd_addr_in(mem_rd),
        .reg_write_out(wb_reg_write), .mem_to_reg_out(wb_mem_to_reg),
        .mem_data_out(wb_mem_data), .alu_result_out(wb_alu_result),
        .rd_addr_out(wb_rd)
    );

    // --- WRITE BACK ---
    assign wb_write_data = (wb_mem_to_reg) ? wb_mem_data : wb_alu_result;
    assign result_out = wb_write_data;

endmodule