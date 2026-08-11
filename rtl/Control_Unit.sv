`include "defines.sv"

module Control_Unit (
    input logic [6:0] opcode_,
    input logic [2:0] funct3_,
    input logic [6:0] funct7_,

    output logic reg_write_,
    output logic [1:0] operand_a_sel_,
    output logic [1:0] operand_b_sel_, //operand b 是否選 imm
    output logic [3:0] alu_op_,
    output logic valid_inst_, // 是否有這指令

    output logic branch_en_,
    output logic [2:0] branch_op_,
    output logic jump_op_,

    output logic mem_en,
    output logic mem_write,
    output logic [2:0] store_op,
    output logic [2:0] load_op,

    output logic id_uses_rs1,
    output logic id_uses_rs2
);

always_comb begin
    reg_write_ = 0;
    operand_a_sel_ = `OP_A_RS1;
    operand_b_sel_ = `OP_B_RS2;
    alu_op_ = `ALUOP_NOP;
    valid_inst_ = 0;

    branch_en_ = 1'b0;
    branch_op_ = `F3_BRANCH_NONE;
    jump_op_ = 0;

    mem_en = 0;
    mem_write = 0;
    store_op = `F3_STORE_NONE;

    load_op = `F3_LOAD_NONE;

    id_uses_rs1 = 1'b0;
    id_uses_rs2 = 1'b0;

    case (opcode_)
        `Opcode_I :  begin
            case (funct3_)
                `F_ADDI : begin
                    reg_write_ = 1;
                    operand_b_sel_ = 1;
                    alu_op_ = `ALUOP_ADD;
                    valid_inst_ = 1'b1;
                end 
                `F_SLTI : begin
                    reg_write_ = 1;
                    operand_b_sel_ = 1;
                    alu_op_ = `ALUOP_LT;
                    valid_inst_ = 1'b1;
                end
                `F_SLTIU : begin
                    reg_write_ = 1;
                    operand_b_sel_ = 1;
                    alu_op_ = `ALUOP_LTU;
                    valid_inst_ = 1'b1;
                end
                `F_ANDI : begin
                    reg_write_ = 1;
                    operand_b_sel_ = 1;
                    alu_op_ = `ALUOP_AND;
                    valid_inst_ = 1'b1;
                end
                `F_XORI : begin
                    reg_write_ = 1;
                    operand_b_sel_ = 1;
                    alu_op_ = `ALUOP_XOR;
                    valid_inst_ = 1'b1;
                end
                `F_ORI : begin
                    reg_write_ = 1;
                    operand_b_sel_ = 1;
                    alu_op_ = `ALUOP_OR;
                    valid_inst_ = 1'b1;
                end
                `F_SLLI : begin
                    if (funct7_ == `F7_SLLI) begin
                        reg_write_ = 1;
                        operand_b_sel_ = 1;
                        alu_op_ = `ALUOP_SLL;
                        valid_inst_ = 1'b1;
                    end else begin
                        reg_write_ = 0;
                        operand_b_sel_ = 0;
                        alu_op_ = `ALUOP_NOP;
                        valid_inst_ = 0;
                    end
                end
                `F_SRLI_SRAI : begin
                    case (funct7_)
                        `F7_SRLI : begin
                            reg_write_ = 1;
                            operand_b_sel_ = 1;
                            alu_op_ = `ALUOP_SRL;
                            valid_inst_ = 1'b1;
                        end
                        `F7_SRAI : begin
                            reg_write_ = 1;
                            operand_b_sel_ = 1;
                            alu_op_ = `ALUOP_SRA;
                            valid_inst_ = 1'b1;
                        end
                        default: begin
                            reg_write_ = 0;
                            operand_b_sel_ = 0;
                            alu_op_ = `ALUOP_NOP;
                            valid_inst_ = 0;
                        end
                    endcase
                    
                end
                default: begin
                    reg_write_ = 0;
                    operand_b_sel_ = 0;
                    alu_op_ = `ALUOP_NOP;
                    valid_inst_ = 0;
                end
            endcase

            operand_a_sel_ = `OP_A_RS1;
        end
        `Opcode_R_M: begin
            // operand_b_sel_ 保持 0。
            case (funct3_)
                `F_ADD_SUB: begin
                    case (funct7_)
                        `F7_ADD: begin
                            alu_op_ = `ALUOP_ADD;
                            valid_inst_ = 1'b1;
                        end
                        `F7_SUB: begin
                            alu_op_ = `ALUOP_SUB;
                            valid_inst_ = 1'b1;
                        end
                        default: begin
                        end
                    endcase
                end

                `F_SLL: begin
                    if (funct7_ == `F7_OPCODE_R) begin
                        alu_op_ = `ALUOP_SLL;
                        valid_inst_ = 1'b1;
                    end
                end

                `F_SLT: begin
                    if (funct7_ == `F7_OPCODE_R) begin
                        alu_op_ = `ALUOP_LT;
                        valid_inst_ = 1'b1;
                    end
                end

                `F_SLTU: begin
                    if (funct7_ == `F7_OPCODE_R) begin
                        alu_op_ = `ALUOP_LTU;
                        valid_inst_ = 1'b1;
                    end
                end

                `F_XOR: begin
                    if (funct7_ == `F7_OPCODE_R) begin
                        alu_op_ = `ALUOP_XOR;
                        valid_inst_ = 1'b1;
                    end
                end

                `F_SR: begin
                    case (funct7_)
                        `F7_SRLI: begin
                            alu_op_ = `ALUOP_SRL;
                            valid_inst_ = 1'b1;
                        end
                        `F7_SRAI: begin
                            alu_op_ = `ALUOP_SRA;
                            valid_inst_ = 1'b1;
                        end
                        default: begin
                        end
                    endcase
                end

                `F_OR: begin
                    if (funct7_ == `F7_OPCODE_R) begin
                        alu_op_ = `ALUOP_OR;
                        valid_inst_ = 1'b1;
                    end
                end

                `F_AND: begin
                    if (funct7_ == `F7_OPCODE_R) begin
                        alu_op_ = `ALUOP_AND;
                        valid_inst_ = 1'b1;
                    end
                end

                default: begin
                end
            endcase

            // 只有上方辨識為合法 R-type 時才允許寫回。
            if (valid_inst_) begin
                reg_write_ = 1'b1;
            end
            operand_a_sel_ = `OP_A_RS1;
        end
        `Opcode_LUI: begin
            reg_write_      = 1'b1;
            operand_a_sel_  = `OP_A_ZERO;
            operand_b_sel_    = 1;
            alu_op_         = `ALUOP_ADD;
            valid_inst_     = 1;
        end
        `Opcode_AUIPC: begin
            reg_write_      = 1'b1;
            operand_a_sel_  = `OP_A_PC;
            operand_b_sel_    = 1;
            alu_op_         = `ALUOP_ADD;
            valid_inst_     = 1;
        end
        `Opcode_BRANCH: begin
            reg_write_      = 1'b0;
            operand_a_sel_  = `OP_A_ZERO;
            operand_b_sel_    = 0;
            alu_op_         = `ALUOP_NOP;
            jump_op_ = 0;

            if (funct3_ != 3'b010 && funct3_ != 3'b011) begin
                branch_en_ = 1'b1;
                valid_inst_ = 1;
                branch_op_ = funct3_;
            end else begin
                branch_en_ = 1'b0;
                valid_inst_ = 0;
                branch_op_ = `F3_BRANCH_NONE;
            end
        end
        `Opcode_JAL : begin
            reg_write_      = 1'b1;
            operand_a_sel_  = `OP_A_PC;
            operand_b_sel_    = `OP_B_FOUR;
            alu_op_         = `ALUOP_ADD;
            valid_inst_ = 1;
            branch_en_ = 1;
            branch_op_ = `F3_JAL;
            jump_op_ = 1;
        end
        `Opcode_JALR : begin
            if (funct3_ == `F3_JALR) begin
                operand_a_sel_  = `OP_A_PC;
                operand_b_sel_    = `OP_B_FOUR;
                alu_op_         = `ALUOP_ADD;   
                reg_write_      = 1'b1;
                valid_inst_ = 1;
                branch_en_ = 1;
                branch_op_ = `F3_JALR;
                jump_op_ = 1;
            end else begin
                operand_a_sel_  = `OP_A_ZERO;
                operand_b_sel_    = `OP_B_RS2;
                alu_op_         = `ALUOP_NOP; 
                reg_write_      = 1'b0;
                valid_inst_ = 0;
                branch_en_ = 0;
                branch_op_ = `F3_BRANCH_NONE ;
                jump_op_ = 0;
            end
        end
        `Opcode_STORE : begin
            case (funct3_)
                `F3_SB, `F3_SH, `F3_SW: begin
                    operand_a_sel_ = `OP_A_RS1;
                    operand_b_sel_ = `OP_B_IMM;
                    alu_op_ = `ALUOP_ADD;
                    valid_inst_ = 1;
                    reg_write_ = 0;
                    mem_en = 1;
                    mem_write = 1;
                    store_op = funct3_;
                end
                default: begin
                    valid_inst_ = 0;
                    mem_en = 0;
                end
            endcase
        end
        `Opcode_LOAD : begin
            case (funct3_)
                `F3_LB, `F3_LH,`F3_LW, `F3_LBU, `F3_LHU: begin
                    operand_a_sel_ = `OP_A_RS1;
                    operand_b_sel_ = `OP_B_IMM;
                    alu_op_ = `ALUOP_ADD;
                    valid_inst_ = 1;
                    reg_write_ = 1;
                    mem_en = 1;
                    mem_write = 0;
                    load_op = funct3_;
                end
                default: begin
                    valid_inst_ = 0;
                    mem_en = 0;
                end
            endcase
        end
        default: begin
            reg_write_ = 0;
            operand_b_sel_ = 0;
            operand_a_sel_  = `OP_A_ZERO;
            alu_op_ = `ALUOP_NOP;
            valid_inst_ = 0;
        end
    endcase

    // Source-register usage belongs to the decoded instruction in ID.
    // Only legal instructions may claim a source, preventing false hazards
    // from immediate bits that overlap the encoded rs1/rs2 fields.
    if (valid_inst_) begin
        case (opcode_)
            `Opcode_I, `Opcode_LOAD, `Opcode_JALR: begin
                id_uses_rs1 = 1'b1;
            end

            `Opcode_R_M, `Opcode_STORE, `Opcode_BRANCH: begin
                id_uses_rs1 = 1'b1;
                id_uses_rs2 = 1'b1;
            end

            default: begin
                id_uses_rs1 = 1'b0;
                id_uses_rs2 = 1'b0;
            end
        endcase
    end
end
    
endmodule
