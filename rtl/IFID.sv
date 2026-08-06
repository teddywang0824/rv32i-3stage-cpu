// IF stage 和 ID stage 中間的 pipeline register
`include "defines.sv"

module IFID (
    input logic clk,
    input logic rst,
    input logic flush_IFID_,
    input logic [31:0] inst_, // 當前 Program ROM 根據 PC 讀出的指令
    input logic write_en_,

    output logic [31:0] inst_r // 被 IFID register 存起來準備送去 Decode 的指令
);

    always_ff @(posedge clk) begin
        if (rst) inst_r <= `I_NOP;
        else if (flush_IFID_) inst_r <= `I_NOP;
        else if (write_en_) inst_r <= inst_;
    end

endmodule