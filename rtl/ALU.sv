`include "defines.sv"

module ALU (
    input logic [31:0] operand_a_,
    input logic [31:0] operand_b_,
    input logic [3:0] alu_op_,
    output logic [31:0] result_
);

always_comb begin
    result_ = 32'd0;

    case (alu_op_)
        `ALUOP_ADD : result_ = operand_a_ + operand_b_;
        `ALUOP_SUB : result_ = operand_a_ - operand_b_;
        `ALUOP_AND : result_ = operand_a_ & operand_b_;
        `ALUOP_OR  : result_ = operand_a_ | operand_b_;
        `ALUOP_XOR : result_ = operand_a_ ^ operand_b_;
        `ALUOP_LT  : result_ = ($signed(operand_a_) < $signed(operand_b_))? 32'd1 : 32'd0;
        `ALUOP_LTU : result_ = (operand_a_ < operand_b_) ? 32'd1 : 32'd0;
        `ALUOP_SLL : result_ = operand_a_ << operand_b_[4:0];
        `ALUOP_SRL : result_ = operand_a_ >> operand_b_[4:0];
        `ALUOP_SRA : result_ = $signed(operand_a_) >>> operand_b_[4:0];
        `ALUOP_NOP : result_ = 32'd0;
        default: result_ = 32'd0;
    endcase
    
end
    
endmodule