// 定義 CPU 共用的常數，例如 NOP 指令、opcode、funct3、funct7、ALU operation code 等等
`ifndef DEFINES_SV // ifndef 是 if not define的意思，避免一直重新定義
`define DEFINES_SV //真正定義的位置

// Basic Instruction
`define I_NOP 32'h00000013 // instruction no operation, I_NOP，使其作addi x0, x0, 0動作

// Opcode
// 定義指令的操作碼，判斷"這條指令是哪一大類"
`define Opcode_I 7'b0010011
`define Opcode_R_M 7'b0110011

// funct3 for I/R-type
// 3-bit 功能碼，用來區分在同個 opcode 下，進一步分辨是哪一條指令
// 注意，並非單獨運作，而是要搭配opcode、funct7 一起
`define F_ADD_SUB 3'b000
`define F_SLL 3'b001
`define F_SLT 3'b010
`define F_SLTU 3'b011
`define F_XOR 3'b100
`define F_SR 3'b101
`define F_OR 3'b110
`define F_AND 3'b111

// I-type ADDI
`define F_ADDI       3'b000
`define F_SLLI       3'b001
`define F_SLTI       3'b010
`define F_SLTIU      3'b011
`define F_XORI       3'b100
`define F_SRLI_SRAI  3'b101
`define F_ORI        3'b110
`define F_ANDI       3'b111

// I-type funct7
`define F7_SLLI 7'b0000000

`define F7_SRLI 7'b0000000
`define F7_SRAI 7'b0100000

// funct7 for R-type
// 7-bit 功能碼，用來區分在同個 opcode 和 funct3 下，進一步分辨是哪一條指令
// 注意，並非單獨運作，而是要搭配opcode、funct3 一起
`define F7_ADD 7'b0000000
`define F7_SUB 7'b0100000
`define F7_OPCODE_R 7'b0000000
`define F7_SRLI 7'b0000000
`define F7_SRAI 7'b0100000

// ALU operation code
// 定義 ALU 運算碼，用來判斷 ALU 應該執行哪一種運算
`define ALUOP_ADD   4'd0
`define ALUOP_SUB   4'd1
`define ALUOP_AND   4'd2
`define ALUOP_OR    4'd3
`define ALUOP_XOR   4'd4
`define ALUOP_LT    4'd5
`define ALUOP_LTU   4'd6
`define ALUOP_SLL   4'd7
`define ALUOP_SRL   4'd8
`define ALUOP_SRA   4'd9
`define ALUOP_NOP   4'd15

`endif
