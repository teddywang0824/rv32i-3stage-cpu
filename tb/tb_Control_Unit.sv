`timescale 1ns / 100ps
`include "defines.sv"

module tb_Control_Unit;

    logic [6:0] opcode_;
    logic [2:0] funct3_;
    logic [6:0] funct7_;

    logic       reg_write_;
    logic [1:0] operand_a_sel_;
    logic       alu_src_imm_;
    logic [3:0] alu_op_;
    logic       valid_inst_;
    logic       branch_en_;
    logic [2:0] branch_op_;

    Control_Unit u_Control_Unit (
        .opcode_      (opcode_),
        .funct3_      (funct3_),
        .funct7_      (funct7_),
        .reg_write_   (reg_write_),
        .operand_a_sel_ (operand_a_sel_),
        .alu_src_imm_ (alu_src_imm_),
        .alu_op_      (alu_op_),
        .valid_inst_  (valid_inst_),
        .branch_en_   (branch_en_),
        .branch_op_   (branch_op_)
    );

    task automatic check_control(
        input logic [6:0] test_opcode,
        input logic [2:0] test_funct3,
        input logic [6:0] test_funct7,
        input logic       expected_reg_write,
        input logic       expected_alu_src_imm,
        input logic [3:0] expected_alu_op,
        input logic       expected_valid,
        input string      test_name
    );
        begin
            opcode_ = test_opcode;
            funct3_ = test_funct3;
            funct7_ = test_funct7;
            #1;

            if (reg_write_ !== expected_reg_write)
                $fatal(1, "[FAIL] %s reg_write: expected=%b actual=%b",
                       test_name, expected_reg_write, reg_write_);

            if (alu_src_imm_ !== expected_alu_src_imm)
                $fatal(1, "[FAIL] %s alu_src_imm: expected=%b actual=%b",
                       test_name, expected_alu_src_imm, alu_src_imm_);

            if (alu_op_ !== expected_alu_op)
                $fatal(1, "[FAIL] %s alu_op: expected=%0d actual=%0d",
                       test_name, expected_alu_op, alu_op_);

            if (valid_inst_ !== expected_valid)
                $fatal(1, "[FAIL] %s valid_inst: expected=%b actual=%b",
                       test_name, expected_valid, valid_inst_);

            $display("[PASS] %s", test_name);
        end
    endtask

    task automatic check_branch_control(
        input logic [6:0] test_opcode,
        input logic [2:0] test_funct3,
        input logic       expected_reg_write,
        input logic       expected_alu_src_imm,
        input logic [3:0] expected_alu_op,
        input logic       expected_valid,
        input logic       expected_branch_en,
        input logic [2:0] expected_branch_op,
        input string      test_name
    );
        begin
            opcode_ = test_opcode;
            funct3_ = test_funct3;
            funct7_ = 7'b0;
            #1;

            if (reg_write_ !== expected_reg_write)
                $fatal(1, "[FAIL] %s reg_write: expected=%b actual=%b",
                       test_name, expected_reg_write, reg_write_);

            if (alu_src_imm_ !== expected_alu_src_imm)
                $fatal(1, "[FAIL] %s alu_src_imm: expected=%b actual=%b",
                       test_name, expected_alu_src_imm, alu_src_imm_);

            if (alu_op_ !== expected_alu_op)
                $fatal(1, "[FAIL] %s alu_op: expected=%0d actual=%0d",
                       test_name, expected_alu_op, alu_op_);

            if (valid_inst_ !== expected_valid)
                $fatal(1, "[FAIL] %s valid_inst: expected=%b actual=%b",
                       test_name, expected_valid, valid_inst_);

            if (branch_en_ !== expected_branch_en)
                $fatal(1, "[FAIL] %s branch_en: expected=%b actual=%b",
                       test_name, expected_branch_en, branch_en_);

            if (branch_op_ !== expected_branch_op)
                $fatal(1, "[FAIL] %s branch_op: expected=%03b actual=%03b",
                       test_name, expected_branch_op, branch_op_);

            $display("[PASS] %s", test_name);
        end
    endtask

    task automatic check_operand_a_sel(
        input logic [6:0] test_opcode,
        input logic [2:0] test_funct3,
        input logic [6:0] test_funct7,
        input logic [1:0] expected_operand_a_sel,
        input string      test_name
    );
        begin
            opcode_ = test_opcode;
            funct3_ = test_funct3;
            funct7_ = test_funct7;
            #1;

            if (operand_a_sel_ !== expected_operand_a_sel)
                $fatal(1, "[FAIL] %s operand_a_sel: expected=%0d actual=%0d",
                       test_name, expected_operand_a_sel, operand_a_sel_);

            $display("[PASS] %s", test_name);
        end
    endtask

    initial begin
        // I-type 的 funct7_ 實際上是 immediate 的一部分；
        // 以下非 shift-immediate 指令不應依賴它來解碼。
        check_control(
            `Opcode_I, `F_ADDI, 7'b101_0101,
            1'b1, 1'b1, `ALUOP_ADD, 1'b1,
            "ADDI produces valid ADD controls"
        );

        // 已支援的 ANDI 使用 immediate，並要求 ALU 執行 AND。
        check_control(
            `Opcode_I, `F_ANDI, 7'b011_0101,
            1'b1, 1'b1, `ALUOP_AND, 1'b1,
            "ANDI produces valid AND controls"
        );

        // SLTI 使用有號比較。
        check_control(
            `Opcode_I, `F_SLTI, 7'b111_1111,
            1'b1, 1'b1, `ALUOP_LT, 1'b1,
            "SLTI produces signed-less-than controls"
        );

        // SLTIU 使用無號比較。
        check_control(
            `Opcode_I, `F_SLTIU, 7'b000_0000,
            1'b1, 1'b1, `ALUOP_LTU, 1'b1,
            "SLTIU produces unsigned-less-than controls"
        );

        // XORI 與 ORI 不限制 funct7，因為高位屬於 immediate。
        check_control(
            `Opcode_I, `F_XORI, 7'b101_1010,
            1'b1, 1'b1, `ALUOP_XOR, 1'b1,
            "XORI produces valid XOR controls"
        );

        check_control(
            `Opcode_I, `F_ORI, 7'b010_1101,
            1'b1, 1'b1, `ALUOP_OR, 1'b1,
            "ORI produces valid OR controls"
        );

        // Shift-immediate 指令必須同時檢查 funct3 與合法 funct7。
        check_control(
            `Opcode_I, `F_SLLI, `F7_SLLI,
            1'b1, 1'b1, `ALUOP_SLL, 1'b1,
            "SLLI produces valid logical-left-shift controls"
        );

        check_control(
            `Opcode_I, `F_SRLI_SRAI, `F7_SRLI,
            1'b1, 1'b1, `ALUOP_SRL, 1'b1,
            "SRLI produces valid logical-right-shift controls"
        );

        check_control(
            `Opcode_I, `F_SRLI_SRAI, `F7_SRAI,
            1'b1, 1'b1, `ALUOP_SRA, 1'b1,
            "SRAI produces valid arithmetic-right-shift controls"
        );

        // SLLI 搭配非法 funct7 時不可寫回。
        check_control(
            `Opcode_I, `F_SLLI, 7'b000_0001,
            1'b0, 1'b0, `ALUOP_NOP, 1'b0,
            "illegal SLLI funct7 uses safe defaults"
        );

        // funct3=101 但不是 SRLI/SRAI 的 funct7 時不可寫回。
        check_control(
            `Opcode_I, `F_SRLI_SRAI, 7'b001_0000,
            1'b0, 1'b0, `ALUOP_NOP, 1'b0,
            "illegal SRLI/SRAI funct7 uses safe defaults"
        );

        // 所有合法 RV32I R-type 都使用 rs2，alu_src_imm 必須為 0。
        check_control(
            `Opcode_R_M, `F_ADD_SUB, `F7_ADD,
            1'b1, 1'b0, `ALUOP_ADD, 1'b1,
            "R-type ADD produces valid controls"
        );

        check_control(
            `Opcode_R_M, `F_ADD_SUB, `F7_SUB,
            1'b1, 1'b0, `ALUOP_SUB, 1'b1,
            "R-type SUB produces valid controls"
        );

        check_control(
            `Opcode_R_M, `F_SLL, `F7_OPCODE_R,
            1'b1, 1'b0, `ALUOP_SLL, 1'b1,
            "R-type SLL produces valid controls"
        );

        check_control(
            `Opcode_R_M, `F_SLT, `F7_OPCODE_R,
            1'b1, 1'b0, `ALUOP_LT, 1'b1,
            "R-type SLT produces valid controls"
        );

        check_control(
            `Opcode_R_M, `F_SLTU, `F7_OPCODE_R,
            1'b1, 1'b0, `ALUOP_LTU, 1'b1,
            "R-type SLTU produces valid controls"
        );

        check_control(
            `Opcode_R_M, `F_XOR, `F7_OPCODE_R,
            1'b1, 1'b0, `ALUOP_XOR, 1'b1,
            "R-type XOR produces valid controls"
        );

        check_control(
            `Opcode_R_M, `F_SR, `F7_SRLI,
            1'b1, 1'b0, `ALUOP_SRL, 1'b1,
            "R-type SRL produces valid controls"
        );

        check_control(
            `Opcode_R_M, `F_SR, `F7_SRAI,
            1'b1, 1'b0, `ALUOP_SRA, 1'b1,
            "R-type SRA produces valid controls"
        );

        check_control(
            `Opcode_R_M, `F_OR, `F7_OPCODE_R,
            1'b1, 1'b0, `ALUOP_OR, 1'b1,
            "R-type OR produces valid controls"
        );

        check_control(
            `Opcode_R_M, `F_AND, `F7_OPCODE_R,
            1'b1, 1'b0, `ALUOP_AND, 1'b1,
            "R-type AND produces valid controls"
        );

        // 三類非法 funct7 都必須維持安全預設值。
        check_control(
            `Opcode_R_M, `F_ADD_SUB, 7'b000_0001,
            1'b0, 1'b0, `ALUOP_NOP, 1'b0,
            "illegal R-type ADD/SUB funct7 uses safe defaults"
        );

        check_control(
            `Opcode_R_M, `F_SR, 7'b000_0001,
            1'b0, 1'b0, `ALUOP_NOP, 1'b0,
            "illegal R-type SRL/SRA funct7 uses safe defaults"
        );

        check_control(
            `Opcode_R_M, `F_AND, `F7_SUB,
            1'b0, 1'b0, `ALUOP_NOP, 1'b0,
            "illegal general R-type funct7 uses safe defaults"
        );

        // 模擬未知 funct3 時也不得產生副作用。
        check_control(
            `Opcode_R_M, 3'bxxx, `F7_OPCODE_R,
            1'b0, 1'b0, `ALUOP_NOP, 1'b0,
            "unknown R-type funct3 uses safe defaults"
        );

        // 現有 I/R-type 的 operand A 都應來自 rs1。
        check_operand_a_sel(
            `Opcode_I, `F_ADDI, 7'b101_0101,
            `OP_A_RS1,
            "I-type selects rs1 as operand A"
        );

        check_operand_a_sel(
            `Opcode_R_M, `F_ADD_SUB, `F7_ADD,
            `OP_A_RS1,
            "R-type selects rs1 as operand A"
        );

        // LUI 使用 0 + U-immediate。
        check_control(
            `Opcode_LUI, 3'b101, 7'b101_0101,
            1'b1, 1'b1, `ALUOP_ADD, 1'b1,
            "LUI produces valid immediate ADD controls"
        );

        check_operand_a_sel(
            `Opcode_LUI, 3'b101, 7'b101_0101,
            `OP_A_ZERO,
            "LUI selects zero as operand A"
        );

        // AUIPC 使用該指令的 PC + U-immediate。
        check_control(
            `Opcode_AUIPC, 3'b010, 7'b010_1010,
            1'b1, 1'b1, `ALUOP_ADD, 1'b1,
            "AUIPC produces valid immediate ADD controls"
        );

        check_operand_a_sel(
            `Opcode_AUIPC, 3'b010, 7'b010_1010,
            `OP_A_PC,
            "AUIPC selects PC as operand A"
        );

        // 六種合法 branch 必須保留 funct3 作為 branch operation，且不得寫回。
        check_branch_control(`Opcode_BRANCH, `F3_BEQ,
            1'b0, 1'b0, `ALUOP_NOP, 1'b1, 1'b1, `F3_BEQ,
            "BEQ produces valid branch controls");
        check_branch_control(`Opcode_BRANCH, `F3_BNE,
            1'b0, 1'b0, `ALUOP_NOP, 1'b1, 1'b1, `F3_BNE,
            "BNE produces valid branch controls");
        check_branch_control(`Opcode_BRANCH, `F3_BLT,
            1'b0, 1'b0, `ALUOP_NOP, 1'b1, 1'b1, `F3_BLT,
            "BLT produces valid branch controls");
        check_branch_control(`Opcode_BRANCH, `F3_BGE,
            1'b0, 1'b0, `ALUOP_NOP, 1'b1, 1'b1, `F3_BGE,
            "BGE produces valid branch controls");
        check_branch_control(`Opcode_BRANCH, `F3_BLTU,
            1'b0, 1'b0, `ALUOP_NOP, 1'b1, 1'b1, `F3_BLTU,
            "BLTU produces valid branch controls");
        check_branch_control(`Opcode_BRANCH, `F3_BGEU,
            1'b0, 1'b0, `ALUOP_NOP, 1'b1, 1'b1, `F3_BGEU,
            "BGEU produces valid branch controls");

        // 010、011 是保留的 branch funct3，必須維持安全值。
        check_branch_control(`Opcode_BRANCH, 3'b010,
            1'b0, 1'b0, `ALUOP_NOP, 1'b0, 1'b0, `F3_BRANCH_NONE,
            "reserved branch funct3 010 uses safe defaults");
        check_branch_control(`Opcode_BRANCH, 3'b011,
            1'b0, 1'b0, `ALUOP_NOP, 1'b0, 1'b0, `F3_BRANCH_NONE,
            "reserved branch funct3 011 uses safe defaults");

        // 非 branch 指令不得殘留 branch enable 或 operation。
        check_branch_control(`Opcode_I, `F_ADDI,
            1'b1, 1'b1, `ALUOP_ADD, 1'b1, 1'b0, `F3_BRANCH_NONE,
            "ADDI keeps branch controls disabled");

        // 未知 opcode 必須保持安全輸出。
        check_control(
            7'b111_1111, 3'b111, 7'b111_1111,
            1'b0, 1'b0, `ALUOP_NOP, 1'b0,
            "unknown opcode uses safe defaults"
        );

        check_operand_a_sel(
            7'b111_1111, 3'b111, 7'b111_1111,
            `OP_A_ZERO,
            "unknown opcode selects safe operand A default"
        );

        // 從合法 ADDI 切換到非法 SLLI，確認沒有殘留控制訊號或 latch。
        check_control(
            `Opcode_I, `F_ADDI, 7'b000_0000,
            1'b1, 1'b1, `ALUOP_ADD, 1'b1,
            "ADDI before transition"
        );

        check_control(
            `Opcode_I, `F_SLLI, 7'b111_1111,
            1'b0, 1'b0, `ALUOP_NOP, 1'b0,
            "valid-to-invalid transition clears controls"
        );

        $display("[PASS] tb_Control_Unit completed.");
        $finish;
    end

endmodule
