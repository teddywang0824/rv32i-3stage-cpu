// 將 pipeline 中的指令拆分為個個欄位 opcode、rd、funct3、rs1、rs2、funct7、imm
`include "defines.sv"

module Inst_Decoder (
    input logic [31:0] inst_r,
    
    output logic [6:0] opcode_,
    output logic [4:0] addr_rd_,
    output logic [2:0] funct3_,
    output logic [4:0] addr_rs1_,
    output logic [4:0] addr_rs2_,
    output logic [6:0] funct7_,
    output logic [31:0] imm_
);

    assign opcode_  = inst_r[6:0];
    assign addr_rd_ = inst_r[11:7];
    assign funct3_  = inst_r[14:12];
    assign addr_rs1_ = inst_r[19:15];
    assign addr_rs2_ = inst_r[24:20];
    assign funct7_   = inst_r[31:25];

    // assign imm_ = {{20{inst_r[31]}}, inst_r[31:20]}; // I-type immediate，只有12bits，要做 sign extension

    always_comb begin
        case (opcode_)
            `Opcode_I, `Opcode_LOAD, `Opcode_JALR :  imm_ = {{20{inst_r[31]}}, inst_r[31:20]};
            `Opcode_STORE : imm_ = {{20{inst_r[31]}}, inst_r[31:25], inst_r[11:7]};
            `Opcode_BRANCH : imm_ = {{19{inst_r[31]}}, inst_r[31], inst_r[7], inst_r[30:25], inst_r[11:8], 1'b0};
            `Opcode_LUI, `Opcode_AUIPC : imm_ = {inst_r[31:12], 12'b0};
            `Opcode_JAL : imm_ = {{11{inst_r[31]}}, inst_r[31], inst_r[19:12], inst_r[20], inst_r[30:21], 1'b0};
            default: imm_ = 0;
        endcase
    end
    
endmodule