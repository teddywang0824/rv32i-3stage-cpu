`timescale 1ns / 100ps
`include "defines.sv"

module tb_CPU_Illegal;

    logic clk;
    logic rst;
    logic [6:0] seen_illegal;

    CPU_Sim_Top u_CPU_Top (
        .clk(clk),
        .rst(rst)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("build/cpu_illegal.vcd");
        $dumpvars(0, tb_CPU_Illegal);
    end

    function automatic logic [31:0] encode_addi(
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic signed [31:0] immediate
    );
        encode_addi = {immediate[11:0], rs1, `F_ADDI, rd, `Opcode_I};
    endfunction

    function automatic logic [31:0] encode_illegal_r(
        input logic [4:0] rd
    );
        encode_illegal_r = {7'b000_0001, 5'd0, 5'd0, `F_ADD_SUB,
                            rd, `Opcode_R_M};
    endfunction

    function automatic logic [31:0] encode_illegal_slli(
        input logic [4:0] rd,
        input logic [4:0] rs1
    );
        encode_illegal_slli = {7'b000_0001, 5'd1, rs1, `F_SLLI,
                               rd, `Opcode_I};
    endfunction

    function automatic logic [31:0] encode_load(
        input logic [2:0] funct3,
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic signed [31:0] immediate
    );
        encode_load = {immediate[11:0], rs1, funct3, rd, `Opcode_LOAD};
    endfunction

    function automatic logic [31:0] encode_store(
        input logic [2:0] funct3,
        input logic [4:0] rs1,
        input logic [4:0] rs2,
        input logic signed [31:0] immediate
    );
        logic [11:0] imm;
        begin
            imm = immediate[11:0];
            encode_store = {imm[11:5], rs2, rs1, funct3,
                            imm[4:0], `Opcode_STORE};
        end
    endfunction

    function automatic logic [31:0] encode_branch(
        input logic [2:0] funct3,
        input logic [4:0] rs1,
        input logic [4:0] rs2,
        input logic signed [31:0] offset
    );
        logic [12:0] imm;
        begin
            imm = offset[12:0];
            encode_branch = {imm[12], imm[10:5], rs2, rs1, funct3,
                             imm[4:1], imm[11], `Opcode_BRANCH};
        end
    endfunction

    function automatic logic [31:0] encode_jalr(
        input logic [2:0] funct3,
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic signed [31:0] immediate
    );
        encode_jalr = {immediate[11:0], rs1, funct3, rd, `Opcode_JALR};
    endfunction

    task automatic clear_rom_and_data;
        integer i;
        begin
            for (i = 0; i < 64; i = i + 1)
                u_CPU_Top.u_Program_Rom.memory[i] = `I_NOP;
            for (i = 0; i < 1024; i = i + 1)
                u_CPU_Top.u_Data_Memory.memory[i] = 32'd0;
        end
    endtask

    task automatic check_reg(
        input logic [4:0] index,
        input logic [31:0] expected,
        input string test_name
    );
        logic [31:0] actual;
        begin
            actual = u_CPU_Top.read_reg(index);
            if (actual !== expected)
                $fatal(1,
                    "[FAIL] %s: x%0d expected=0x%08h actual=0x%08h",
                    test_name, index, expected, actual
                );
        end
    endtask

    // Record that every illegal instruction really reached ID.  At the same
    // point, verify the controls as connected inside CPU_Top are safe.
    always @(posedge clk) begin
        if (rst) begin
            seen_illegal <= 7'b0;
        end else if (u_CPU_Top.fetch_response_valid &&
                     !u_CPU_Top.valid_inst_) begin
            if (u_CPU_Top.reg_write_ !== 1'b0 ||
                u_CPU_Top.mem_en !== 1'b0 ||
                u_CPU_Top.mem_write !== 1'b0 ||
                u_CPU_Top.branch_en_ !== 1'b0 ||
                u_CPU_Top.jump_op_ !== 1'b0 ||
                u_CPU_Top.id_uses_rs1 !== 1'b0 ||
                u_CPU_Top.id_uses_rs2 !== 1'b0)
                $fatal(1, "[FAIL] illegal instruction has a side-effect control");

            if (u_CPU_Top.fetch_response_inst === u_CPU_Top.u_Program_Rom.memory[1])
                seen_illegal[0] <= 1'b1;
            else if (u_CPU_Top.fetch_response_inst === u_CPU_Top.u_Program_Rom.memory[3])
                seen_illegal[1] <= 1'b1;
            else if (u_CPU_Top.fetch_response_inst === u_CPU_Top.u_Program_Rom.memory[4])
                seen_illegal[2] <= 1'b1;
            else if (u_CPU_Top.fetch_response_inst === u_CPU_Top.u_Program_Rom.memory[5])
                seen_illegal[3] <= 1'b1;
            else if (u_CPU_Top.fetch_response_inst === u_CPU_Top.u_Program_Rom.memory[6])
                seen_illegal[4] <= 1'b1;
            else if (u_CPU_Top.fetch_response_inst === u_CPU_Top.u_Program_Rom.memory[7])
                seen_illegal[5] <= 1'b1;
            else if (u_CPU_Top.fetch_response_inst === u_CPU_Top.u_Program_Rom.memory[8])
                seen_illegal[6] <= 1'b1;
        end

        if (!rst && u_CPU_Top.branch_taken)
            $fatal(1, "[FAIL] illegal control-flow encoding redirected the PC");
    end

    initial begin
        rst = 1'b1;
        seen_illegal = 7'b0;
        clear_rom_and_data();

        // Legal instructions surround seven distinct illegal encodings.
        // The reserved branch and JALR would skip later checks if decoded as
        // control flow, so seen_illegal also guards against a false pass.
        u_CPU_Top.u_Program_Rom.memory[0] = encode_addi(5'd1, 5'd0, 32'sd11);
        u_CPU_Top.u_Program_Rom.memory[1] = encode_illegal_r(5'd1);
        u_CPU_Top.u_Program_Rom.memory[2] = encode_addi(5'd2, 5'd1, 32'sd1);
        u_CPU_Top.u_Program_Rom.memory[3] = encode_illegal_slli(5'd2, 5'd2);
        u_CPU_Top.u_Program_Rom.memory[4] =
            encode_load(3'b011, 5'd3, 5'd0, 32'sd0);
        u_CPU_Top.u_Program_Rom.memory[5] =
            encode_store(3'b111, 5'd0, 5'd4, 32'sd0);
        u_CPU_Top.u_Program_Rom.memory[6] =
            encode_branch(3'b010, 5'd0, 5'd0, 32'sd16);
        u_CPU_Top.u_Program_Rom.memory[7] =
            encode_jalr(3'b001, 5'd5, 5'd6, 32'sd0);
        u_CPU_Top.u_Program_Rom.memory[8] =
            {12'hABC, 5'd0, 3'b111, 5'd7, 7'b111_1111};
        u_CPU_Top.u_Program_Rom.memory[9] = encode_addi(5'd8, 5'd0, 32'sd88);
        u_CPU_Top.u_Program_Rom.memory[10] =
            encode_store(`F3_SW, 5'd0, 5'd4, 32'sd4);

        repeat (3) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        // Sentinels make unintended register or memory writes observable.
        u_CPU_Top.write_reg(3, 32'h3333_3333);
        u_CPU_Top.write_reg(4, 32'h4444_4444);
        u_CPU_Top.write_reg(5, 32'h5555_5555);
        u_CPU_Top.write_reg(6, 32'd40);
        u_CPU_Top.write_reg(7, 32'h7777_7777);
        u_CPU_Top.u_Data_Memory.memory[0] = 32'hDEAD_BEEF;

        repeat (28) @(posedge clk);
        #1;

        if (seen_illegal !== 7'b111_1111)
            $fatal(1, "[FAIL] not all illegal instructions reached ID: seen=%07b",
                   seen_illegal);

        check_reg(5'd1, 32'd11, "illegal R-type preserves rd");
        check_reg(5'd2, 32'd12, "execution continues across illegal R/shift");
        check_reg(5'd3, 32'h3333_3333, "reserved Load preserves rd");
        check_reg(5'd5, 32'h5555_5555, "reserved JALR preserves rd");
        check_reg(5'd7, 32'h7777_7777, "unknown opcode preserves rd");
        check_reg(5'd8, 32'd88, "execution continues after illegal control flow");

        if (u_CPU_Top.u_Data_Memory.memory[0] !== 32'hDEAD_BEEF)
            $fatal(1, "[FAIL] reserved Store modified protected memory");
        if (u_CPU_Top.u_Data_Memory.memory[1] !== 32'h4444_4444)
            $fatal(1, "[FAIL] legal Store after illegal instructions did not execute");

        $display("[PASS] tb_CPU_Illegal completed: 7 illegal encodings have no side effects.");
        $finish;
    end

    initial begin
        #5000;
        $fatal(1, "[FAIL] tb_CPU_Illegal timeout");
    end

endmodule
