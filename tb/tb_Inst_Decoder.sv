`timescale 1ns / 100ps
module tb_Inst_Decoder;

logic [31:0] inst_r;

logic [6:0] opcode_;
logic [4:0] addr_rd_;
logic [2:0] funct3_;
logic [4:0] addr_rs1_;
logic [4:0] addr_rs2_;
logic [6:0] funct7_;
logic [31:0] imm_;

Inst_Decoder u_Inst_Decoder(
    .inst_r(inst_r),
    .opcode_(opcode_),
    .addr_rd_(addr_rd_),
    .funct3_(funct3_),
    .addr_rs1_(addr_rs1_),
    .addr_rs2_(addr_rs2_),
    .funct7_(funct7_),
    .imm_(imm_)
);

task automatic check_i_type(
    input logic [31:0] instruction,
    input logic [6:0]  expected_opcode,
    input logic [4:0]  expected_rd,
    input logic [2:0]  expected_funct3,
    input logic [4:0]  expected_rs1,
    input logic [31:0] expected_imm,
    input string       test_name
);
    begin
        inst_r = instruction;
        #1;

        if (opcode_ !== expected_opcode)
            $fatal(1,
                "[FAIL] %s opcode: expected=%07b actual=%07b",
                test_name, expected_opcode, opcode_
            );

        if (addr_rd_ !== expected_rd)
            $fatal(1,
                "[FAIL] %s rd: expected=%0d actual=%0d",
                test_name, expected_rd, addr_rd_
            );

        if (funct3_ !== expected_funct3)
            $fatal(1,
                "[FAIL] %s funct3: expected=%03b actual=%03b",
                test_name, expected_funct3, funct3_
            );

        if (addr_rs1_ !== expected_rs1)
            $fatal(1,
                "[FAIL] %s rs1: expected=%0d actual=%0d",
                test_name, expected_rs1, addr_rs1_
            );

        if (imm_ !== expected_imm)
            $fatal(1,
                "[FAIL] %s immediate: expected=%08h actual=%08h",
                test_name, expected_imm, imm_
            );

        $display("[PASS] %s decode", test_name);
    end
endtask

task automatic check_r_type(
    input logic [31:0] instruction,
    input logic [6:0]  expected_opcode,
    input logic [4:0]  expected_rd,
    input logic [2:0]  expected_funct3,
    input logic [4:0]  expected_rs1,
    input logic [4:0]  expected_rs2,
    input logic [6:0]  expected_funct7,
    input string       test_name
);
    begin
        inst_r = instruction;
        #1;

        if (opcode_ !== expected_opcode)
            $fatal(1,
                "[FAIL] %s opcode: expected=%07b actual=%07b",
                test_name, expected_opcode, opcode_
            );

        if (addr_rd_ !== expected_rd)
            $fatal(1,
                "[FAIL] %s rd: expected=%0d actual=%0d",
                test_name, expected_rd, addr_rd_
            );

        if (funct3_ !== expected_funct3)
            $fatal(1,
                "[FAIL] %s funct3: expected=%03b actual=%03b",
                test_name, expected_funct3, funct3_
            );

        if (addr_rs1_ !== expected_rs1)
            $fatal(1,
                "[FAIL] %s rs1: expected=%0d actual=%0d",
                test_name, expected_rs1, addr_rs1_
            );

        if (addr_rs2_ !== expected_rs2)
            $fatal(1,
                "[FAIL] %s rs2: expected=%0d actual=%0d",
                test_name, expected_rs2, addr_rs2_
            );

        if (funct7_ !== expected_funct7)
            $fatal(1,
                "[FAIL] %s funct7: expected=%07b actual=%07b",
                test_name, expected_funct7, funct7_
            );

        $display("[PASS] %s decode", test_name);
    end
endtask

task automatic check_imm(
    input logic [31:0] instruction,
    input logic [31:0] expected_imm,
    input string       test_name
);
    begin
        inst_r = instruction;
        #1;

        if (imm_ !== expected_imm)
            $fatal(1,
                "[FAIL] %s immediate: expected=%08h actual=%08h",
                test_name, expected_imm, imm_
            );

        $display("[PASS] %s immediate", test_name);
    end
endtask

initial begin
    // NOP
    inst_r = 32'h0000_0013;
    #1;
    if (opcode_ !== 7'b0010011) $fatal(1, "[FAIL] NOP opcode");
    if (addr_rd_ !== 5'b00000) $fatal(1, "[FAIL] NOP rd");
    if (funct3_ !== 3'b000) $fatal(1, "[FAIL] NOP funct3");
    if (addr_rs1_ !== 5'b00000) $fatal(1, "[FAIL] NOP addr rs1");
    if (addr_rs2_ !== 5'b00000) $fatal(1, "[FAIL] NOP addr rs2");
    if (funct7_ !== 7'b0) $fatal(1, "[FAIL] NOP funct7");
    if (imm_ !== 32'b0) $fatal(1, "[FAIL] NOP imm");
    
    $display("[PASS] NOP decode");

    check_i_type(
        32'hFFB0_0093,
        7'b0010011,
        5'd1,
        3'b000,
        5'd0,
        32'hFFFF_FFFB,
        "ADDI x1, x0, -5"
    );

    check_i_type(
        32'h7FF1_7293,
        7'b0010011,
        5'd5,
        3'b111,
        5'd2,
        32'h0000_07FF,
        "ANDI x5, x2, 2047"
    );

    check_r_type(
        32'h4020_81B3,
        7'b0110011,
        5'd3,
        3'b000,
        5'd1,
        5'd2,
        7'b0100000,
        "SUB x3, x1, x2"
    );

    // I-type: ALU immediate, load and JALR all use inst[31:20].
    check_imm(32'h07B0_0093, 32'h0000_007B, "I-type ADDI +123");
    check_imm(32'hFFB0_0093, 32'hFFFF_FFFB, "I-type ADDI -5");
    check_imm(32'h00C2_2183, 32'h0000_000C, "I-type LW +12");
    check_imm(32'hFFC1_00E7, 32'hFFFF_FFFC, "I-type JALR -4");

    // S-type store offsets.
    check_imm(32'h0020_A823, 32'h0000_0010, "S-type SW +16");
    check_imm(32'hFE20_A823, 32'hFFFF_FFF0, "S-type SW -16");

    // B-type branch offsets always have bit 0 cleared.
    check_imm(32'h0020_8863, 32'h0000_0010, "B-type BEQ +16");
    check_imm(32'hFE20_88E3, 32'hFFFF_FFF0, "B-type BEQ -16");

    // U-type keeps inst[31:12] and appends twelve zero bits.
    check_imm(32'h1234_52B7, 32'h1234_5000, "U-type LUI 0x12345");
    check_imm(32'hABCD_E317, 32'hABCD_E000, "U-type AUIPC 0xABCDE");
    if (opcode_ !== 7'b0010111)
        $fatal(1,
            "[FAIL] U-type AUIPC opcode: expected=%07b actual=%07b",
            7'b0010111, opcode_
        );
    $display("[PASS] U-type AUIPC opcode");

    // J-type jump offsets always have bit 0 cleared.
    check_imm(32'h0100_00EF, 32'h0000_0010, "J-type JAL +16");
    check_imm(32'hFF1F_F0EF, 32'hFFFF_FFF0, "J-type JAL -16");

    // Instructions without an immediate must decode to zero.
    check_imm(32'h4020_81B3, 32'h0000_0000, "R-type immediate is zero");
    check_imm(32'hFFF0_0000, 32'h0000_0000, "Unknown opcode immediate is zero");

    $display("[PASS] tb_Inst_Decoder completed.");
    $finish;

end

endmodule
