// =============================================================================
// File: pipeline_regs.v
// Description: All 4 Pipeline Registers
// =============================================================================

module if_id_reg (
    input wire clk, reset, flush, stall,
    input wire [7:0] pc_in,
    input wire [15:0] instr_in,
    output reg [7:0] pc_out,
    output reg [15:0] instr_out
);
    always @(posedge clk or posedge reset) begin
        if (reset || flush) begin
            pc_out <= 0; instr_out <= 0;
        end else if (!stall) begin
            pc_out <= pc_in; instr_out <= instr_in;
        end
    end
endmodule

module id_ex_reg (
    input wire clk, reset,
    input wire reg_write_in, mem_read_in, mem_write_in, alu_src_in, mem_to_reg_in,
    input wire [3:0] alu_control_in,
    input wire [7:0] pc_in, reg1_data_in, reg2_data_in, imm_in,
    input wire [2:0] rs1_addr_in, rs2_addr_in, rd_addr_in,
    output reg reg_write_out, mem_read_out, mem_write_out, alu_src_out, mem_to_reg_out,
    output reg [3:0] alu_control_out,
    output reg [7:0] pc_out, reg1_data_out, reg2_data_out, imm_out,
    output reg [2:0] rs1_addr_out, rs2_addr_out, rd_addr_out
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            reg_write_out <= 0; mem_read_out <= 0; mem_write_out <= 0; 
            alu_src_out <= 0; mem_to_reg_out <= 0; alu_control_out <= 0;
            pc_out <= 0; reg1_data_out <= 0; reg2_data_out <= 0; imm_out <= 0;
            rs1_addr_out <= 0; rs2_addr_out <= 0; rd_addr_out <= 0;
        end else begin
            reg_write_out <= reg_write_in; mem_read_out <= mem_read_in; 
            mem_write_out <= mem_write_in; alu_src_out <= alu_src_in; 
            mem_to_reg_out <= mem_to_reg_in; alu_control_out <= alu_control_in;
            pc_out <= pc_in; reg1_data_out <= reg1_data_in; reg2_data_out <= reg2_data_in;
            imm_out <= imm_in; rs1_addr_out <= rs1_addr_in; rs2_addr_out <= rs2_addr_in;
            rd_addr_out <= rd_addr_in;
        end
    end
endmodule

module ex_mem_reg (
    input wire clk, reset,
    input wire reg_write_in, mem_read_in, mem_write_in, mem_to_reg_in,
    input wire [7:0] alu_result_in, write_data_in,
    input wire [2:0] rd_addr_in,
    output reg reg_write_out, mem_read_out, mem_write_out, mem_to_reg_out,
    output reg [7:0] alu_result_out, write_data_out,
    output reg [2:0] rd_addr_out
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            reg_write_out <= 0; mem_read_out <= 0; mem_write_out <= 0; mem_to_reg_out <= 0;
            alu_result_out <= 0; write_data_out <= 0; rd_addr_out <= 0;
        end else begin
            reg_write_out <= reg_write_in; mem_read_out <= mem_read_in; 
            mem_write_out <= mem_write_in; mem_to_reg_out <= mem_to_reg_in;
            alu_result_out <= alu_result_in; write_data_out <= write_data_in;
            rd_addr_out <= rd_addr_in;
        end
    end
endmodule

module mem_wb_reg (
    input wire clk, reset,
    input wire reg_write_in, mem_to_reg_in,
    input wire [7:0] mem_data_in, alu_result_in,
    input wire [2:0] rd_addr_in,
    output reg reg_write_out, mem_to_reg_out,
    output reg [7:0] mem_data_out, alu_result_out,
    output reg [2:0] rd_addr_out
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            reg_write_out <= 0; mem_to_reg_out <= 0;
            mem_data_out <= 0; alu_result_out <= 0; rd_addr_out <= 0;
        end else begin
            reg_write_out <= reg_write_in; mem_to_reg_out <= mem_to_reg_in;
            mem_data_out <= mem_data_in; alu_result_out <= alu_result_in;
            rd_addr_out <= rd_addr_in;
        end
    end
endmodule