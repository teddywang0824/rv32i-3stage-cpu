`timescale 1ns / 100ps
`include "defines.sv"

module tb_CPU_Program;

    logic clk;
    logic rst;

    integer cycle_count;
    integer load_request_count;
    integer load_use_stall_count;
    integer bne_count;
    integer bne_taken_count;
    integer result_store_count;
    logic   saw_done_pc;

    CPU_Top u_CPU_Top (
        .clk(clk),
        .rst(rst)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("build/cpu_program.vcd");
        $dumpvars(0, tb_CPU_Program);
    end

    function automatic logic [31:0] encode_addi(
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic signed [31:0] immediate
    );
        encode_addi = {immediate[11:0], rs1, `F_ADDI, rd, `Opcode_I};
    endfunction

    function automatic logic [31:0] encode_add(
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic [4:0] rs2
    );
        encode_add = {`F7_ADD, rs2, rs1, `F_ADD_SUB, rd, `Opcode_R_M};
    endfunction

    function automatic logic [31:0] encode_lw(
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic signed [31:0] immediate
    );
        encode_lw = {immediate[11:0], rs1, `F3_LW, rd, `Opcode_LOAD};
    endfunction

    function automatic logic [31:0] encode_sw(
        input logic [4:0] rs1,
        input logic [4:0] rs2,
        input logic signed [31:0] immediate
    );
        logic [11:0] imm;
        begin
            imm = immediate[11:0];
            encode_sw = {imm[11:5], rs2, rs1, `F3_SW,
                         imm[4:0], `Opcode_STORE};
        end
    endfunction

    function automatic logic [31:0] encode_bne(
        input logic [4:0] rs1,
        input logic [4:0] rs2,
        input logic signed [31:0] offset
    );
        logic [12:0] imm;
        begin
            imm = offset[12:0];
            encode_bne = {imm[12], imm[10:5], rs2, rs1, `F3_BNE,
                          imm[4:1], imm[11], `Opcode_BRANCH};
        end
    endfunction

    function automatic logic [31:0] encode_jal(
        input logic [4:0] rd,
        input logic signed [31:0] offset
    );
        logic [20:0] imm;
        begin
            imm = offset[20:0];
            encode_jal = {imm[20], imm[10:1], imm[11], imm[19:12],
                          rd, `Opcode_JAL};
        end
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
            actual = u_CPU_Top.u_Reg_File.regs[index];
            if (actual !== expected)
                $fatal(1,
                    "[FAIL] %s: x%0d expected=0x%08h actual=0x%08h",
                    test_name, index, expected, actual
                );
        end
    endtask

    // Count architectural events independently from the final result.  These
    // checks prevent an accidentally preloaded or prematurely written value
    // from making the test pass.
    always @(posedge clk) begin
        if (rst) begin
            load_request_count  <= 0;
            load_use_stall_count <= 0;
            bne_count           <= 0;
            bne_taken_count     <= 0;
            result_store_count  <= 0;
            saw_done_pc         <= 1'b0;
        end else begin
            if (u_CPU_Top.mem_en_r && !u_CPU_Top.mem_write_r)
                load_request_count <= load_request_count + 1;

            if (u_CPU_Top.load_use_stall)
                load_use_stall_count <= load_use_stall_count + 1;

            if (u_CPU_Top.branch_en_r && !u_CPU_Top.jump_op_r &&
                u_CPU_Top.branch_op_r == `F3_BNE) begin
                bne_count <= bne_count + 1;
                if (u_CPU_Top.branch_taken)
                    bne_taken_count <= bne_taken_count + 1;
            end

            if (u_CPU_Top.mem_en_r && u_CPU_Top.mem_write_r &&
                !u_CPU_Top.misaligned && u_CPU_Top.alu_result_ == 32'd16)
                result_store_count <= result_store_count + 1;

            if (u_CPU_Top.pc == 32'd36)
                saw_done_pc <= 1'b1;
        end
    end

    initial begin
        rst = 1'b1;
        cycle_count = 0;
        load_request_count = 0;
        load_use_stall_count = 0;
        bne_count = 0;
        bne_taken_count = 0;
        result_store_count = 0;
        saw_done_pc = 1'b0;
        clear_rom_and_data();

        // Protect the testbench encoders with independently known machine
        // words, especially the backward B-immediate layout.
        if (encode_addi(5'd1, 5'd0, 32'sd0) !== 32'h0000_0093 ||
            encode_addi(5'd2, 5'd0, 32'sd4) !== 32'h0040_0113 ||
            encode_lw(5'd4, 5'd1, 32'sd0) !== 32'h0000_A203 ||
            encode_add(5'd3, 5'd3, 5'd4) !== 32'h0041_81B3 ||
            encode_bne(5'd2, 5'd0, -32'sd16) !== 32'hFE01_18E3 ||
            encode_sw(5'd0, 5'd3, 32'sd16) !== 32'h0030_2823 ||
            encode_jal(5'd0, 32'sd0) !== 32'h0000_006F)
            $fatal(1, "[FAIL] program testbench instruction encoder");

        // PC  Instruction
        //  0  addi x1,x0,0       array pointer
        //  4  addi x2,x0,4       remaining elements
        //  8  addi x3,x0,0       sum
        // 12  lw   x4,0(x1)
        // 16  add  x3,x3,x4      intentional load-use dependency
        // 20  addi x1,x1,4
        // 24  addi x2,x2,-1
        // 28  bne  x2,x0,-16     loop back to PC 12
        // 32  sw   x3,16(x0)     completion/result sentinel
        // 36  jal  x0,0           done loop
        u_CPU_Top.u_Program_Rom.memory[0] = encode_addi(5'd1, 5'd0, 32'sd0);
        u_CPU_Top.u_Program_Rom.memory[1] = encode_addi(5'd2, 5'd0, 32'sd4);
        u_CPU_Top.u_Program_Rom.memory[2] = encode_addi(5'd3, 5'd0, 32'sd0);
        u_CPU_Top.u_Program_Rom.memory[3] = encode_lw(5'd4, 5'd1, 32'sd0);
        u_CPU_Top.u_Program_Rom.memory[4] = encode_add(5'd3, 5'd3, 5'd4);
        u_CPU_Top.u_Program_Rom.memory[5] = encode_addi(5'd1, 5'd1, 32'sd4);
        u_CPU_Top.u_Program_Rom.memory[6] = encode_addi(5'd2, 5'd2, -32'sd1);
        u_CPU_Top.u_Program_Rom.memory[7] = encode_bne(5'd2, 5'd0, -32'sd16);
        u_CPU_Top.u_Program_Rom.memory[8] = encode_sw(5'd0, 5'd3, 32'sd16);
        u_CPU_Top.u_Program_Rom.memory[9] = encode_jal(5'd0, 32'sd0);

        // [3, -2, 7, 5] sums to 13 in 32-bit two's-complement arithmetic.
        u_CPU_Top.u_Data_Memory.memory[0] = 32'd3;
        u_CPU_Top.u_Data_Memory.memory[1] = 32'hFFFF_FFFE;
        u_CPU_Top.u_Data_Memory.memory[2] = 32'd7;
        u_CPU_Top.u_Data_Memory.memory[3] = 32'd5;
        u_CPU_Top.u_Data_Memory.memory[4] = 32'hCAFE_BABE;

        repeat (3) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        // Wait for the result Store, but always retain a hard cycle limit.
        while (u_CPU_Top.u_Data_Memory.memory[4] !== 32'd13 &&
               cycle_count < 120) begin
            @(posedge clk);
            #1;
            cycle_count = cycle_count + 1;
        end

        if (u_CPU_Top.u_Data_Memory.memory[4] !== 32'd13)
            $fatal(1, "[FAIL] array-sum program exceeded 120 cycles");

        // Allow event counters from the result Store edge and the following
        // done instruction to settle before checking the complete trace.
        repeat (5) @(posedge clk);
        #1;

        check_reg(5'd0, 32'd0,  "x0 remains hardwired to zero");
        check_reg(5'd1, 32'd16, "array pointer advances four words");
        check_reg(5'd2, 32'd0,  "loop counter reaches zero");
        check_reg(5'd3, 32'd13, "array sum register");
        check_reg(5'd4, 32'd5,  "last loaded element");

        if (u_CPU_Top.u_Data_Memory.memory[0] !== 32'd3 ||
            u_CPU_Top.u_Data_Memory.memory[1] !== 32'hFFFF_FFFE ||
            u_CPU_Top.u_Data_Memory.memory[2] !== 32'd7 ||
            u_CPU_Top.u_Data_Memory.memory[3] !== 32'd5)
            $fatal(1, "[FAIL] input array was unexpectedly modified");

        if (load_request_count !== 4)
            $fatal(1, "[FAIL] expected 4 loads, observed %0d",
                   load_request_count);
        if (load_use_stall_count !== 4)
            $fatal(1, "[FAIL] expected 4 load-use stalls, observed %0d",
                   load_use_stall_count);
        if (bne_count !== 4 || bne_taken_count !== 3)
            $fatal(1, "[FAIL] expected BNE executions/taken=4/3, observed %0d/%0d",
                   bne_count, bne_taken_count);
        if (result_store_count !== 1)
            $fatal(1, "[FAIL] expected one result Store, observed %0d",
                   result_store_count);
        if (!saw_done_pc)
            $fatal(1, "[FAIL] program did not reach the done-loop PC");

        $display("[PASS] tb_CPU_Program array sum completed in %0d cycles.",
                 cycle_count);
        $display("[PASS] result=13 loads=4 stalls=4 BNE=4 taken=3 stores=1.");
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "[FAIL] tb_CPU_Program timeout");
    end

endmodule
