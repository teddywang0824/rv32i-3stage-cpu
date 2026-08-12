`timescale 1ns / 100ps
`include "defines.sv"

module tb_CPU_Branch;

    logic clk;
    logic rst;
    logic check_redirect_edge;
    logic [31:0] expected_redirect_target;
    logic [31:0] killed_response_pc;
    logic [31:0] killed_response_inst;
    integer redirect_check_count;

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
        $dumpfile("build/cpu_branch.vcd");
        $dumpvars(0, tb_CPU_Branch);
    end

    // Snapshot a taken redirect before the active edge.  The synchronous
    // instruction response must be invalidated at that edge while its stale
    // payload remains unchanged and ID/EX receives a bubble.
    always @(negedge clk) begin
        check_redirect_edge = !rst && u_CPU_Top.branch_taken;
        if (check_redirect_edge) begin
            if (u_CPU_Top.fetch_response_valid !== 1'b1)
                $fatal(1, "[FAIL] taken Branch has no valid younger response to kill");

            expected_redirect_target = u_CPU_Top.branch_target;
            killed_response_pc = u_CPU_Top.fetch_response_pc;
            killed_response_inst = u_CPU_Top.fetch_response_inst;
        end
    end

    always @(posedge clk) begin
        #1;
        if (check_redirect_edge) begin
            if (u_CPU_Top.pc !== expected_redirect_target)
                $fatal(1,
                    "[FAIL] redirect PC: expected=0x%08h actual=0x%08h",
                    expected_redirect_target, u_CPU_Top.pc
                );
            if (u_CPU_Top.fetch_response_valid !== 1'b0)
                $fatal(1, "[FAIL] taken Branch did not invalidate fetch response");
            if (u_CPU_Top.fetch_response_pc !== killed_response_pc ||
                u_CPU_Top.fetch_response_inst !== killed_response_inst)
                $fatal(1, "[FAIL] kill_response unexpectedly changed response payload");
            if (u_CPU_Top.idex_valid_inst_r !== 1'b0)
                $fatal(1, "[FAIL] taken Branch did not insert ID/EX bubble");

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

    function automatic logic [31:0] encode_branch(
        input logic [2:0] funct3,
        input logic [4:0] rs1,
        input logic [4:0] rs2,
        input logic signed [31:0] offset
    );
        logic [12:0] imm;
        begin
            imm = offset[12:0];
            encode_branch = {
                imm[12], imm[10:5], rs2, rs1, funct3,
                imm[4:1], imm[11], `Opcode_BRANCH
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

    task automatic begin_case(
        input logic [31:0] lhs,
        input logic [31:0] rhs
    );
        begin
            @(negedge clk);
            rst = 1'b1;
            clear_rom();

            // 讓 Register File、PC、IF/ID、ID/EX 與啟動 Controller 完整 reset。
            repeat (3) @(posedge clk);
            @(negedge clk);
            rst = 1'b0;

            // Branch operands 在每個案例中保持不變；不讓 setup 指令與 branch
            // forwarding 混在同一個測試目的中。
            u_CPU_Top.write_reg(1, lhs);
            u_CPU_Top.write_reg(2, rhs);
        end
    endtask

    task automatic check_wrong_path_registers(
        input logic expected_to_execute,
        input string test_name
    );
        logic [31:0] expected;
        begin
            expected = expected_to_execute ? 32'd1 : 32'd0;

            if (u_CPU_Top.read_reg(26) !== expected)
                $fatal(1,
                    "[FAIL] %s first younger instruction: expected x26=%0d actual=%0d",
                    test_name, expected, u_CPU_Top.read_reg(26)
                );

            if (u_CPU_Top.read_reg(27) !== expected)
                $fatal(1,
                    "[FAIL] %s second younger instruction: expected x27=%0d actual=%0d",
                    test_name, expected, u_CPU_Top.read_reg(27)
                );
        end
    endtask

    // PC=0 的 branch 向前跳到 PC=12。
    // PC=4 與 PC=8 是 branch 在 EX stage 決定時已進入管線的兩條指令；
    // taken 時兩者都必須被 flush，not-taken 時兩者都必須執行。
    task automatic run_forward_case(
        input logic [2:0] funct3,
        input logic [31:0] lhs,
        input logic [31:0] rhs,
        input logic expected_taken,
        input string test_name
    );
        begin
            begin_case(lhs, rhs);

            u_CPU_Top.u_Program_Rom.memory[0] =
                encode_branch(funct3, 5'd1, 5'd2, 32'sd12);
            u_CPU_Top.u_Program_Rom.memory[1] =
                encode_addi(5'd26, 5'd0, 32'sd1);
            u_CPU_Top.u_Program_Rom.memory[2] =
                encode_addi(5'd27, 5'd0, 32'sd1);
            u_CPU_Top.u_Program_Rom.memory[3] =
                encode_addi(5'd28, 5'd0, 32'sd7);

            repeat (16) @(posedge clk);
            #1;

            check_wrong_path_registers(!expected_taken, test_name);

            if (u_CPU_Top.read_reg(28) !== 32'd7)
                $fatal(1,
                    "[FAIL] %s forward target PC=12 was not executed",
                    test_name
                );

            $display("[PASS] %s (forward, taken=%0d)",
                     test_name, expected_taken);
        end
    endtask

    // PC=8 的 branch 使用 offset=-8，target 是 PC=0。
    // taken 時必須真的重新看到 PC=0，且 PC=12/16 的兩條 younger 指令
    // 不得寫回；not-taken 時則不可回到 PC=0，並應依序執行兩條指令。
    task automatic run_backward_case(
        input logic [2:0] funct3,
        input logic [31:0] lhs,
        input logic [31:0] rhs,
        input logic expected_taken,
        input string test_name
    );
        logic saw_branch_pc;
        logic returned_to_zero;
        integer cycle;
        begin
            begin_case(lhs, rhs);

            u_CPU_Top.u_Program_Rom.memory[0] = `I_NOP;
            u_CPU_Top.u_Program_Rom.memory[1] = `I_NOP;
            u_CPU_Top.u_Program_Rom.memory[2] =
                encode_branch(funct3, 5'd1, 5'd2, -32'sd8);
            u_CPU_Top.u_Program_Rom.memory[3] =
                encode_addi(5'd26, 5'd0, 32'sd1);
            u_CPU_Top.u_Program_Rom.memory[4] =
                encode_addi(5'd27, 5'd0, 32'sd1);

            saw_branch_pc = 1'b0;
            returned_to_zero = 1'b0;

            for (cycle = 0; cycle < 20; cycle = cycle + 1) begin
                @(posedge clk);
                #1;
                if (u_CPU_Top.pc == 32'h0000_0008)
                    saw_branch_pc = 1'b1;
                if (saw_branch_pc && u_CPU_Top.pc == 32'h0000_0000)
                    returned_to_zero = 1'b1;
            end

            if (returned_to_zero !== expected_taken)
                $fatal(1,
                    "[FAIL] %s backward target: expected taken=%0d observed return=%0d",
                    test_name, expected_taken, returned_to_zero
                );

            check_wrong_path_registers(!expected_taken, test_name);

            $display("[PASS] %s (backward, taken=%0d)",
                     test_name, expected_taken);
        end
    endtask

    task automatic run_four_directions(
        input logic [2:0] funct3,
        input logic [31:0] taken_lhs,
        input logic [31:0] taken_rhs,
        input logic [31:0] not_taken_lhs,
        input logic [31:0] not_taken_rhs,
        input string mnemonic
    );
        begin
            run_forward_case(funct3, taken_lhs, taken_rhs, 1'b1,
                             {mnemonic, " taken"});
            run_forward_case(funct3, not_taken_lhs, not_taken_rhs, 1'b0,
                             {mnemonic, " not-taken"});
            run_backward_case(funct3, taken_lhs, taken_rhs, 1'b1,
                              {mnemonic, " taken"});
            run_backward_case(funct3, not_taken_lhs, not_taken_rhs, 1'b0,
                              {mnemonic, " not-taken"});
        end
    endtask

    initial begin
        rst = 1'b1;
        check_redirect_edge = 1'b0;
        redirect_check_count = 0;
        clear_rom();

        // 先用兩個已知 machine code 保護 testbench 自己的 B-immediate 排列。
        if (encode_branch(3'b000, 5'd1, 5'd2, 32'sd12) !== 32'h0020_8663)
            $fatal(1, "[FAIL] testbench forward branch encoder");
        if (encode_branch(3'b000, 5'd1, 5'd2, -32'sd8) !== 32'hFE20_8CE3)
            $fatal(1, "[FAIL] testbench backward branch encoder");

        // BEQ / BNE
        run_four_directions(3'b000,
            32'd5, 32'd5, 32'd5, 32'd6, "BEQ");
        run_four_directions(3'b001,
            32'd5, 32'd6, 32'd5, 32'd5, "BNE");

        // BLT / BGE 必須使用 signed comparison。
        run_four_directions(3'b100,
            32'hFFFF_FFFF, 32'd1, 32'd1, 32'hFFFF_FFFF, "BLT");
        run_four_directions(3'b101,
            32'd1, 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'd1, "BGE");

        // BLTU / BGEU 使用相同 bit patterns，但必須視為 unsigned。
        run_four_directions(3'b110,
            32'd1, 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'd1, "BLTU");
        run_four_directions(3'b111,
            32'hFFFF_FFFF, 32'd1, 32'd1, 32'hFFFF_FFFF, "BGEU");

        if (redirect_check_count < 12)
            $fatal(1,
                "[FAIL] expected at least 12 taken redirect edge checks, observed %0d",
                redirect_check_count
            );

        $display("[PASS] tb_CPU_Branch completed: 24 branch scenarios, %0d redirect edge checks.",
                 redirect_check_count);
        $finish;
    end

    initial begin
        #20000;
        $fatal(1, "[FAIL] tb_CPU_Branch timeout");
    end

endmodule
