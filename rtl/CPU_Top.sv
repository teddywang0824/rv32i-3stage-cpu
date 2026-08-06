`include "defines.sv"

module CPU_Top (
    input logic clk,
    input logic rst
);

// ------------------------------------------------------------
// Internal wires
// ------------------------------------------------------------

// Controller signals
logic flush_IFID_;
logic flush_IDEX_;
logic rst_pc_;

// PC / ROM signals
logic [31:0] pc;
logic [31:0] pc_next_;
logic [31:0] inst_;

// IF/ID signal
logic [31:0] inst_r;

// Decoder signals
logic [6:0]  opcode_;
logic [4:0]  addr_rd_;
logic [2:0]  funct3_;
logic [4:0]  addr_rs1_;
logic [4:0]  addr_rs2_;
logic [6:0]  funct7_;
logic [31:0] imm_;

// Register file signals
logic        write_regf_en_r;
logic [4:0]  addr_rd_r;
logic [31:0] rd_value_;
logic [31:0] rs1_value_;
logic [31:0] rs2_value_;

// Control Unit
logic reg_write_;
logic alu_src_imm_; //operand b 是否選 imm
logic [3:0] alu_op_;
logic valid_inst_; // 是否有這指令

// ID/EX signals
logic [31:0] imm_r;
logic [31:0] rs1_value_r;
logic [31:0] rs2_value_r;

logic reg_write_r;
logic [3:0] alu_op_r;
logic alu_src_imm_r;
logic valid_inst_r;

logic [31:0] operand_b_choose;

logic [31:0] forwarded_rs1_value;
logic [31:0] forwarded_rs2_value;

logic stall_; // 是否要暫停pc、ifid推進
logic keepgoing;
logic bubble;

// ------------------------------------------------------------
// Simple PC next logic
// CH1: no branch / jump yet, so PC simply increments by 4
// ------------------------------------------------------------
assign pc_next_ = pc + 32'd4;

// ------------------------------------------------------------
// CH1: no execute/write-back stage yet
// Temporarily disable register write-back
// ------------------------------------------------------------
// assign write_regf_en_r = 1'b0;
// assign rd_value_       = 32'd0;
assign write_regf_en_r = reg_write_r && valid_inst_r;

assign operand_b_choose = (alu_src_imm_r) ? imm_r : rs2_value_r;

assign keepgoing = ~stall_;
assign bubble = flush_IDEX_ || stall_;

assign stall_ = 1'b0; // temp

// ------------------------------------------------------------
// Controller
// ------------------------------------------------------------
Controller u_Controller (
    .clk          (clk),
    .rst          (rst),
    .flush_IFID_  (flush_IFID_),
    .flush_IDEX_  (flush_IDEX_),
    .rst_pc_      (rst_pc_)
);

// ------------------------------------------------------------
// Program Counter
// ------------------------------------------------------------
PC u_PC (
    .clk       (clk),
    .rst       (rst),
    .rst_pc_   (rst_pc_),
    .pc_next_  (pc_next_),
    .pc_write_en (keepgoing),

    .pc        (pc)
);

// ------------------------------------------------------------
// Program ROM
// ------------------------------------------------------------
Program_ROM u_Program_Rom (
    .rom_addr  (pc),
    .rom_data  (inst_)
);

// ------------------------------------------------------------
// IF/ID pipeline register
// ------------------------------------------------------------
IFID u_IFID (
    .clk          (clk),
    .rst          (rst),
    .flush_IFID_  (flush_IFID_),
    .inst_        (inst_),
    .write_en_    (keepgoing),

    .inst_r       (inst_r)
);

// ------------------------------------------------------------
// Instruction Decoder
// ------------------------------------------------------------
Inst_Decoder u_Inst_Decoder (
    .inst_r     (inst_r),
    .opcode_    (opcode_),
    .addr_rd_   (addr_rd_),
    .funct3_    (funct3_),
    .addr_rs1_  (addr_rs1_),
    .addr_rs2_  (addr_rs2_),
    .funct7_    (funct7_),
    .imm_       (imm_)
);

// ------------------------------------------------------------
// Register File
// ------------------------------------------------------------
Reg_File u_Reg_File (
    .clk              (clk),
    .rst              (rst),
    .write_regf_en_r  (write_regf_en_r),
    .addr_rd_r        (addr_rd_r),
    .rd_value_        (rd_value_),
    .addr_rs1_        (addr_rs1_),
    .addr_rs2_        (addr_rs2_),
    .rs1_value_       (rs1_value_),
    .rs2_value_       (rs2_value_)
);

Control_Unit u_Control_Unit (
    .opcode_      (opcode_),
    .funct3_      (funct3_),
    .funct7_      (funct7_),

    .reg_write_   (reg_write_),
    .alu_src_imm_ (alu_src_imm_),
    .alu_op_      (alu_op_),
    .valid_inst_  (valid_inst_)
);

// ------------------------------------------------------------
// ID/EX pipeline register
// ------------------------------------------------------------
IDEX u_IDEX (
    .clk          (clk),
    .rst          (rst),
    .flush_IDEX_  (bubble),
    .addr_rd_     (addr_rd_),
    .imm_         (imm_),
    .rs1_value_   (forwarded_rs1_value),
    .rs2_value_   (forwarded_rs2_value),
    .addr_rd_r    (addr_rd_r),
    .imm_r        (imm_r),
    .rs1_value_r  (rs1_value_r),
    .rs2_value_r  (rs2_value_r),

    .reg_write_(reg_write_),
    .alu_src_imm_(alu_src_imm_),
    .alu_op_(alu_op_),
    .valid_inst_(valid_inst_),

    .reg_write_r(reg_write_r),
    .alu_src_imm_r(alu_src_imm_r),
    .alu_op_r(alu_op_r),
    .valid_inst_r(valid_inst_r)
    
);

ALU u_ALU (
    .operand_a_ (rs1_value_r),
    .operand_b_ (operand_b_choose),
    .alu_op_    (alu_op_r),

    .result_    (rd_value_)
);

Forwarding_Unit u_Forwarding_Unit (
    .ex_reg_write(write_regf_en_r),
    .ex_rd(addr_rd_r),
    .rd_value_(rd_value_),
    .id_rs1(addr_rs1_),
    .id_rs2(addr_rs2_),
    .rs1_value_(rs1_value_),
    .rs2_value_(rs2_value_),

    .forwarded_rs1_value(forwarded_rs1_value),
    .forwarded_rs2_value(forwarded_rs2_value)
);

endmodule
