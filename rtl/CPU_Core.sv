`include "defines.sv"

module CPU_Core (
    input logic clk,
    input logic rst,

    output logic        imem_req_valid,
    output logic [31:0] imem_req_addr,
    output logic        imem_resp_kill,
    input  logic        imem_resp_valid,
    input  logic [31:0] imem_resp_pc,
    input  logic [31:0] imem_resp_inst,

    output logic        dmem_req_valid,
    output logic        dmem_req_write,
    output logic [3:0]  dmem_req_byte_enable,
    output logic [31:0] dmem_req_addr,
    output logic [31:0] dmem_req_wdata,
    input  logic        dmem_resp_valid,
    input  logic [31:0] dmem_resp_rdata,

    output logic        trap_valid,
    output logic [3:0]  trap_cause,
    output logic [31:0] trap_pc,
    output logic [31:0] trap_tval,
    input  logic        trap_ack,
    input  logic [31:0] trap_redirect_pc,

    output logic        retire_valid,
    output logic [31:0] retire_pc,
    output logic [31:0] retire_inst,
    output logic        retire_rd_write,
    output logic [4:0]  retire_rd,
    output logic [31:0] retire_rd_data,
    output logic        retire_mem_write,
    output logic [31:0] retire_mem_addr,
    output logic [31:0] retire_mem_data,
    output logic [3:0]  retire_mem_byte_enable
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
logic        fetch_response_valid;
logic [31:0] fetch_response_pc;
logic [31:0] fetch_response_inst;
logic        kill_fetch_response;
logic        pc_write_en;

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
logic id_valid_inst;

logic [1:0] operand_a_sel_;

logic branch_en_;
logic [2:0] branch_op_;
logic jump_op_;

logic mem_en;
logic mem_write;
logic [2:0] store_op;

logic [2:0] load_op_;
logic id_uses_rs1;
logic id_uses_rs2;

// ID/EX signals
logic [31:0] imm_r;
logic [31:0] rs1_value_r;
logic [31:0] rs2_value_r;
logic [4:0]  idex_addr_rd_r;
logic [2:0]  idex_load_op_r;

logic idex_reg_write_r;
logic [3:0] alu_op_r;
logic [1:0] operand_b_sel_r;
logic idex_valid_inst_r;

logic [31:0] operand_a_choose;
logic [31:0] operand_b_choose;

logic [31:0] forwarded_rs1_value;
logic [31:0] forwarded_rs2_value;

logic [1:0] operand_a_sel_r;

logic stall_; // 是否要暫停pc、ifid推進
logic load_use_stall;
logic keepgoing;
logic bubble_IDEX;

logic [31:0] idex_pc_r;
logic [31:0] idex_inst_r;

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

// EX/WB signals
logic [31:0] alu_result_;
logic        exwb_reg_write_r;
logic        exwb_valid_inst_r;
logic        exwb_mem_en_r;
logic        exwb_mem_write_r;
logic [2:0]  exwb_load_op_r;
logic        ex_forward_en;
logic [31:0] alu_result_r;
logic [31:0] exwb_pc_r;
logic [31:0] exwb_inst_r;
logic        exwb_store_commit_r;
logic [31:0] exwb_store_data_r;
logic [3:0]  exwb_store_byte_enable_r;

// Load Unit
logic [31:0] load_value;
logic load_misaligned;

// Step 27 interface baseline.  Trap_Unit will replace these safe defaults
// when the pending/ack/redirect behavior is integrated.
assign trap_valid = 1'b0;
assign trap_cause = 4'd0;
assign trap_pc    = 32'd0;
assign trap_tval  = 32'd0;

// Keep the existing datapath names local while the public Core boundary uses
// explicit request/response terminology.
assign fetch_response_valid = imem_resp_valid;
assign fetch_response_pc    = imem_resp_pc;
assign fetch_response_inst  = imem_resp_inst;
assign read_valid           = dmem_resp_valid;
assign read_data            = dmem_resp_rdata;

assign imem_req_valid = keepgoing;
assign imem_req_addr  = pc;
assign imem_resp_kill = kill_fetch_response;

assign dmem_req_valid       = check;
assign dmem_req_write       = mem_write_r;
assign dmem_req_byte_enable = byte_enable;
assign dmem_req_addr        = alu_result_;
assign dmem_req_wdata       = aligned_write_data;

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
assign write_regf_en_r = (exwb_reg_write_r && exwb_valid_inst_r) && (!(exwb_mem_en_r && !exwb_mem_write_r) || (read_valid && !load_misaligned)) ;

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
assign pc_write_en = keepgoing || branch_taken;
assign kill_fetch_response = flush_IFID_ || branch_taken;
assign id_valid_inst = fetch_response_valid && valid_inst_;
assign bubble_IDEX = flush_IDEX_ || stall_ || branch_taken
                   || !fetch_response_valid;

// assign stall_ = 1'b0; // temp
assign stall_ = load_use_stall;

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

assign rd_value_ = (exwb_mem_en_r && !exwb_mem_write_r) ? load_value : alu_result_r;

// A retire event describes the instruction whose architectural effects commit
// at the current write-back edge.  Consumers should sample these signals on
// the rising edge, before EX/WB advances to the following instruction.
assign retire_valid           = exwb_valid_inst_r;
assign retire_pc              = exwb_pc_r;
assign retire_inst            = exwb_inst_r;
assign retire_rd_write        = write_regf_en_r && (addr_rd_r != 5'd0);
assign retire_rd              = addr_rd_r;
assign retire_rd_data         = rd_value_;
assign retire_mem_write       = exwb_store_commit_r;
assign retire_mem_addr        = alu_result_r;
assign retire_mem_data        = exwb_store_data_r;
assign retire_mem_byte_enable = exwb_store_byte_enable_r;

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
    .pc_write_en (pc_write_en),

    .pc        (pc)
);

// ------------------------------------------------------------
// Instruction Decoder
// ------------------------------------------------------------
Inst_Decoder u_Inst_Decoder (
    .inst_r     (fetch_response_inst),
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
    .store_op(store_op),
    .load_op(load_op_),
    .id_uses_rs1(id_uses_rs1),
    .id_uses_rs2(id_uses_rs2)
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
    .inst_        (fetch_response_inst),
    .addr_rd_r    (idex_addr_rd_r),
    .imm_r        (imm_r),
    .rs1_value_r  (rs1_value_r),
    .rs2_value_r  (rs2_value_r),
    .idex_inst_r  (idex_inst_r),

    .reg_write_(reg_write_),
    .operand_b_sel_(operand_b_sel_),
    .alu_op_(alu_op_),
    .valid_inst_(id_valid_inst),

    .reg_write_r(idex_reg_write_r),
    .operand_b_sel_r(operand_b_sel_r),
    .alu_op_r(alu_op_r),
    .valid_inst_r(idex_valid_inst_r),
    
    .operand_a_sel_(operand_a_sel_),
    .operand_a_sel_r(operand_a_sel_r),

    .ifid_pc_(fetch_response_pc),
    .idex_pc_r(idex_pc_r),

    .branch_en_(branch_en_),
    .branch_en_r(branch_en_r),

    .branch_op_(branch_op_),
    .branch_op_r(branch_op_r),

    .jump_op_(jump_op_),
    .jump_op_r(jump_op_r),

    .mem_en(mem_en),
    .mem_write(mem_write),
    .mem_en_r(mem_en_r),
    .mem_write_r(mem_write_r),
    .store_op(store_op),
    .store_op_r(store_op_r),

    .load_op_(load_op_),
    .load_op_r(idex_load_op_r)
);

ALU u_ALU (
    .operand_a_ (operand_a_choose),
    .operand_b_ (operand_b_choose),
    .alu_op_    (alu_op_r),

    .result_    (alu_result_)
);

// A load's EX result is an address rather than its final write-back value.
assign ex_forward_en = idex_reg_write_r && idex_valid_inst_r
                     && !(mem_en_r && !mem_write_r);

Forwarding_Unit u_Forwarding_Unit (
    .ex_reg_write(ex_forward_en),
    .ex_rd(idex_addr_rd_r),
    .rd_value_(alu_result_),
    .wb_reg_write(write_regf_en_r),
    .wb_rd(addr_rd_r),
    .wb_value(rd_value_),
    .id_rs1(addr_rs1_),
    .id_rs2(addr_rs2_),
    .rs1_value_(rs1_value_),
    .rs2_value_(rs2_value_),

    .forwarded_rs1_value(forwarded_rs1_value),
    .forwarded_rs2_value(forwarded_rs2_value)
);

Hazard_Unit u_Hazard_Unit (
    .ex_valid(idex_valid_inst_r),
    .ex_mem_en(mem_en_r),
    .ex_mem_write(mem_write_r),
    .ex_reg_write(idex_reg_write_r),
    .ex_rd(idex_addr_rd_r),

    .id_valid(id_valid_inst),
    .id_uses_rs1(id_uses_rs1),
    .id_uses_rs2(id_uses_rs2),
    .id_rs1(addr_rs1_),
    .id_rs2(addr_rs2_),

    .load_use_stall(load_use_stall)
);

EXWB u_EXWB (
    .clk(clk),
    .rst(rst),
    .alu_result_(alu_result_),
    .addr_rd_(idex_addr_rd_r),
    .reg_write_(idex_reg_write_r),
    .valid_inst_(idex_valid_inst_r),
    .pc_(idex_pc_r),
    .inst_(idex_inst_r),
    .mem_en_(mem_en_r),
    .mem_write_(mem_write_r),
    .load_op_(idex_load_op_r),
    .store_commit_(idex_valid_inst_r && check && mem_write_r),
    .store_data_(aligned_write_data),
    .store_byte_enable_(byte_enable),

    .alu_result_r(alu_result_r),
    .addr_rd_r(addr_rd_r),
    .reg_write_r(exwb_reg_write_r),
    .valid_inst_r(exwb_valid_inst_r),
    .pc_r(exwb_pc_r),
    .inst_r(exwb_inst_r),
    .mem_en_r(exwb_mem_en_r),
    .mem_write_r(exwb_mem_write_r),
    .load_op_r(exwb_load_op_r),
    .store_commit_r(exwb_store_commit_r),
    .store_data_r(exwb_store_data_r),
    .store_byte_enable_r(exwb_store_byte_enable_r)
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
    .address(alu_result_),
    .value(rs2_value_r),

    .byte_enable(byte_enable),
    .aligned_write_data(aligned_write_data),
    .misaligned(misaligned)
);

Load_Unit u_Load_Unit (
    .load_op(exwb_load_op_r),
    .address(alu_result_r),
    .read_data(read_data),

    .load_value(load_value),
    .load_misaligned(load_misaligned)
);

endmodule
