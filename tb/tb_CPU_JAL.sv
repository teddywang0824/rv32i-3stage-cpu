`timescale 1ns / 100ps
`include "defines.sv"

module tb_CPU_JAL;

    logic clk;
    logic rst;
    logic check_redirect_edge;
    logic [31:0] expected_redirect_target;
    logic [31:0] killed_response_pc;
    logic [31:0] killed_response_inst;
    integer redirect_check_count;

    CPU_Sim_Top u_CPU_Top (
        .clk(clk),
        .rst(rst)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("build/cpu_jal.vcd");
        $dumpvars(0, tb_CPU_JAL);
    end

    always @(negedge clk) begin
        check_redirect_edge = !rst && u_CPU_Top.branch_taken;
        if (check_redirect_edge) begin
            if (u_CPU_Top.fetch_response_valid !== 1'b1)
                $fatal(1, "[FAIL] JAL redirect has no valid younger response to kill");
            expected_redirect_target = u_CPU_Top.branch_target;
            killed_response_pc = u_CPU_Top.fetch_response_pc;
            killed_response_inst = u_CPU_Top.fetch_response_inst;
        end
    end

    always @(posedge clk) begin
        #1;
        if (check_redirect_edge) begin
            if (u_CPU_Top.pc !== expected_redirect_target)
                $fatal(1, "[FAIL] JAL redirect did not load target PC");
            if (u_CPU_Top.fetch_response_valid !== 1'b0)
                $fatal(1, "[FAIL] JAL redirect did not invalidate fetch response");
            if (u_CPU_Top.fetch_response_pc !== killed_response_pc ||
                u_CPU_Top.fetch_response_inst !== killed_response_inst)
                $fatal(1, "[FAIL] JAL kill unexpectedly changed response payload");
            if (u_CPU_Top.idex_valid_inst_r !== 1'b0)
                $fatal(1, "[FAIL] JAL redirect did not insert ID/EX bubble");
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
            actual = u_CPU_Top.read_reg(addr);
            if (actual !== expected)
                $fatal(1,
                    "[FAIL] %s: expected x%0d=0x%08h actual=0x%08h",
                    test_name, addr, expected, actual
                );
        end
    endtask

    // JAL is deliberately placed at PC=8.  Its target (PC+12=20) and link
    // value (PC+4=12) are different, catching a shared-value-path mistake.
    task automatic run_forward_link_case;
        begin
            begin_case();

            u_CPU_Top.u_Program_Rom.memory[0] = `I_NOP;
            u_CPU_Top.u_Program_Rom.memory[1] = `I_NOP;
            u_CPU_Top.u_Program_Rom.memory[2] = encode_jal(5'd5, 32'sd12);
            u_CPU_Top.u_Program_Rom.memory[3] = encode_addi(5'd26, 5'd0, 32'sd1);
            u_CPU_Top.u_Program_Rom.memory[4] = encode_addi(5'd27, 5'd0, 32'sd1);
            u_CPU_Top.u_Program_Rom.memory[5] = encode_addi(5'd28, 5'd0, 32'sd7);
            u_CPU_Top.u_Program_Rom.memory[6] = encode_addi(5'd29, 5'd5, 32'sd1);

            repeat (18) @(posedge clk);
            #1;

            check_reg(5'd5,  32'd12, "JAL writes instruction PC+4 to rd");
            check_reg(5'd26, 32'd0,  "JAL flushes first younger instruction");
            check_reg(5'd27, 32'd0,  "JAL flushes second younger instruction");
            check_reg(5'd28, 32'd7,  "JAL executes positive-offset target");
            check_reg(5'd29, 32'd13, "instruction after target reads link register");

            $display("[PASS] JAL forward target, link write-back, and flush");
        end
    endtask

    task automatic run_backward_case;
        logic saw_jal_pc;
        logic returned_to_zero;
        integer cycle;
        begin
            begin_case();

            u_CPU_Top.u_Program_Rom.memory[0] = encode_addi(5'd28, 5'd0, 32'sd9);
            u_CPU_Top.u_Program_Rom.memory[1] = `I_NOP;
            u_CPU_Top.u_Program_Rom.memory[2] = encode_jal(5'd6, -32'sd8);
            u_CPU_Top.u_Program_Rom.memory[3] = encode_addi(5'd26, 5'd0, 32'sd1);
            u_CPU_Top.u_Program_Rom.memory[4] = encode_addi(5'd27, 5'd0, 32'sd1);

            saw_jal_pc = 1'b0;
            returned_to_zero = 1'b0;
            for (cycle = 0; cycle < 18; cycle = cycle + 1) begin
                @(posedge clk);
                #1;
                if (u_CPU_Top.pc == 32'h0000_0008)
                    saw_jal_pc = 1'b1;
                if (saw_jal_pc && u_CPU_Top.pc == 32'h0000_0000)
                    returned_to_zero = 1'b1;
            end

            if (!returned_to_zero)
                $fatal(1, "[FAIL] JAL negative offset did not return from PC=8 to PC=0");

            check_reg(5'd6,  32'd12, "backward JAL writes PC+4 to rd");
            check_reg(5'd26, 32'd0,  "backward JAL flushes first younger instruction");
            check_reg(5'd27, 32'd0,  "backward JAL flushes second younger instruction");
            check_reg(5'd28, 32'd9,  "backward JAL reaches target");

            $display("[PASS] JAL negative offset and backward target");
        end
    endtask

    task automatic run_rd_zero_case;
        begin
            begin_case();

            u_CPU_Top.u_Program_Rom.memory[0] = encode_jal(5'd0, 32'sd12);
            u_CPU_Top.u_Program_Rom.memory[1] = encode_addi(5'd26, 5'd0, 32'sd1);
            u_CPU_Top.u_Program_Rom.memory[2] = encode_addi(5'd27, 5'd0, 32'sd1);
            u_CPU_Top.u_Program_Rom.memory[3] = encode_addi(5'd28, 5'd0, 32'sd11);

            repeat (15) @(posedge clk);
            #1;

            check_reg(5'd0,  32'd0,  "JAL x0 preserves architectural zero");
            check_reg(5'd26, 32'd0,  "JAL x0 still flushes first younger instruction");
            check_reg(5'd27, 32'd0,  "JAL x0 still flushes second younger instruction");
            check_reg(5'd28, 32'd11, "JAL x0 still redirects to target");

            $display("[PASS] JAL with rd=x0");
        end
    endtask

    initial begin
        rst = 1'b1;
        check_redirect_edge = 1'b0;
        redirect_check_count = 0;
        clear_rom();

        // Protect the testbench's own J-immediate bit arrangement.
        if (encode_jal(5'd1, 32'sd16) !== 32'h0100_00EF)
            $fatal(1, "[FAIL] testbench JAL encoder");

        run_forward_link_case();
        run_backward_case();
        run_rd_zero_case();

        if (redirect_check_count < 3)
            $fatal(1, "[FAIL] expected at least 3 JAL redirect checks, observed %0d",
                   redirect_check_count);

        $display("[PASS] tb_CPU_JAL completed: 3 integration scenarios, %0d redirect edge checks.",
                 redirect_check_count);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "[FAIL] tb_CPU_JAL timeout");
    end

endmodule
