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
logic [1:0] operand_b_sel_; //operand b 是否選 imm
logic [3:0] alu_op_;
logic valid_inst_; // 是否有這指令

logic [1:0] operand_a_sel_;

logic branch_en_;
logic [2:0] branch_op_;
logic jump_op_;

logic mem_en;
logic mem_write;
logic [2:0] store_op;

// ID/EX signals
logic [31:0] imm_r;
logic [31:0] rs1_value_r;
logic [31:0] rs2_value_r;

logic reg_write_r;
logic [3:0] alu_op_r;
logic [1:0] operand_b_sel_r;
logic valid_inst_r;

logic [31:0] operand_a_choose;
logic [31:0] operand_b_choose;

logic [31:0] forwarded_rs1_value;
logic [31:0] forwarded_rs2_value;

logic [1:0] operand_a_sel_r;

logic stall_; // 是否要暫停pc、ifid推進
logic keepgoing;
logic bubble_IDEX;
logic bubble_IFID;

logic [31:0] ifid_pc_r;
logic [31:0] idex_pc_r;

logic branch_en_r;
logic [2:0] branch_op_r;
logic jump_op_r;

logic mem_en_r;
logic mem_write_r;
logic [2:0] store_op_r;

// Branch Unit
logic branch_taken;
logic [31:0] branch_target;

// Store Unit
logic [3:0] byte_enable;
logic [31:0] aligned_write_data;
logic misaligned;

// Data Mem
logic [31:0] read_data;
logic read_valid;
logic check;

// ------------------------------------------------------------
// Simple PC next logic
// CH1: no branch / jump yet, so PC simply increments by 4
// ------------------------------------------------------------
assign pc_next_ = branch_taken ? branch_target : pc + 32'd4;

// ------------------------------------------------------------
// CH1: no execute/write-back stage yet
// Temporarily disable register write-back
// ------------------------------------------------------------
// assign write_regf_en_r = 1'b0;
// assign rd_value_       = 32'd0;
assign write_regf_en_r = reg_write_r && valid_inst_r;

// assign operand_b_choose = (operand_b_sel_r) ? imm_r : rs2_value_r;
always_comb begin
    operand_b_choose = 32'b0;

    case (operand_b_sel_r)
        `OP_B_RS2:  operand_b_choose = rs2_value_r;
        `OP_B_IMM: operand_b_choose = imm_r;
        `OP_B_FOUR:   operand_b_choose = 32'd4;
        default:    operand_b_choose = 32'b0;
    endcase
end


assign keepgoing = ~stall_;
assign bubble_IDEX = flush_IDEX_ || stall_ || branch_taken;
assign bubble_IFID = flush_IFID_ || branch_taken;

assign stall_ = 1'b0; // temp

always_comb begin
    operand_a_choose = 32'b0;

    case (operand_a_sel_r)
        `OP_A_RS1:  operand_a_choose = rs1_value_r;
        `OP_A_ZERO: operand_a_choose = 32'b0;
        `OP_A_PC:   operand_a_choose = idex_pc_r;
        default:    operand_a_choose = 32'b0;
    endcase
end

assign check = mem_en_r && !misaligned;

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
    .flush_IFID_  (bubble_IFID),
    .inst_        (inst_),
    .write_en_    (keepgoing),
    .pc_(pc),

    .inst_r       (inst_r),
    .pc_r(ifid_pc_r)
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
    .operand_b_sel_ (operand_b_sel_),
    .operand_a_sel_(operand_a_sel_),
    .alu_op_      (alu_op_),
    .valid_inst_  (valid_inst_),
    .branch_en_(branch_en_),
    .branch_op_(branch_op_),
    .jump_op_(jump_op_),
    .mem_en(mem_en),
    .mem_write(mem_write),
    .store_op(store_op)
);

// ------------------------------------------------------------
// ID/EX pipeline register
// ------------------------------------------------------------
IDEX u_IDEX (
    .clk          (clk),
    .rst          (rst),
    .flush_IDEX_  (bubble_IDEX),
    .addr_rd_     (addr_rd_),
    .imm_         (imm_),
    .rs1_value_   (forwarded_rs1_value),
    .rs2_value_   (forwarded_rs2_value),
    .addr_rd_r    (addr_rd_r),
    .imm_r        (imm_r),
    .rs1_value_r  (rs1_value_r),
    .rs2_value_r  (rs2_value_r),

    .reg_write_(reg_write_),
    .operand_b_sel_(operand_b_sel_),
    .alu_op_(alu_op_),
    .valid_inst_(valid_inst_),

    .reg_write_r(reg_write_r),
    .operand_b_sel_r(operand_b_sel_r),
    .alu_op_r(alu_op_r),
    .valid_inst_r(valid_inst_r),
    
    .operand_a_sel_(operand_a_sel_),
    .operand_a_sel_r(operand_a_sel_r),

    .ifid_pc_(ifid_pc_r),
    .idex_pc_r(idex_pc_r),

    .branch_en_(branch_en_),
    .branch_en_r(branch_en_r),

    .branch_op_(branch_op_),
    .branch_op_r(branch_op_r),

    .jump_op_(jump_op_),
    .jump_op_r(jump_op_r),

    .mem_en(mem_en),
    .mem_write(mem_write),
    .store_op(store_op),
    .mem_en_r(mem_en_r),
    .mem_write_r(mem_write_r),
    .store_op_r(store_op_r)
);

ALU u_ALU (
    .operand_a_ (operand_a_choose),
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

Branch_Unit u_Branch_Unit (
    .rs1_value_(rs1_value_r),
    .rs2_value_(rs2_value_r),
    .imm_(imm_r),
    .branch_en_(branch_en_r),
    .branch_op_(branch_op_r),
    .jump_op_(jump_op_r),
    .pc_(idex_pc_r),

    .branch_taken(branch_taken),
    .branch_target(branch_target)
);

Store_Unit u_Store_Unit (
    .store_op(store_op_r),
    .address(rd_value_),
    .value(rs2_value_r),

    .byte_enable(byte_enable),
    .aligned_write_data(aligned_write_data),
    .misaligned(misaligned)
);

Data_Memory u_Data_Memory (
    .clk(clk),
    .mem_en(check),
    .mem_write(mem_write_r),
    .byte_enable(byte_enable),
    .address(rd_value_),
    .write_data(aligned_write_data),

    .read_data(read_data),
    .read_valid(read_valid)
);

endmodule
