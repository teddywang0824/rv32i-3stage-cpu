`timescale 1ns / 100ps
`include "defines.sv"

module tb_Branch_Unit;

    logic [31:0] rs1_value_;
    logic [31:0] rs2_value_;
    logic [31:0] imm_;
    logic        branch_en_;
    logic [2:0]  branch_op_;
    logic [31:0] pc_;

    logic        branch_taken;
    logic [31:0] branch_target;

    Branch_Unit u_Branch_Unit (
        .rs1_value_  (rs1_value_),
        .rs2_value_  (rs2_value_),
        .imm_        (imm_),
        .branch_en_  (branch_en_),
        .branch_op_  (branch_op_),
        .pc_         (pc_),
        .branch_taken(branch_taken),
        .branch_target(branch_target)
    );

    task automatic check_branch(
        input logic        test_branch_en,
        input logic [2:0]  test_branch_op,
        input logic [31:0] test_rs1,
        input logic [31:0] test_rs2,
        input logic [31:0] test_pc,
        input logic [31:0] test_imm,
        input logic        expected_taken,
        input logic [31:0] expected_target,
        input string       test_name
    );
        begin
            branch_en_ = test_branch_en;
            branch_op_ = test_branch_op;
            rs1_value_ = test_rs1;
            rs2_value_ = test_rs2;
            pc_        = test_pc;
            imm_       = test_imm;
            #1;

            if (branch_taken !== expected_taken) begin
                $fatal(1,
                    "[FAIL] %s taken: expected=%b actual=%b",
                    test_name, expected_taken, branch_taken
                );
            end

            if (branch_target !== expected_target) begin
                $fatal(1,
                    "[FAIL] %s target: expected=0x%08h actual=0x%08h",
                    test_name, expected_target, branch_target
                );
            end

            $display("[PASS] %s", test_name);
        end
    endtask

    initial begin
        // Equality branches.
        check_branch(1'b1, `F3_BEQ, 32'd7, 32'd7,
                     32'h0000_0100, 32'h0000_0010,
                     1'b1, 32'h0000_0110, "BEQ taken when operands are equal");
        check_branch(1'b1, `F3_BEQ, 32'd7, 32'd8,
                     32'h0000_0100, 32'h0000_0010,
                     1'b0, 32'h0000_0110, "BEQ not taken when operands differ");
        check_branch(1'b1, `F3_BNE, 32'd7, 32'd8,
                     32'h0000_0100, 32'hFFFF_FFF0,
                     1'b1, 32'h0000_00F0, "BNE taken and negative target offset");
        check_branch(1'b1, `F3_BNE, 32'd7, 32'd7,
                     32'h0000_0100, 32'h0000_0010,
                     1'b0, 32'h0000_0110, "BNE not taken when operands are equal");

        // Signed comparisons: 0xFFFF_FFFF is -1.
        check_branch(1'b1, `F3_BLT, 32'hFFFF_FFFF, 32'd1,
                     32'h0000_0200, 32'h0000_0020,
                     1'b1, 32'h0000_0220, "BLT uses signed comparison");
        check_branch(1'b1, `F3_BLT, 32'd1, 32'hFFFF_FFFF,
                     32'h0000_0200, 32'h0000_0020,
                     1'b0, 32'h0000_0220, "BLT signed not-taken case");
        check_branch(1'b1, `F3_BGE, 32'hFFFF_FFFF, 32'd1,
                     32'h0000_0200, 32'h0000_0020,
                     1'b0, 32'h0000_0220, "BGE uses signed comparison");
        check_branch(1'b1, `F3_BGE, 32'd1, 32'hFFFF_FFFF,
                     32'h0000_0200, 32'h0000_0020,
                     1'b1, 32'h0000_0220, "BGE signed taken case");

        // Unsigned comparisons: 0xFFFF_FFFF is the largest unsigned value.
        check_branch(1'b1, `F3_BLTU, 32'd1, 32'hFFFF_FFFF,
                     32'h0000_0300, 32'h0000_0040,
                     1'b1, 32'h0000_0340, "BLTU uses unsigned comparison");
        check_branch(1'b1, `F3_BLTU, 32'hFFFF_FFFF, 32'd1,
                     32'h0000_0300, 32'h0000_0040,
                     1'b0, 32'h0000_0340, "BLTU unsigned not-taken case");
        check_branch(1'b1, `F3_BGEU, 32'hFFFF_FFFF, 32'd1,
                     32'h0000_0300, 32'h0000_0040,
                     1'b1, 32'h0000_0340, "BGEU uses unsigned comparison");
        check_branch(1'b1, `F3_BGEU, 32'd1, 32'hFFFF_FFFF,
                     32'h0000_0300, 32'h0000_0040,
                     1'b0, 32'h0000_0340, "BGEU unsigned not-taken case");

        // branch_en must gate a true comparison.
        check_branch(1'b0, `F3_BEQ, 32'hCAFE_BABE, 32'hCAFE_BABE,
                     32'h0000_0400, 32'h0000_0008,
                     1'b0, 32'h0000_0408, "branch_en=0 suppresses a taken condition");

        // Reserved branch operation codes must never take a branch.
        check_branch(1'b1, `F3_BRANCH_NONE, 32'd0, 32'd0,
                     32'h0000_0500, 32'h0000_0008,
                     1'b0, 32'h0000_0508, "reserved branch operation 010 is safe");
        check_branch(1'b1, 3'b011, 32'd0, 32'd0,
                     32'hFFFF_FFFC, 32'h0000_0008,
                     1'b0, 32'h0000_0004, "reserved operation and target wraparound");

        $display("[PASS] tb_Branch_Unit completed.");
        $finish;
    end

endmodule
