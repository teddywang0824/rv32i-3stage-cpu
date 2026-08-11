module Forwarding_Unit (
    input logic ex_reg_write,
    input logic [4:0] ex_rd,
    input logic [31:0] rd_value_,
    input logic wb_reg_write,
    input logic [4:0] wb_rd,
    input logic [31:0] wb_value,
    input logic [4:0] id_rs1,
    input logic [4:0] id_rs2,
    input logic [31:0] rs1_value_,
    input logic [31:0] rs2_value_,

    output logic [31:0] forwarded_rs1_value,
    output logic [31:0] forwarded_rs2_value
);

    always_comb begin
        forwarded_rs1_value = rs1_value_;
        forwarded_rs2_value = rs2_value_;

        if (wb_reg_write && (wb_rd != 5'd0) && (wb_rd == id_rs1))
            forwarded_rs1_value = wb_value;
        if (wb_reg_write && (wb_rd != 5'd0) && (wb_rd == id_rs2))
            forwarded_rs2_value = wb_value;

        if (ex_reg_write && (ex_rd != 5'd0) && (ex_rd == id_rs1))
            forwarded_rs1_value = rd_value_;
        if (ex_reg_write && (ex_rd != 5'd0) && (ex_rd == id_rs2))
            forwarded_rs2_value = rd_value_;
    end

    
endmodule
