`include "defines.sv"
module Branch_Unit (
    input logic [31:0] rs1_value_,
    input logic [31:0] rs2_value_,
    input logic [31:0] imm_,
    input logic branch_en_,
    input logic [2:0] branch_op_,
    input logic [31:0] pc_,
    
    output logic branch_taken,
    output logic [31:0] branch_target
);
    logic compare_result;

    assign branch_target = pc_ + imm_;
    assign branch_taken = compare_result && branch_en_;

    always_comb begin
        case (branch_op_)
            `F3_BEQ: begin
                compare_result = (rs1_value_==rs2_value_); 
            end 
            `F3_BNE: begin
                compare_result = (rs1_value_!=rs2_value_);
            end 
            `F3_BLT: begin
                compare_result = ($signed(rs1_value_) < $signed(rs2_value_));
            end 
            `F3_BGE: begin
                compare_result = ($signed(rs1_value_) >= $signed(rs2_value_));
            end 
            `F3_BLTU: begin
                compare_result = ($unsigned(rs1_value_) < $unsigned(rs2_value_));
            end 
            `F3_BGEU: begin
                compare_result = ($unsigned(rs1_value_) >= $unsigned(rs2_value_));
            end 
            default: begin
                compare_result = 1'b0;
            end
        endcase
    end

endmodule