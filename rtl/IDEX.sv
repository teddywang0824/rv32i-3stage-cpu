
`include "defines.sv"
module IDEX (
    input logic clk,
    input logic rst,
    input logic flush_IDEX_,

    // direct from instr. decoder
    input logic [4:0] addr_rd_, // 目標暫存器位置
    input logic [31:0] imm_, 
    input logic [31:0] rs1_value_, 
    input logic [31:0] rs2_value_,

    // pass by control unit
    input logic reg_write_,
    input logic alu_src_imm_,
    input logic [1:0] operand_a_sel_,
    input logic [3:0] alu_op_,
    input logic valid_inst_,
    input logic [31:0] ifid_pc_,

    output logic [4:0] addr_rd_r,
    output logic [31:0] imm_r,
    output logic [31:0] rs1_value_r,
    output logic [31:0] rs2_value_r,

    output logic reg_write_r,
    output logic [3:0] alu_op_r,
    output logic alu_src_imm_r,
    output logic [1:0] operand_a_sel_r,
    output logic valid_inst_r,
    output logic [31:0] idex_pc_r
);

    always_ff @(posedge clk) begin
        if (rst) begin
            addr_rd_r   <= 5'd0;
            imm_r       <= 32'd0;
            rs1_value_r <= 32'd0;
            rs2_value_r <= 32'd0;

            reg_write_r <= 1'b0;
            alu_src_imm_r <= 1'b0;
            alu_op_r <= `ALUOP_NOP;
            valid_inst_r <= 1'b0;

            operand_a_sel_r <= 2'b0;
            idex_pc_r <= 32'b0;
        end
        else if (flush_IDEX_) begin
            addr_rd_r   <= 5'd0;
            imm_r       <= 32'd0;
            rs1_value_r <= 32'd0;
            rs2_value_r <= 32'd0;

            reg_write_r <= 1'b0;
            alu_src_imm_r <= 1'b0;
            alu_op_r <= `ALUOP_NOP;
            valid_inst_r <= 1'b0;

            operand_a_sel_r <= 2'b0;
            idex_pc_r <= 32'b0;
        end
        else begin
            addr_rd_r   <= addr_rd_;
            imm_r       <= imm_;
            rs1_value_r <= rs1_value_;
            rs2_value_r <= rs2_value_;

            reg_write_r <= reg_write_;
            alu_src_imm_r <= alu_src_imm_;
            alu_op_r <= alu_op_;
            valid_inst_r <= valid_inst_;

            operand_a_sel_r <= operand_a_sel_;
            idex_pc_r <= ifid_pc_;
        end
    end

endmodule