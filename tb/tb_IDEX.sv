`timescale 1ns / 100ps
`include "defines.sv"

module tb_IDEX;

    logic        clk;
    logic        rst;
    logic        flush_IDEX_;
    logic [4:0]  addr_rd_;
    logic [31:0] imm_;
    logic [31:0] rs1_value_;
    logic [31:0] rs2_value_;

    logic [4:0]  addr_rd_r;
    logic [31:0] imm_r;
    logic [31:0] rs1_value_r;
    logic [31:0] rs2_value_r;

    logic reg_write_;
    logic [1:0] operand_b_sel_;
    logic [1:0] operand_a_sel_;
    logic [3:0] alu_op_;
    logic valid_inst_;
    logic [31:0] ifid_pc_;
    logic branch_en_;
    logic [2:0] branch_op_;
    logic jump_op_;
    logic [2:0] load_op_;
    logic mem_en;
    logic mem_write;
    logic [2:0] store_op;

    logic reg_write_r;
    logic [1:0] operand_b_sel_r;
    logic [1:0] operand_a_sel_r;
    logic [3:0] alu_op_r;
    logic valid_inst_r;
    logic [31:0] idex_pc_r;
    logic branch_en_r;
    logic [2:0] branch_op_r;
    logic jump_op_r;
    logic [2:0] load_op_r;
    logic mem_en_r;
    logic mem_write_r;
    logic [2:0] store_op_r;

    IDEX u_IDEX (
        .clk          (clk),
        .rst          (rst),
        .flush_IDEX_  (flush_IDEX_),
        .addr_rd_     (addr_rd_),
        .imm_         (imm_),
        .rs1_value_   (rs1_value_),
        .rs2_value_   (rs2_value_),
        .addr_rd_r    (addr_rd_r),
        .imm_r        (imm_r),
        .rs1_value_r  (rs1_value_r),
        .rs2_value_r  (rs2_value_r),

        .reg_write_(reg_write_),
        .operand_b_sel_(operand_b_sel_),
        .operand_a_sel_(operand_a_sel_),
        .alu_op_(alu_op_),
        .valid_inst_(valid_inst_),
        .ifid_pc_(ifid_pc_),
        .branch_en_(branch_en_),
        .branch_op_(branch_op_),
        .jump_op_(jump_op_),
        .load_op_(load_op_),
        .mem_en(mem_en),
        .mem_write(mem_write),
        .store_op(store_op),

        .reg_write_r(reg_write_r),
        .operand_b_sel_r(operand_b_sel_r),
        .operand_a_sel_r(operand_a_sel_r),
        .alu_op_r(alu_op_r),
        .valid_inst_r(valid_inst_r),
        .idex_pc_r(idex_pc_r),
        .branch_en_r(branch_en_r),
        .branch_op_r(branch_op_r),
        .jump_op_r(jump_op_r),
        .load_op_r(load_op_r),
        .mem_en_r(mem_en_r),
        .mem_write_r(mem_write_r),
        .store_op_r(store_op_r)
        
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic check_outputs(
        input logic [4:0]  expected_rd,
        input logic [31:0] expected_imm,
        input logic [31:0] expected_rs1,
        input logic [31:0] expected_rs2,
        input logic        expected_reg_write,
        input logic [1:0]  expected_operand_b_sel,
        input logic [1:0]  expected_operand_a_sel,
        input logic [3:0]  expected_alu_op,
        input logic        expected_valid_inst,
        input logic [31:0] expected_pc,
        input logic        expected_branch_en,
        input logic [2:0]  expected_branch_op,
        input logic        expected_jump_op,
        input logic        expected_mem_en,
        input logic        expected_mem_write,
        input logic [2:0]  expected_store_op,
        input logic [2:0]  expected_load_op,
        input string       test_name
    );
        begin
            if (addr_rd_r !== expected_rd)
                $fatal(1,
                    "[FAIL] %s rd: expected=%0d actual=%0d",
                    test_name, expected_rd, addr_rd_r
                );

            if (imm_r !== expected_imm)
                $fatal(1,
                    "[FAIL] %s imm: expected=%08h actual=%08h",
                    test_name, expected_imm, imm_r
                );

            if (rs1_value_r !== expected_rs1)
                $fatal(1,
                    "[FAIL] %s rs1: expected=%08h actual=%08h",
                    test_name, expected_rs1, rs1_value_r
                );

            if (rs2_value_r !== expected_rs2)
                $fatal(1,
                    "[FAIL] %s rs2: expected=%08h actual=%08h",
                    test_name, expected_rs2, rs2_value_r
                );

            if (reg_write_r !== expected_reg_write)
                $fatal(1,
                    "[FAIL] %s reg_write: expected=%b actual=%b",
                    test_name, expected_reg_write, reg_write_r
                );

            if (operand_b_sel_r !== expected_operand_b_sel)
                $fatal(1,
                    "[FAIL] %s operand_b_sel: expected=%0d actual=%0d",
                    test_name, expected_operand_b_sel, operand_b_sel_r
                );

            if (operand_a_sel_r !== expected_operand_a_sel)
                $fatal(1,
                    "[FAIL] %s operand_a_sel: expected=%0d actual=%0d",
                    test_name, expected_operand_a_sel, operand_a_sel_r
                );

            if (alu_op_r !== expected_alu_op)
                $fatal(1,
                    "[FAIL] %s alu_op: expected=%0d actual=%0d",
                    test_name, expected_alu_op, alu_op_r
                );

            if (valid_inst_r !== expected_valid_inst)
                $fatal(1,
                    "[FAIL] %s valid_inst: expected=%b actual=%b",
                    test_name, expected_valid_inst, valid_inst_r
                );

            if (idex_pc_r !== expected_pc)
                $fatal(1,
                    "[FAIL] %s instruction PC: expected=%08h actual=%08h",
                    test_name, expected_pc, idex_pc_r
                );

            if (branch_en_r !== expected_branch_en)
                $fatal(1,
                    "[FAIL] %s branch_en: expected=%b actual=%b",
                    test_name, expected_branch_en, branch_en_r
                );

            if (branch_op_r !== expected_branch_op)
                $fatal(1,
                    "[FAIL] %s branch_op: expected=%03b actual=%03b",
                    test_name, expected_branch_op, branch_op_r
                );

            if (jump_op_r !== expected_jump_op)
                $fatal(1,
                    "[FAIL] %s jump_op: expected=%b actual=%b",
                    test_name, expected_jump_op, jump_op_r
                );

            if (mem_en_r !== expected_mem_en)
                $fatal(1, "[FAIL] %s mem_en: expected=%b actual=%b",
                       test_name, expected_mem_en, mem_en_r);
            if (mem_write_r !== expected_mem_write)
                $fatal(1, "[FAIL] %s mem_write: expected=%b actual=%b",
                       test_name, expected_mem_write, mem_write_r);
            if (expected_mem_en && store_op_r !== expected_store_op)
                $fatal(1, "[FAIL] %s store_op: expected=%03b actual=%03b",
                       test_name, expected_store_op, store_op_r);
            if (load_op_r !== expected_load_op)
                $fatal(1, "[FAIL] %s load_op: expected=%03b actual=%03b",
                       test_name, expected_load_op, load_op_r);

            $display("[PASS] %s", test_name);
        end
    endtask

    initial begin
        rst         = 1'b1;
        flush_IDEX_ = 1'b0;
        addr_rd_    = 5'd31;
        imm_        = 32'hDEAD_BEEF;
        rs1_value_  = 32'h1111_1111;
        rs2_value_  = 32'h2222_2222;
        reg_write_  = 1'b1;
        operand_b_sel_ = `OP_B_FOUR;
        operand_a_sel_ = `OP_A_PC;
        alu_op_      = `ALUOP_ADD;
        valid_inst_  = 1'b1;
        ifid_pc_     = 32'hDEAD_BEEF;
        branch_en_   = 1'b1;
        branch_op_   = `F3_JAL;
        jump_op_     = 1'b1;
        load_op_     = `F3_LW;
        mem_en       = 1'b1;
        mem_write    = 1'b1;
        store_op     = `F3_SW;

        // Reset 在上升緣將所有輸出清為 0。
        @(posedge clk);
        #1;
        check_outputs(5'd0, 32'd0, 32'd0, 32'd0,
                      1'b0, `OP_B_RS2, `OP_A_RS1, `ALUOP_NOP, 1'b0, 32'd0,
                      1'b0, `F3_BRANCH_NONE, 1'b0,
                      1'b0, 1'b0, `F3_STORE_NONE, 3'd0,
                      "reset clears all outputs");

        // 解除 reset，並在下一個上升緣同時保存四個欄位。
        @(negedge clk);
        rst        = 1'b0;
        addr_rd_   = 5'd7;
        imm_       = 32'hFFFF_FFFB;
        rs1_value_ = 32'h1234_5678;
        rs2_value_ = 32'hCAFE_BABE;
        reg_write_   = 1'b1;
        operand_b_sel_ = `OP_B_FOUR;
        operand_a_sel_ = `OP_A_PC;
        alu_op_      = `ALUOP_ADD;
        valid_inst_  = 1'b1;
        ifid_pc_     = 32'h0000_0100;
        branch_en_   = 1'b1;
        branch_op_   = `F3_JAL;
        jump_op_     = 1'b1;
        load_op_     = `F3_LW;
        mem_en       = 1'b1;
        mem_write    = 1'b1;
        store_op     = `F3_SW;

        @(posedge clk);
        #1;
        check_outputs(5'd7, 32'hFFFF_FFFB,
                      32'h1234_5678, 32'hCAFE_BABE,
                      1'b1, `OP_B_FOUR, `OP_A_PC, `ALUOP_ADD, 1'b1, 32'h0000_0100,
                      1'b1, `F3_JAL, 1'b1,
                      1'b1, 1'b1, `F3_SW, `F3_LW,
                      "rising edge captures all inputs");

        // 在上升緣之間改變輸入，輸出仍應保持舊值。
        @(negedge clk);
        addr_rd_   = 5'd12;
        imm_       = 32'h0000_07FF;
        rs1_value_ = 32'hAAAA_AAAA;
        rs2_value_ = 32'h5555_5555;
        reg_write_   = 1'b0;
        operand_b_sel_ = `OP_B_RS2;
        operand_a_sel_ = `OP_A_ZERO;
        alu_op_      = `ALUOP_SUB;
        valid_inst_  = 1'b0;
        ifid_pc_     = 32'h0000_0104;
        branch_en_   = 1'b0;
        branch_op_   = `F3_BGEU;
        jump_op_     = 1'b0;
        mem_en       = 1'b0;
        mem_write    = 1'b0;
        store_op     = `F3_STORE_NONE;
        load_op_     = `F3_LB;
        #1;
        check_outputs(5'd7, 32'hFFFF_FFFB,
                      32'h1234_5678, 32'hCAFE_BABE,
                      1'b1, `OP_B_FOUR, `OP_A_PC, `ALUOP_ADD, 1'b1, 32'h0000_0100,
                      1'b1, `F3_JAL, 1'b1,
                      1'b1, 1'b1, `F3_SW, `F3_LW,
                      "outputs hold between rising edges");

        // 下一個上升緣才一起更新。
        @(posedge clk);
        #1;
        check_outputs(5'd12, 32'h0000_07FF,
                      32'hAAAA_AAAA, 32'h5555_5555,
                      1'b0, `OP_B_RS2, `OP_A_ZERO, `ALUOP_SUB, 1'b0, 32'h0000_0104,
                      1'b0, `F3_BGEU, 1'b0,
                      1'b0, 1'b0, `F3_STORE_NONE, `F3_LB,
                      "next rising edge updates all outputs");

        // Flush 在上升緣將所有輸出清為 0。
        @(negedge clk);
        flush_IDEX_ = 1'b1;
        addr_rd_    = 5'd20;
        imm_        = 32'h0102_0304;
        rs1_value_  = 32'hABCD_EF01;
        rs2_value_  = 32'h1020_3040;
        reg_write_   = 1'b1;
        operand_b_sel_ = `OP_B_FOUR;
        operand_a_sel_ = `OP_A_PC;
        alu_op_      = `ALUOP_AND;
        valid_inst_  = 1'b1;
        ifid_pc_     = 32'h0000_0200;
        branch_en_   = 1'b1;
        branch_op_   = `F3_JAL;
        jump_op_     = 1'b1;
        mem_en       = 1'b1;
        mem_write    = 1'b1;
        store_op     = `F3_SB;
        load_op_     = `F3_LHU;

        @(posedge clk);
        #1;
        check_outputs(5'd0, 32'd0, 32'd0, 32'd0,
                      1'b0, `OP_B_RS2, `OP_A_RS1, `ALUOP_NOP, 1'b0, 32'd0,
                      1'b0, `F3_BRANCH_NONE, 1'b0,
                      1'b0, 1'b0, `F3_STORE_NONE, 3'd0,
                      "flush clears all outputs");

        // 解除 flush 後恢復正常保存。
        @(negedge clk);
        flush_IDEX_ = 1'b0;
        addr_rd_    = 5'd9;
        imm_        = 32'h0000_002A;
        rs1_value_  = 32'h0BAD_F00D;
        rs2_value_  = 32'h1357_2468;
        reg_write_   = 1'b1;
        operand_b_sel_ = `OP_B_FOUR;
        operand_a_sel_ = `OP_A_PC;
        alu_op_      = `ALUOP_ADD;
        valid_inst_  = 1'b1;
        ifid_pc_     = 32'h0000_0300;
        branch_en_   = 1'b1;
        branch_op_   = `F3_JAL;
        jump_op_     = 1'b1;
        mem_en       = 1'b1;
        mem_write    = 1'b1;
        store_op     = `F3_SH;
        load_op_     = `F3_LBU;

        @(posedge clk);
        #1;
        check_outputs(5'd9, 32'h0000_002A,
                      32'h0BAD_F00D, 32'h1357_2468,
                      1'b1, `OP_B_FOUR, `OP_A_PC, `ALUOP_ADD, 1'b1, 32'h0000_0300,
                      1'b1, `F3_JAL, 1'b1,
                      1'b1, 1'b1, `F3_SH, `F3_LBU,
                      "ID/EX resumes after flush");

        // 第二次 reset 仍能清除所有輸出。
        @(negedge clk);
        rst         = 1'b1;
        addr_rd_    = 5'd30;
        imm_        = 32'hFFFF_FFFF;
        rs1_value_  = 32'hDEAD_BEEF;
        rs2_value_  = 32'hCAFE_BABE;
        reg_write_   = 1'b1;
        operand_b_sel_ = `OP_B_FOUR;
        operand_a_sel_ = `OP_A_ZERO;
        alu_op_      = `ALUOP_XOR;
        valid_inst_  = 1'b1;
        ifid_pc_     = 32'hFFFF_FFFC;
        branch_en_   = 1'b1;
        branch_op_   = `F3_JAL;
        jump_op_     = 1'b1;
        mem_en       = 1'b1;
        mem_write    = 1'b1;
        store_op     = `F3_SW;
        load_op_     = `F3_LH;

        @(posedge clk);
        #1;
        check_outputs(5'd0, 32'd0, 32'd0, 32'd0,
                      1'b0, `OP_B_RS2, `OP_A_RS1, `ALUOP_NOP, 1'b0, 32'd0,
                      1'b0, `F3_BRANCH_NONE, 1'b0,
                      1'b0, 1'b0, `F3_STORE_NONE, 3'd0,
                      "second reset clears all outputs");

        $display("[PASS] tb_IDEX completed.");
        $finish;
    end

endmodule
