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
    logic alu_src_imm_;
    logic [1:0] operand_a_sel_;
    logic [3:0] alu_op_;
    logic valid_inst_;
    logic [31:0] ifid_pc_;

    logic reg_write_r;
    logic alu_src_imm_r;
    logic [1:0] operand_a_sel_r;
    logic [3:0] alu_op_r;
    logic valid_inst_r;
    logic [31:0] idex_pc_r;

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
        .alu_src_imm_(alu_src_imm_),
        .operand_a_sel_(operand_a_sel_),
        .alu_op_(alu_op_),
        .valid_inst_(valid_inst_),
        .ifid_pc_(ifid_pc_),

        .reg_write_r(reg_write_r),
        .alu_src_imm_r(alu_src_imm_r),
        .operand_a_sel_r(operand_a_sel_r),
        .alu_op_r(alu_op_r),
        .valid_inst_r(valid_inst_r),
        .idex_pc_r(idex_pc_r)
        
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
        input logic        expected_alu_src_imm,
        input logic [1:0]  expected_operand_a_sel,
        input logic [3:0]  expected_alu_op,
        input logic        expected_valid_inst,
        input logic [31:0] expected_pc,
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

            if (alu_src_imm_r !== expected_alu_src_imm)
                $fatal(1,
                    "[FAIL] %s alu_src_imm: expected=%b actual=%b",
                    test_name, expected_alu_src_imm, alu_src_imm_r
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
        alu_src_imm_ = 1'b1;
        operand_a_sel_ = `OP_A_PC;
        alu_op_      = `ALUOP_ADD;
        valid_inst_  = 1'b1;
        ifid_pc_     = 32'hDEAD_BEEF;

        // Reset 在上升緣將所有輸出清為 0。
        @(posedge clk);
        #1;
        check_outputs(5'd0, 32'd0, 32'd0, 32'd0,
                      1'b0, 1'b0, `OP_A_RS1, `ALUOP_NOP, 1'b0, 32'd0,
                      "reset clears all outputs");

        // 解除 reset，並在下一個上升緣同時保存四個欄位。
        @(negedge clk);
        rst        = 1'b0;
        addr_rd_   = 5'd7;
        imm_       = 32'hFFFF_FFFB;
        rs1_value_ = 32'h1234_5678;
        rs2_value_ = 32'hCAFE_BABE;
        reg_write_   = 1'b1;
        alu_src_imm_ = 1'b1;
        operand_a_sel_ = `OP_A_PC;
        alu_op_      = `ALUOP_ADD;
        valid_inst_  = 1'b1;
        ifid_pc_     = 32'h0000_0100;

        @(posedge clk);
        #1;
        check_outputs(5'd7, 32'hFFFF_FFFB,
                      32'h1234_5678, 32'hCAFE_BABE,
                      1'b1, 1'b1, `OP_A_PC, `ALUOP_ADD, 1'b1, 32'h0000_0100,
                      "rising edge captures all inputs");

        // 在上升緣之間改變輸入，輸出仍應保持舊值。
        @(negedge clk);
        addr_rd_   = 5'd12;
        imm_       = 32'h0000_07FF;
        rs1_value_ = 32'hAAAA_AAAA;
        rs2_value_ = 32'h5555_5555;
        reg_write_   = 1'b0;
        alu_src_imm_ = 1'b0;
        operand_a_sel_ = `OP_A_ZERO;
        alu_op_      = `ALUOP_SUB;
        valid_inst_  = 1'b0;
        ifid_pc_     = 32'h0000_0104;
        #1;
        check_outputs(5'd7, 32'hFFFF_FFFB,
                      32'h1234_5678, 32'hCAFE_BABE,
                      1'b1, 1'b1, `OP_A_PC, `ALUOP_ADD, 1'b1, 32'h0000_0100,
                      "outputs hold between rising edges");

        // 下一個上升緣才一起更新。
        @(posedge clk);
        #1;
        check_outputs(5'd12, 32'h0000_07FF,
                      32'hAAAA_AAAA, 32'h5555_5555,
                      1'b0, 1'b0, `OP_A_ZERO, `ALUOP_SUB, 1'b0, 32'h0000_0104,
                      "next rising edge updates all outputs");

        // Flush 在上升緣將所有輸出清為 0。
        @(negedge clk);
        flush_IDEX_ = 1'b1;
        addr_rd_    = 5'd20;
        imm_        = 32'h0102_0304;
        rs1_value_  = 32'hABCD_EF01;
        rs2_value_  = 32'h1020_3040;
        reg_write_   = 1'b1;
        alu_src_imm_ = 1'b1;
        operand_a_sel_ = `OP_A_PC;
        alu_op_      = `ALUOP_AND;
        valid_inst_  = 1'b1;
        ifid_pc_     = 32'h0000_0200;

        @(posedge clk);
        #1;
        check_outputs(5'd0, 32'd0, 32'd0, 32'd0,
                      1'b0, 1'b0, `OP_A_RS1, `ALUOP_NOP, 1'b0, 32'd0,
                      "flush clears all outputs");

        // 解除 flush 後恢復正常保存。
        @(negedge clk);
        flush_IDEX_ = 1'b0;
        addr_rd_    = 5'd9;
        imm_        = 32'h0000_002A;
        rs1_value_  = 32'h0BAD_F00D;
        rs2_value_  = 32'h1357_2468;
        reg_write_   = 1'b1;
        alu_src_imm_ = 1'b1;
        operand_a_sel_ = `OP_A_PC;
        alu_op_      = `ALUOP_ADD;
        valid_inst_  = 1'b1;
        ifid_pc_     = 32'h0000_0300;

        @(posedge clk);
        #1;
        check_outputs(5'd9, 32'h0000_002A,
                      32'h0BAD_F00D, 32'h1357_2468,
                      1'b1, 1'b1, `OP_A_PC, `ALUOP_ADD, 1'b1, 32'h0000_0300,
                      "ID/EX resumes after flush");

        // 第二次 reset 仍能清除所有輸出。
        @(negedge clk);
        rst         = 1'b1;
        addr_rd_    = 5'd30;
        imm_        = 32'hFFFF_FFFF;
        rs1_value_  = 32'hDEAD_BEEF;
        rs2_value_  = 32'hCAFE_BABE;
        reg_write_   = 1'b1;
        alu_src_imm_ = 1'b1;
        operand_a_sel_ = `OP_A_ZERO;
        alu_op_      = `ALUOP_XOR;
        valid_inst_  = 1'b1;
        ifid_pc_     = 32'hFFFF_FFFC;

        @(posedge clk);
        #1;
        check_outputs(5'd0, 32'd0, 32'd0, 32'd0,
                      1'b0, 1'b0, `OP_A_RS1, `ALUOP_NOP, 1'b0, 32'd0,
                      "second reset clears all outputs");

        $display("[PASS] tb_IDEX completed.");
        $finish;
    end

endmodule
