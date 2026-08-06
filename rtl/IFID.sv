// IF stage 和 ID stage 中間的 pipeline register
`include "defines.sv"

module IFID (
    input logic clk,
    input logic rst,
    input logic flush_IFID_,
    input logic [31:0] inst_, // 當前 Program ROM 根據 PC 讀出的指令
    input logic write_en_,
    input logic [31:0] pc_,

    output logic [31:0] inst_r, // 被 IFID register 存起來準備送去 Decode 的指令
    output logic [31:0] pc_r
);

    always_ff @(posedge clk) begin
        if (rst) begin 
            inst_r <= `I_NOP;
            pc_r <= 32'b0;
        end
        else if (flush_IFID_) begin
            inst_r <= `I_NOP;
            pc_r <= 32'b0;
        end
        else if (write_en_) begin
            inst_r <= inst_;
            pc_r <= pc_;
        end
    end
endmodule