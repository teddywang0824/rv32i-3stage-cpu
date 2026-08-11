`timescale 1ns / 100ps
`include "defines.sv"

module tb_CPU_Load;

    logic clk;
    logic rst;

    CPU_Top u_CPU_Top (
        .clk(clk),
        .rst(rst)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("build/cpu_load.vcd");
        $dumpvars(0, tb_CPU_Load);
    end

    function automatic logic [31:0] encode_addi(
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic signed [31:0] immediate
    );
        encode_addi = {immediate[11:0], rs1, 3'b000, rd, `Opcode_I};
    endfunction

    function automatic logic [31:0] encode_load(
        input logic [2:0] funct3,
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic signed [31:0] immediate
    );
        encode_load = {immediate[11:0], rs1, funct3, rd, `Opcode_LOAD};
    endfunction

    function automatic logic [31:0] encode_jal(
        input logic [4:0] rd,
        input logic signed [31:0] offset
    );
        logic [20:0] imm;
        begin
            imm = offset[20:0];
            encode_jal = {
                imm[20], imm[10:1], imm[11], imm[19:12],
                rd, `Opcode_JAL
            };
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

    task automatic begin_case;
        begin
            @(negedge clk);
            rst = 1'b1;
            clear_rom_and_data();
            repeat (3) @(posedge clk);
            @(negedge clk);
            rst = 1'b0;
        end
    endtask

    task automatic check_reg(
        input logic [4:0] reg_index,
        input logic [31:0] expected,
        input string test_name
    );
        logic [31:0] actual;
        begin
            actual = u_CPU_Top.u_Reg_File.regs[reg_index];
            if (actual !== expected)
                $fatal(1,
                    "[FAIL] %s: x%0d expected=0x%08h actual=0x%08h",
                    test_name, reg_index, expected, actual
                );
        end
    endtask

    task automatic run_sizes_offsets_and_extensions;
        begin
            begin_case();
            u_CPU_Top.u_Reg_File.regs[1] = 32'd0;
            u_CPU_Top.u_Data_Memory.memory[0] = 32'h80FF_7F01;

            // Consecutive requests also verify that address, rd, load_op and
            // synchronous read_data stay associated with the same instruction.
            u_CPU_Top.u_Program_Rom.memory[0] = encode_load(`F3_LB,  5'd2,  5'd1, 32'sd0);
            u_CPU_Top.u_Program_Rom.memory[1] = encode_load(`F3_LB,  5'd3,  5'd1, 32'sd2);
            u_CPU_Top.u_Program_Rom.memory[2] = encode_load(`F3_LBU, 5'd4,  5'd1, 32'sd2);
            u_CPU_Top.u_Program_Rom.memory[3] = encode_load(`F3_LB,  5'd5,  5'd1, 32'sd3);
            u_CPU_Top.u_Program_Rom.memory[4] = encode_load(`F3_LBU, 5'd6,  5'd1, 32'sd3);
            u_CPU_Top.u_Program_Rom.memory[5] = encode_load(`F3_LH,  5'd7,  5'd1, 32'sd0);
            u_CPU_Top.u_Program_Rom.memory[6] = encode_load(`F3_LH,  5'd8,  5'd1, 32'sd2);
            u_CPU_Top.u_Program_Rom.memory[7] = encode_load(`F3_LHU, 5'd9,  5'd1, 32'sd2);
            u_CPU_Top.u_Program_Rom.memory[8] = encode_load(`F3_LW,  5'd10, 5'd1, 32'sd0);

            repeat (22) @(posedge clk);
            #1;

            check_reg(5'd2,  32'h0000_0001, "LB offset 0");
            check_reg(5'd3,  32'hFFFF_FFFF, "LB sign extension");
            check_reg(5'd4,  32'h0000_00FF, "LBU zero extension");
            check_reg(5'd5,  32'hFFFF_FF80, "LB upper byte sign extension");
            check_reg(5'd6,  32'h0000_0080, "LBU upper byte zero extension");
            check_reg(5'd7,  32'h0000_7F01, "LH lower halfword");
            check_reg(5'd8,  32'hFFFF_80FF, "LH upper halfword sign extension");
            check_reg(5'd9,  32'h0000_80FF, "LHU upper halfword zero extension");
            check_reg(5'd10, 32'h80FF_7F01, "LW complete word");

            $display("[PASS] CPU Load sizes, offsets, signed/unsigned extension, and consecutive requests");
        end
    endtask

    task automatic run_address_and_writeback_sequence;
        begin
            begin_case();
            u_CPU_Top.u_Reg_File.regs[1] = 32'd16;
            u_CPU_Top.u_Data_Memory.memory[3] = 32'hCAFE_BABE;
            u_CPU_Top.u_Data_Memory.memory[8] = 32'h1122_3344;

            u_CPU_Top.u_Program_Rom.memory[0] = encode_load(`F3_LW, 5'd11, 5'd1, -32'sd4);
            u_CPU_Top.u_Program_Rom.memory[1] = encode_addi(5'd3, 5'd0, 32'sd32);
            // x3 is produced by the immediately preceding ALU instruction;
            // this checks rs1 forwarding into Load address calculation.
            u_CPU_Top.u_Program_Rom.memory[2] = encode_load(`F3_LW, 5'd12, 5'd3, 32'sd0);
            // An independent ALU instruction following a Load must still write.
            u_CPU_Top.u_Program_Rom.memory[3] = encode_addi(5'd13, 5'd0, 32'sd85);

            repeat (16) @(posedge clk);
            #1;

            check_reg(5'd11, 32'hCAFE_BABE, "Load uses negative I-immediate");
            check_reg(5'd12, 32'h1122_3344, "Load receives forwarded base address");
            check_reg(5'd13, 32'h0000_0055, "ALU writeback after Load remains enabled");

            $display("[PASS] CPU Load address calculation, base forwarding, and writeback sequencing");
        end
    endtask

    task automatic run_misaligned_suppression;
        begin
            begin_case();
            u_CPU_Top.u_Reg_File.regs[1]  = 32'd0;
            u_CPU_Top.u_Reg_File.regs[14] = 32'hAAAA_AAAA;
            u_CPU_Top.u_Reg_File.regs[15] = 32'hBBBB_BBBB;
            u_CPU_Top.u_Data_Memory.memory[0] = 32'h89AB_CDEF;

            u_CPU_Top.u_Program_Rom.memory[0] = encode_load(`F3_LH, 5'd14, 5'd1, 32'sd1);
            u_CPU_Top.u_Program_Rom.memory[1] = encode_load(`F3_LW, 5'd15, 5'd1, 32'sd2);
            u_CPU_Top.u_Program_Rom.memory[2] = encode_load(`F3_LW, 5'd16, 5'd1, 32'sd0);

            repeat (14) @(posedge clk);
            #1;

            check_reg(5'd14, 32'hAAAA_AAAA, "misaligned LH suppresses rd write");
            check_reg(5'd15, 32'hBBBB_BBBB, "misaligned LW suppresses rd write");
            check_reg(5'd16, 32'h89AB_CDEF, "aligned Load after misaligned requests still writes");

            $display("[PASS] CPU Load misalignment suppression");
        end
    endtask

    task automatic run_flush_case;
        begin
            begin_case();
            u_CPU_Top.u_Reg_File.regs[17] = 32'h1717_1717;
            u_CPU_Top.u_Reg_File.regs[18] = 32'h1818_1818;
            u_CPU_Top.u_Data_Memory.memory[0] = 32'hAAAA_0000;
            u_CPU_Top.u_Data_Memory.memory[1] = 32'hBBBB_0001;
            u_CPU_Top.u_Data_Memory.memory[2] = 32'hCCCC_0002;

            u_CPU_Top.u_Program_Rom.memory[0] = encode_jal(5'd0, 32'sd12);
            u_CPU_Top.u_Program_Rom.memory[1] = encode_load(`F3_LW, 5'd17, 5'd0, 32'sd0);
            u_CPU_Top.u_Program_Rom.memory[2] = encode_load(`F3_LW, 5'd18, 5'd0, 32'sd4);
            u_CPU_Top.u_Program_Rom.memory[3] = encode_load(`F3_LW, 5'd19, 5'd0, 32'sd8);

            repeat (17) @(posedge clk);
            #1;

            check_reg(5'd17, 32'h1717_1717, "first wrong-path Load is flushed");
            check_reg(5'd18, 32'h1818_1818, "second wrong-path Load is flushed");
            check_reg(5'd19, 32'hCCCC_0002, "Load at jump target executes");

            $display("[PASS] CPU Load wrong-path flush");
        end
    endtask

    task automatic run_illegal_and_x0_case;
        begin
            begin_case();
            u_CPU_Top.u_Reg_File.regs[20] = 32'h2020_2020;
            u_CPU_Top.u_Data_Memory.memory[0] = 32'hDEAD_BEEF;

            u_CPU_Top.u_Program_Rom.memory[0] = encode_load(`F3_LW, 5'd0, 5'd0, 32'sd0);
            u_CPU_Top.u_Program_Rom.memory[1] = encode_load(3'b011, 5'd20, 5'd0, 32'sd0);

            repeat (12) @(posedge clk);
            #1;

            check_reg(5'd0, 32'd0, "Load cannot modify x0");
            check_reg(5'd20, 32'h2020_2020, "reserved Load funct3 has no writeback");

            $display("[PASS] CPU Load x0 and illegal encoding safety");
        end
    endtask

    initial begin
        rst = 1'b1;
        clear_rom_and_data();

        if (encode_load(`F3_LW, 5'd2, 5'd1, 32'sd16) !== 32'h0100_A103)
            $fatal(1, "[FAIL] testbench positive Load encoder");
        if (encode_load(`F3_LW, 5'd2, 5'd1, -32'sd4) !== 32'hFFC0_A103)
            $fatal(1, "[FAIL] testbench negative Load encoder");

        run_sizes_offsets_and_extensions();
        run_address_and_writeback_sequence();
        run_misaligned_suppression();
        run_flush_case();
        run_illegal_and_x0_case();

        $display("[PASS] tb_CPU_Load completed: 5 integration scenarios.");
        $finish;
    end

    initial begin
        #20000;
        $fatal(1, "[FAIL] tb_CPU_Load timeout");
    end

endmodule
