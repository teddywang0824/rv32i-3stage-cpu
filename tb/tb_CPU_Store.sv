`timescale 1ns / 100ps
`include "defines.sv"

module tb_CPU_Store;

    logic clk;
    logic rst;

    CPU_Sim_Top u_CPU_Top (
        .clk(clk),
        .rst(rst),
        .trap_ack(1'b0),
        .trap_redirect_pc(32'd0)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("build/cpu_store.vcd");
        $dumpvars(0, tb_CPU_Store);
    end

    function automatic logic [31:0] encode_addi(
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic signed [31:0] immediate
    );
        encode_addi = {immediate[11:0], rs1, 3'b000, rd, `Opcode_I};
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
            encode_store = {
                imm[11:5], rs2, rs1, funct3, imm[4:0], `Opcode_STORE
            };
        end
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

    task automatic check_memory_word(
        input integer word_index,
        input logic [31:0] expected,
        input string test_name
    );
        logic [31:0] actual;
        begin
            actual = u_CPU_Top.u_Data_Memory.memory[word_index];
            if (actual !== expected)
                $fatal(1,
                    "[FAIL] %s: memory[%0d] expected=0x%08h actual=0x%08h",
                    test_name, word_index, expected, actual
                );
        end
    endtask

    task automatic run_store_sizes_and_offsets;
        begin
            begin_case();
            u_CPU_Top.write_reg(1, 32'd0);
            u_CPU_Top.write_reg(2, 32'h0000_00D4);
            u_CPU_Top.write_reg(3, 32'h0000_BEEF);
            u_CPU_Top.write_reg(4, 32'h1234_5678);

            u_CPU_Top.u_Program_Rom.memory[0] = encode_store(`F3_SB, 5'd1, 5'd2, 32'sd0);
            u_CPU_Top.u_Program_Rom.memory[1] = encode_store(`F3_SB, 5'd1, 5'd2, 32'sd1);
            u_CPU_Top.u_Program_Rom.memory[2] = encode_store(`F3_SB, 5'd1, 5'd2, 32'sd2);
            u_CPU_Top.u_Program_Rom.memory[3] = encode_store(`F3_SB, 5'd1, 5'd2, 32'sd3);
            u_CPU_Top.u_Program_Rom.memory[4] = encode_store(`F3_SH, 5'd1, 5'd3, 32'sd4);
            u_CPU_Top.u_Program_Rom.memory[5] = encode_store(`F3_SH, 5'd1, 5'd3, 32'sd6);
            u_CPU_Top.u_Program_Rom.memory[6] = encode_store(`F3_SW, 5'd1, 5'd4, 32'sd8);

            repeat (18) @(posedge clk);
            #1;

            check_memory_word(0, 32'hD4D4_D4D4, "SB covers all four byte offsets");
            check_memory_word(1, 32'hBEEF_BEEF, "SH covers both aligned halfword offsets");
            check_memory_word(2, 32'h1234_5678, "SW stores complete word");
            if (u_CPU_Top.read_reg(1) !== 32'd0 ||
                u_CPU_Top.read_reg(2) !== 32'h0000_00D4 ||
                u_CPU_Top.read_reg(3) !== 32'h0000_BEEF ||
                u_CPU_Top.read_reg(4) !== 32'h1234_5678)
                $fatal(1, "[FAIL] Store instruction unexpectedly wrote Register File");

            $display("[PASS] CPU Store sizes, offsets, and no register write-back");
        end
    endtask

    task automatic run_negative_immediate;
        begin
            begin_case();
            u_CPU_Top.write_reg(1, 32'd16);
            u_CPU_Top.write_reg(2, 32'hCAFE_BABE);
            u_CPU_Top.u_Program_Rom.memory[0] =
                encode_store(`F3_SW, 5'd1, 5'd2, -32'sd4);

            repeat (10) @(posedge clk);
            #1;
            check_memory_word(3, 32'hCAFE_BABE,
                              "SW uses sign-extended negative S-immediate");
            $display("[PASS] CPU Store negative S-immediate");
        end
    endtask

    task automatic run_store_forwarding;
        begin
            begin_case();
            u_CPU_Top.write_reg(2, 32'h0000_00D4);

            // The first SB needs rs1 forwarding; the second needs rs2 forwarding.
            u_CPU_Top.u_Program_Rom.memory[0] = encode_addi(5'd1, 5'd0, 32'sd32);
            u_CPU_Top.u_Program_Rom.memory[1] = encode_store(`F3_SB, 5'd1, 5'd2, 32'sd0);
            u_CPU_Top.u_Program_Rom.memory[2] = encode_addi(5'd3, 5'd0, 32'sd90);
            u_CPU_Top.u_Program_Rom.memory[3] = encode_store(`F3_SB, 5'd1, 5'd3, 32'sd1);

            repeat (14) @(posedge clk);
            #1;
            check_memory_word(8, 32'h0000_5AD4,
                              "Store receives forwarded base and write data");
            $display("[PASS] CPU Store rs1/rs2 forwarding");
        end
    endtask

    task automatic run_misaligned_suppression;
        begin
            begin_case();
            u_CPU_Top.write_reg(1, 32'd0);
            u_CPU_Top.write_reg(2, 32'h1122_3344);
            u_CPU_Top.u_Data_Memory.memory[0] = 32'hCAFE_BABE;

            u_CPU_Top.u_Program_Rom.memory[0] = encode_store(`F3_SH, 5'd1, 5'd2, 32'sd1);
            u_CPU_Top.u_Program_Rom.memory[1] = encode_store(`F3_SW, 5'd1, 5'd2, 32'sd2);

            repeat (10) @(posedge clk);
            #1;
            check_memory_word(0, 32'hCAFE_BABE,
                              "misaligned SH/SW produce no memory side effect");
            $display("[PASS] CPU Store misalignment suppression");
        end
    endtask

    task automatic run_flush_case;
        begin
            begin_case();
            u_CPU_Top.write_reg(2, 32'h89AB_CDEF);

            u_CPU_Top.u_Program_Rom.memory[0] = encode_jal(5'd0, 32'sd12);
            u_CPU_Top.u_Program_Rom.memory[1] = encode_store(`F3_SW, 5'd0, 5'd2, 32'sd0);
            u_CPU_Top.u_Program_Rom.memory[2] = encode_store(`F3_SW, 5'd0, 5'd2, 32'sd4);
            u_CPU_Top.u_Program_Rom.memory[3] = encode_store(`F3_SW, 5'd0, 5'd2, 32'sd8);

            repeat (15) @(posedge clk);
            #1;
            check_memory_word(0, 32'd0, "JAL flushes first wrong-path Store");
            check_memory_word(1, 32'd0, "JAL flushes second wrong-path Store");
            check_memory_word(2, 32'h89AB_CDEF, "Store at jump target executes");
            $display("[PASS] CPU Store wrong-path flush");
        end
    endtask

    initial begin
        rst = 1'b1;
        clear_rom_and_data();

        if (encode_store(`F3_SW, 5'd1, 5'd2, 32'sd16) !== 32'h0020_A823)
            $fatal(1, "[FAIL] testbench positive S-immediate encoder");
        if (encode_store(`F3_SW, 5'd1, 5'd2, -32'sd4) !== 32'hFE20_AE23)
            $fatal(1, "[FAIL] testbench negative S-immediate encoder");

        run_store_sizes_and_offsets();
        run_negative_immediate();
        run_store_forwarding();
        run_misaligned_suppression();
        run_flush_case();

        $display("[PASS] tb_CPU_Store completed: 5 integration scenarios.");
        $finish;
    end

    initial begin
        #15000;
        $fatal(1, "[FAIL] tb_CPU_Store timeout");
    end

endmodule
