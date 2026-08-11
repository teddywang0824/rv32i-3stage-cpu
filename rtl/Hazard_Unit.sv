module Hazard_Unit (
    input logic  ex_valid,
    input logic  ex_mem_en,
    input logic  ex_mem_write,
    input logic  ex_reg_write,
    input logic  [4:0] ex_rd,

    input logic  id_valid,
    input logic  id_uses_rs1,
    input logic  id_uses_rs2,
    input logic  [4:0] id_rs1,
    input logic  [4:0] id_rs2,

    output logic load_use_stall
);
    assign load_use_stall = ex_valid
                          && ex_mem_en
                          && !ex_mem_write
                          && ex_reg_write
                          && id_valid
                          && (ex_rd != 5'd0)
                          && ((id_uses_rs1 && (ex_rd == id_rs1))
                           || (id_uses_rs2 && (ex_rd == id_rs2)));
endmodule
