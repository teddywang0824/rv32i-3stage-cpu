// 根據 PC 的值讀取對應的 32bits 指令，為定義的則回傳 NOP
`include "defines.sv"

// module Program_ROM (
//     input logic [31:0] rom_addr, //pc 給的指令位置
//     output logic [31:0] rom_data //對應的32bit 指令
// );

//     always_comb begin
//         unique case (rom_addr)
//             32'h0000_0000: rom_data = 32'hffb0_0093; // addi x1, x0, -5
//             32'h0000_0004: rom_data = 32'h0010_0113; // addi x2, x0, 1
//             32'h0000_0008: rom_data = 32'h0060_2193; // slti x3, x0, 6
//             32'h0000_000c: rom_data = 32'h0060_b213; // sltiu x4, x1, 6
//             32'h0000_0010: rom_data = 32'h7ff1_7293; // andi x5, x2, 2047
//             32'h0000_0014: rom_data = 32'hfff0_4313; // xori x6, x0, -1
//             32'h0000_0018: rom_data = 32'h0550_6393; // ori  x7, x0, 0x55
//             32'h0000_001c: rom_data = 32'h0041_1413; // slli x8, x2, 4
//             32'h0000_0020: rom_data = 32'h0043_5493; // srli x9, x6, 4
//             32'h0000_0024: rom_data = 32'h4043_5513; // srai x10, x6, 4
//             32'h0000_0028: rom_data = 32'h0081_05b3; // add  x11, x2, x8
//             32'h0000_002c: rom_data = 32'h4081_0633; // sub  x12, x2, x8
//             32'h0000_0030: rom_data = 32'h0021_16b3; // sll  x13, x2, x2
//             32'h0000_0034: rom_data = 32'h0020_a733; // slt  x14, x1, x2
//             32'h0000_0038: rom_data = 32'h0020_b7b3; // sltu x15, x1, x2
//             32'h0000_003c: rom_data = 32'h0073_4833; // xor  x16, x6, x7
//             32'h0000_0040: rom_data = 32'h0023_58b3; // srl  x17, x6, x2
//             32'h0000_0044: rom_data = 32'h4023_5933; // sra  x18, x6, x2
//             32'h0000_0048: rom_data = 32'h0083_e9b3; // or   x19, x7, x8
//             32'h0000_004c: rom_data = 32'h0083_fa33; // and  x20, x7, x8

//             // RAW Hazard 測試
//             32'h0000_0050: rom_data = 32'h0050_0A93; // addi x21,x0,5
//             32'h0000_0054: rom_data = 32'h003A_8B13; // addi x22,x21,3
//             32'h0000_0058: rom_data = 32'h015B_0BB3; // add x23,x22,x21
//             default : rom_data = `I_NOP; // addi x0, x0, 0
//         endcase
//     end

// endmodule

// module Program_ROM (
//     input logic [31:0] rom_addr,

//     output logic [31:0] rom_data
// );
//     logic [31:0] memory [0:63];

//     always_comb begin
//         rom_data = memory[rom_addr[7:2]];
//     end
// endmodule

module Program_ROM #(
    parameter INIT_FILE = "",
    parameter integer WORDS = 64
) (
    input  logic        clk,
    input  logic        rst,

    input  logic        fetch_en,
    input  logic        kill_response,
    input  logic [31:0] fetch_addr,

    output logic        response_valid,
    output logic [31:0] response_pc,
    output logic [31:0] response_inst
);

    logic [31:0] memory [0:WORDS-1];
    integer i;

    initial begin
        for (i = 0; i < WORDS; i = i + 1)
            memory[i] = `I_NOP;

        if (INIT_FILE != "")
            $readmemh(INIT_FILE, memory);
    end

    always_ff @(posedge clk) begin
        if (rst || kill_response) begin
            response_valid <= 0;
        end else if (fetch_en) begin
            response_pc <= fetch_addr;
            response_inst <= memory[fetch_addr[31:2]];
            response_valid <= 1;
        end
    end

endmodule
