module Forwarding_Unit (
    input logic ex_reg_write,
    input logic [4:0] ex_rd,
    input logic [31:0] rd_value_,
    input logic [4:0] id_rs1,
    input logic [4:0] id_rs2,
    input logic [31:0] rs1_value_,
    input logic [31:0] rs2_value_,

    output logic [31:0] forwarded_rs1_value,
    output logic [31:0] forwarded_rs2_value
);

    assign forwarded_rs1_value = (ex_reg_write && (ex_rd != 5'd0) && (ex_rd == id_rs1)) ? rd_value_ : rs1_value_;
    assign forwarded_rs2_value = (ex_reg_write && (ex_rd != 5'd0) && (ex_rd == id_rs2)) ? rd_value_ : rs2_value_;

    
endmodule