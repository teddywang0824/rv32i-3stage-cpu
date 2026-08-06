`timescale 1ns / 100ps
`include "defines.sv"

module tb_ALU;

    logic [31:0] operand_a_;
    logic [31:0] operand_b_;
    logic [3:0]  alu_op_;
    logic [31:0] result_;

    ALU u_ALU (
        .operand_a_ (operand_a_),
        .operand_b_ (operand_b_),
        .alu_op_    (alu_op_),
        .result_    (result_)
    );

    task automatic check_alu(
        input logic [31:0] test_a,
        input logic [31:0] test_b,
        input logic [3:0]  test_op,
        input logic [31:0] expected,
        input string       test_name
    );
        begin
            operand_a_ = test_a;
            operand_b_ = test_b;
            alu_op_    = test_op;
            #1;

            if (result_ !== expected) begin
                $fatal(1,
                    "[FAIL] %s: A=0x%08h B=0x%08h expected=0x%08h actual=0x%08h",
                    test_name, test_a, test_b, expected, result_
                );
            end

            $display("[PASS] %s: result=0x%08h", test_name, result_);
        end
    endtask

    initial begin
        // Arithmetic operations and 32-bit wraparound.
        check_alu(32'd7,         32'd5, `ALUOP_ADD, 32'd12,        "ADD");
        check_alu(32'hFFFF_FFFF, 32'd1, `ALUOP_ADD, 32'h0000_0000, "ADD wraparound");
        check_alu(32'd7,         32'd5, `ALUOP_SUB, 32'd2,         "SUB");
        check_alu(32'd0,         32'd1, `ALUOP_SUB, 32'hFFFF_FFFF, "SUB wraparound");

        // Bitwise logic operations.
        check_alu(32'hF0F0_F0F0, 32'h0FF0_0FF0, `ALUOP_AND, 32'h00F0_00F0, "AND");
        check_alu(32'hF0F0_F0F0, 32'h0FF0_0FF0, `ALUOP_OR,  32'hFFF0_FFF0, "OR");
        check_alu(32'hF0F0_F0F0, 32'h0FF0_0FF0, `ALUOP_XOR, 32'hFF00_FF00, "XOR");

        // The same bit pattern produces different signed/unsigned results.
        check_alu(32'hFFFF_FFFF, 32'd1,         `ALUOP_LT,  32'd1, "LT: -1 < 1");
        check_alu(32'd1,         32'hFFFF_FFFF, `ALUOP_LT,  32'd0, "LT: 1 < -1");
        check_alu(32'hFFFF_FFFF, 32'd1,         `ALUOP_LTU, 32'd0, "LTU: max < 1");
        check_alu(32'd1,         32'hFFFF_FFFF, `ALUOP_LTU, 32'd1, "LTU: 1 < max");

        // RV32 uses only the low five bits of the shift amount.
        check_alu(32'h0000_0001, 32'd4,  `ALUOP_SLL, 32'h0000_0010, "SLL by 4");
        check_alu(32'h0000_0001, 32'd33, `ALUOP_SLL, 32'h0000_0002, "SLL by 33 uses shamt 1");
        check_alu(32'h8000_0000, 32'd4,  `ALUOP_SRL, 32'h0800_0000, "SRL fills with zero");
        check_alu(32'h8000_0000, 32'd4,  `ALUOP_SRA, 32'hF800_0000, "SRA preserves sign");

        // NOP and unsupported operation codes must be side-effect free.
        check_alu(32'hDEAD_BEEF, 32'hCAFE_BABE, `ALUOP_NOP, 32'd0, "NOP");
        check_alu(32'hDEAD_BEEF, 32'hCAFE_BABE, 4'd10,      32'd0, "unknown operation");

        $display("[PASS] tb_ALU completed.");
        $finish;
    end

endmodule
