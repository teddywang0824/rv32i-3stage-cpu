// 定義 CPU 共用的常數，例如 NOP 指令、opcode、funct3、funct7、ALU operation code 等等
`ifndef DEFINES_SV // ifndef 是 if not define的意思，避免一直重新定義
`define DEFINES_SV //真正定義的位置

// Basic Instruction
`define I_NOP 32'h00000013 // instruction no operation, I_NOP，使其作addi x0, x0, 0動作

// RV32I Core v1.0 architectural contract constants.
// See docs/rv32i-core-spec.md.  These constants define the target contract;
// later milestones connect the FENCE/SYSTEM/trap constants to the datapath.
`define RV32_XLEN            32
`define RV32_IALIGN_BITS     32
`define RV32_RESET_VECTOR    32'h0000_0000
`define RV32_IMEM_WORDS      64
`define RV32_DMEM_WORDS      1024

// Opcode
// 定義指令的操作碼，判斷"這條指令是哪一大類"
`define Opcode_I        7'b0010011
`define Opcode_R_M      7'b0110011
`define Opcode_LOAD     7'b0000011 // Itype
`define Opcode_JALR     7'b1100111 // Itype
`define Opcode_STORE    7'b0100011 // Stype
`define Opcode_BRANCH   7'b1100011 // Btype
`define Opcode_LUI      7'b0110111 // Utype
`define Opcode_AUIPC    7'b0010111 // Utype
`define Opcode_JAL      7'b1101111 // Jtype
`define Opcode_MISC_MEM 7'b0001111 // FENCE
`define Opcode_SYSTEM   7'b1110011 // ECALL / EBREAK

// Fixed encodings in the RV32I v1.0 target contract.
`define F3_FENCE        3'b000
`define F3_SYSTEM_PRIV  3'b000
`define I_ECALL         32'h0000_0073
`define I_EBREAK        32'h0010_0073

// trap 發生的例外種類
`define TRAP_INST_ADDR_MISALIGNED 4'd0
`define TRAP_ILLEGAL_INSTRUCTION  4'd2
`define TRAP_BREAKPOINT           4'd3
`define TRAP_LOAD_ADDR_MISALIGNED 4'd4
`define TRAP_STORE_ADDR_MISALIGNED 4'd6
`define TRAP_ENV_CALL             4'd11

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

// 會使用的 operand_a 可能對象

`define OP_A_RS1    2'd0
`define OP_A_ZERO   2'd1
`define OP_A_PC     2'd3

// 會使用的 operand_b 可能對象

`define OP_B_RS2    2'd0
`define OP_B_IMM    2'd1
`define OP_B_FOUR   2'd3


// Branch 解碼
// 31       30       25 24    20 19    15 14  12 11      8 7       6      0
// +----------+---------+--------+--------+------+----------+--------+--------+
// | imm[12]  |imm[10:5]|  rs2   |  rs1   |funct3| imm[4:1] |imm[11]| opcode |
// +----------+---------+--------+--------+------+----------+--------+--------+

// Branch指令 funct3
`define F3_BRANCH_NONE     3'b010

`define F3_BEQ      3'b000 // rs1 == rs2
`define F3_BNE      3'b001 // rs1 != rs2
`define F3_BLT      3'b100 // rs1 <  rs2 (signed)
`define F3_BGE      3'b101 // rs1 >= rs2 (signed)
`define F3_BLTU     3'b110 // rs1 <  rs2 (unsigned)
`define F3_BGEU     3'b111 // rs1 >= rs2 (unsigned)

// Jump 指令編碼(用於funct3)
`define F3_JALR   3'b000
`define F3_JAL    3'b001   

// Store funct3
`define F3_SB 3'b000
`define F3_SH 3'b001
`define F3_SW 3'b010
`define F3_STORE_NONE 3'b011

// Load funct3
`define F3_LB 3'b000
`define F3_LH 3'b001
`define F3_LW 3'b010
`define F3_LBU 3'b100
`define F3_LHU 3'b101

`define F3_LOAD_NONE 3'b011

`endif
