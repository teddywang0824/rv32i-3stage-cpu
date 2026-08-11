`timescale 1ns / 100ps
`include "defines.sv"

module tb_CPU_JALR;

    logic clk;
    logic rst;
    logic check_redirect_edge;
    logic [31:0] expected_redirect_target;
    logic [31:0] killed_response_pc;
    logic [31:0] killed_response_inst;
    integer redirect_check_count;

    CPU_Top u_CPU_Top (
        .clk(clk),
        .rst(rst)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("build/cpu_jalr.vcd");
        $dumpvars(0, tb_CPU_JALR);
    end

    always @(negedge clk) begin
        check_redirect_edge = !rst && u_CPU_Top.branch_taken;
        if (check_redirect_edge) begin
            if (u_CPU_Top.fetch_response_valid !== 1'b1)
                $fatal(1, "[FAIL] JALR redirect has no valid younger response to kill");
            expected_redirect_target = u_CPU_Top.branch_target;
            killed_response_pc = u_CPU_Top.fetch_response_pc;
            killed_response_inst = u_CPU_Top.fetch_response_inst;
        end
    end

    always @(posedge clk) begin
        #1;
        if (check_redirect_edge) begin
            if (u_CPU_Top.pc !== expected_redirect_target)
                $fatal(1, "[FAIL] JALR redirect did not load target PC");
            if (u_CPU_Top.fetch_response_valid !== 1'b0)
                $fatal(1, "[FAIL] JALR redirect did not invalidate fetch response");
            if (u_CPU_Top.fetch_response_pc !== killed_response_pc ||
                u_CPU_Top.fetch_response_inst !== killed_response_inst)
                $fatal(1, "[FAIL] JALR kill unexpectedly changed response payload");
            if (u_CPU_Top.idex_valid_inst_r !== 1'b0)
                $fatal(1, "[FAIL] JALR redirect did not insert ID/EX bubble");
            redirect_check_count = redirect_check_count + 1;
        end
    end

    function automatic logic [31:0] encode_addi(
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic signed [31:0] immediate
    );
        encode_addi = {immediate[11:0], rs1, 3'b000, rd, `Opcode_I};
    endfunction

    function automatic logic [31:0] encode_jalr(
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic signed [31:0] immediate
    );
        encode_jalr = {immediate[11:0], rs1, 3'b000, rd, `Opcode_JALR};
    endfunction

    function automatic logic [31:0] encode_illegal_jalr(
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic signed [31:0] immediate
    );
        encode_illegal_jalr = {immediate[11:0], rs1, 3'b001, rd, `Opcode_JALR};
    endfunction

    task automatic clear_rom;
        integer i;
        begin
            for (i = 0; i < 64; i = i + 1)
                u_CPU_Top.u_Program_Rom.memory[i] = `I_NOP;
        end
    endtask

    task automatic begin_case;
        begin
            @(negedge clk);
            rst = 1'b1;
            clear_rom();
            repeat (3) @(posedge clk);
            @(negedge clk);
            rst = 1'b0;
        end
    endtask

    task automatic check_reg(
        input logic [4:0] addr,
        input logic [31:0] expected,
        input string test_name
    );
        logic [31:0] actual;
        begin
            actual = u_CPU_Top.u_Reg_File.regs[addr];
            if (actual !== expected)
                $fatal(1,
                    "[FAIL] %s: expected x%0d=0x%08h actual=0x%08h",
                    test_name, addr, expected, actual
                );
        end
    endtask

    // The ADDI immediately before JALR produces its base register.  The raw
    // sum is 25, so JALR must clear bit 0 and redirect to PC=24.
    task automatic run_forwarded_base_case;
        begin
            begin_case();

            u_CPU_Top.u_Program_Rom.memory[0] = `I_NOP;
            u_CPU_Top.u_Program_Rom.memory[1] = encode_addi(5'd1, 5'd0, 32'sd25);
            u_CPU_Top.u_Program_Rom.memory[2] = encode_jalr(5'd5, 5'd1, 32'sd0);
            u_CPU_Top.u_Program_Rom.memory[3] = encode_addi(5'd26, 5'd0, 32'sd1);
            u_CPU_Top.u_Program_Rom.memory[4] = encode_addi(5'd27, 5'd0, 32'sd1);
            u_CPU_Top.u_Program_Rom.memory[6] = encode_addi(5'd28, 5'd0, 32'sd7);
            u_CPU_Top.u_Program_Rom.memory[7] = encode_addi(5'd29, 5'd5, 32'sd1);

            repeat (18) @(posedge clk);
            #1;

            check_reg(5'd1,  32'd25, "JALR base producer executes");
            check_reg(5'd5,  32'd12, "JALR writes instruction PC+4 to rd");
            check_reg(5'd26, 32'd0,  "JALR flushes first younger instruction");
            check_reg(5'd27, 32'd0,  "JALR flushes second younger instruction");
            check_reg(5'd28, 32'd7,  "JALR clears target bit zero and reaches PC=24");
            check_reg(5'd29, 32'd13, "target path reads JALR link register");

            $display("[PASS] JALR forwarded base, bit-zero clearing, link, and flush");
        end
    endtask

    task automatic run_negative_immediate_case;
        begin
            begin_case();

            // JALR is at PC=8: (x2=32) + (-12) = target PC=20, link=12.
            u_CPU_Top.u_Reg_File.regs[2] = 32'd32;
            u_CPU_Top.u_Program_Rom.memory[0] = `I_NOP;
            u_CPU_Top.u_Program_Rom.memory[1] = `I_NOP;
            u_CPU_Top.u_Program_Rom.memory[2] = encode_jalr(5'd6, 5'd2, -32'sd12);
            u_CPU_Top.u_Program_Rom.memory[3] = encode_addi(5'd26, 5'd0, 32'sd1);
            u_CPU_Top.u_Program_Rom.memory[4] = encode_addi(5'd27, 5'd0, 32'sd1);
            u_CPU_Top.u_Program_Rom.memory[5] = encode_addi(5'd28, 5'd0, 32'sd9);

            repeat (18) @(posedge clk);
            #1;

            check_reg(5'd6,  32'd12, "negative-immediate JALR writes PC+4");
            check_reg(5'd26, 32'd0,  "negative-immediate JALR flushes first younger instruction");
            check_reg(5'd27, 32'd0,  "negative-immediate JALR flushes second younger instruction");
            check_reg(5'd28, 32'd9,  "JALR sign-extends negative immediate");

            $display("[PASS] JALR negative immediate");
        end
    endtask

    task automatic run_rd_zero_case;
        begin
            begin_case();

            u_CPU_Top.u_Reg_File.regs[3] = 32'd13;
            u_CPU_Top.u_Program_Rom.memory[0] = encode_jalr(5'd0, 5'd3, 32'sd0);
            u_CPU_Top.u_Program_Rom.memory[1] = encode_addi(5'd26, 5'd0, 32'sd1);
            u_CPU_Top.u_Program_Rom.memory[2] = encode_addi(5'd27, 5'd0, 32'sd1);
            u_CPU_Top.u_Program_Rom.memory[3] = encode_addi(5'd28, 5'd0, 32'sd11);

            repeat (15) @(posedge clk);
            #1;

            check_reg(5'd0,  32'd0,  "JALR x0 preserves architectural zero");
            check_reg(5'd26, 32'd0,  "JALR x0 flushes first younger instruction");
            check_reg(5'd27, 32'd0,  "JALR x0 flushes second younger instruction");
            check_reg(5'd28, 32'd11, "JALR x0 still redirects using rs1 base");

            $display("[PASS] JALR with rd=x0");
        end
    endtask

    task automatic run_illegal_funct3_case;
        begin
            begin_case();

            u_CPU_Top.u_Reg_File.regs[1] = 32'd20;
            u_CPU_Top.u_Program_Rom.memory[0] =
                encode_illegal_jalr(5'd7, 5'd1, 32'sd0);
            u_CPU_Top.u_Program_Rom.memory[1] = encode_addi(5'd26, 5'd0, 32'sd1);
            u_CPU_Top.u_Program_Rom.memory[2] = encode_addi(5'd27, 5'd0, 32'sd1);

            repeat (12) @(posedge clk);
            #1;

            check_reg(5'd7,  32'd0, "reserved JALR funct3 does not write rd");
            check_reg(5'd26, 32'd1, "reserved JALR funct3 does not redirect");
            check_reg(5'd27, 32'd1, "reserved JALR funct3 does not flush sequential path");

            $display("[PASS] reserved JALR funct3 is rejected safely");
        end
    endtask

    initial begin
        rst = 1'b1;
        check_redirect_edge = 1'b0;
        redirect_check_count = 0;
        clear_rom();

        // Protect the testbench's own I-type encoding.
        if (encode_jalr(5'd5, 5'd1, 32'sd12) !== 32'h00C0_82E7)
            $fatal(1, "[FAIL] testbench JALR encoder");

        run_forwarded_base_case();
        run_negative_immediate_case();
        run_rd_zero_case();
        run_illegal_funct3_case();

        if (redirect_check_count !== 3)
            $fatal(1, "[FAIL] expected 3 legal JALR redirects, observed %0d",
                   redirect_check_count);

        $display("[PASS] tb_CPU_JALR completed: 4 integration scenarios, 3 redirect edge checks.");
        $finish;
    end

    initial begin
        #12000;
        $fatal(1, "[FAIL] tb_CPU_JALR timeout");
    end

endmodule
