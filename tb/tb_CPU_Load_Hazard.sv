`timescale 1ns / 100ps
`include "defines.sv"

module tb_CPU_Load_Hazard;

    logic clk;
    logic rst;
    integer stall_count;
    integer stall_hold_check_count;
    logic check_stall_hold;
    logic [31:0] stalled_pc;
    logic [31:0] stalled_response_pc;
    logic [31:0] stalled_response_inst;
    logic stalled_response_valid;

    CPU_Sim_Top u_CPU_Top (
        .clk(clk),
        .rst(rst)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("build/cpu_load_hazard.vcd");
        $dumpvars(0, tb_CPU_Load_Hazard);
    end

    always @(posedge clk) begin
        if (rst)
            stall_count <= 0;
        else if (u_CPU_Top.load_use_stall)
            stall_count <= stall_count + 1;
    end

    // Snapshot the complete fetch transaction before a stalled rising edge.
    // After that edge, the PC and response must still be identical while
    // ID/EX receives a bubble.
    always @(negedge clk) begin
        check_stall_hold = !rst && u_CPU_Top.load_use_stall;
        if (check_stall_hold) begin
            stalled_pc = u_CPU_Top.pc;
            stalled_response_pc = u_CPU_Top.fetch_response_pc;
            stalled_response_inst = u_CPU_Top.fetch_response_inst;
            stalled_response_valid = u_CPU_Top.fetch_response_valid;
        end
    end

    always @(posedge clk) begin
        #1;
        if (check_stall_hold) begin
            if (u_CPU_Top.pc !== stalled_pc)
                $fatal(1, "[FAIL] load-use stall did not hold PC");
            if (u_CPU_Top.fetch_response_valid !== stalled_response_valid ||
                u_CPU_Top.fetch_response_pc !== stalled_response_pc ||
                u_CPU_Top.fetch_response_inst !== stalled_response_inst)
                $fatal(1, "[FAIL] load-use stall did not hold complete fetch response");
            if (u_CPU_Top.idex_valid_inst_r !== 1'b0)
                $fatal(1, "[FAIL] load-use stall did not insert ID/EX bubble");

            stall_hold_check_count = stall_hold_check_count + 1;
        end
    end

    function automatic logic [31:0] encode_addi(
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic signed [31:0] immediate
    );
        encode_addi = {immediate[11:0], rs1, 3'b000, rd, `Opcode_I};
    endfunction

    function automatic logic [31:0] encode_add(
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic [4:0] rs2
    );
        encode_add = {7'b0000000, rs2, rs1, 3'b000, rd, `Opcode_R_M};
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
            encode_store = {
                imm[11:5], rs2, rs1, funct3, imm[4:0], `Opcode_STORE
            };
        end
    endfunction

    function automatic logic [31:0] encode_beq(
        input logic [4:0] rs1,
        input logic [4:0] rs2,
        input logic signed [31:0] offset
    );
        logic [12:0] imm;
        begin
            imm = offset[12:0];
            encode_beq = {
                imm[12], imm[10:5], rs2, rs1, `F3_BEQ,
                imm[4:1], imm[11], `Opcode_BRANCH
            };
        end
    endfunction

    function automatic logic [31:0] encode_jalr(
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic signed [31:0] immediate
    );
        encode_jalr = {immediate[11:0], rs1, `F3_JALR, rd, `Opcode_JALR};
    endfunction

    function automatic logic [31:0] encode_lui(
        input logic [4:0] rd,
        input logic [19:0] upper_immediate
    );
        encode_lui = {upper_immediate, rd, `Opcode_LUI};
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
            actual = u_CPU_Top.read_reg(reg_index);
            if (actual !== expected)
                $fatal(1,
                    "[FAIL] %s: x%0d expected=0x%08h actual=0x%08h",
                    test_name, reg_index, expected, actual
                );
        end
    endtask

    task automatic check_stalls(
        input integer expected,
        input string test_name
    );
        begin
            if (stall_count !== expected)
                $fatal(1,
                    "[FAIL] %s: expected stalls=%0d actual=%0d",
                    test_name, expected, stall_count
                );
        end
    endtask

    task automatic run_rs1_consumer;
        begin
            begin_case();
            u_CPU_Top.u_Data_Memory.memory[0] = 32'd10;
            u_CPU_Top.u_Program_Rom.memory[0] =
                encode_load(`F3_LW, 5'd1, 5'd0, 32'sd0);
            u_CPU_Top.u_Program_Rom.memory[1] =
                encode_addi(5'd2, 5'd1, 32'sd5);

            repeat (13) @(posedge clk);
            #1;
            check_reg(5'd1, 32'd10, "Load writes producer rd");
            check_reg(5'd2, 32'd15, "Load-to-ADDI forwards after stall");
            check_stalls(1, "Load-to-ADDI stalls exactly once");
            $display("[PASS] CPU load-use rs1 consumer");
        end
    endtask

    task automatic run_both_source_consumer;
        begin
            begin_case();
            u_CPU_Top.u_Data_Memory.memory[1] = 32'd7;
            u_CPU_Top.u_Program_Rom.memory[0] =
                encode_load(`F3_LW, 5'd3, 5'd0, 32'sd4);
            u_CPU_Top.u_Program_Rom.memory[1] =
                encode_add(5'd4, 5'd3, 5'd3);

            repeat (13) @(posedge clk);
            #1;
            check_reg(5'd4, 32'd14, "Load-to-ADD supplies both operands");
            check_stalls(1, "Dual-source match still stalls one cycle");
            $display("[PASS] CPU load-use dual-source R-type consumer");
        end
    endtask

    task automatic run_store_consumers;
        begin
            begin_case();
            u_CPU_Top.write_reg(7, 32'h1122_3344);
            u_CPU_Top.u_Data_Memory.memory[0] = 32'hAABB_CCDD;
            u_CPU_Top.u_Data_Memory.memory[3] = 32'd16;

            // First dependency uses the loaded value as Store rs2 data.
            u_CPU_Top.u_Program_Rom.memory[0] =
                encode_load(`F3_LW, 5'd5, 5'd0, 32'sd0);
            u_CPU_Top.u_Program_Rom.memory[1] =
                encode_store(`F3_SW, 5'd0, 5'd5, 32'sd8);
            // Second dependency uses the loaded value as Store rs1 address.
            u_CPU_Top.u_Program_Rom.memory[2] =
                encode_load(`F3_LW, 5'd6, 5'd0, 32'sd12);
            u_CPU_Top.u_Program_Rom.memory[3] =
                encode_store(`F3_SW, 5'd6, 5'd7, 32'sd0);

            repeat (18) @(posedge clk);
            #1;
            if (u_CPU_Top.u_Data_Memory.memory[2] !== 32'hAABB_CCDD)
                $fatal(1, "[FAIL] Load-to-Store rs2 data dependency");
            if (u_CPU_Top.u_Data_Memory.memory[4] !== 32'h1122_3344)
                $fatal(1, "[FAIL] Load-to-Store rs1 address dependency");
            check_stalls(2, "Two independent Load-to-Store hazards stall once each");
            $display("[PASS] CPU load-use Store address/data consumers");
        end
    endtask

    task automatic run_branch_consumer;
        begin
            begin_case();
            u_CPU_Top.write_reg(9, 32'd1);
            u_CPU_Top.u_Data_Memory.memory[0] = 32'd1;

            u_CPU_Top.u_Program_Rom.memory[0] =
                encode_load(`F3_LW, 5'd8, 5'd0, 32'sd0);
            // Branch at PC=4 targets PC=16 and must use the loaded x8.
            u_CPU_Top.u_Program_Rom.memory[1] =
                encode_beq(5'd8, 5'd9, 32'sd12);
            u_CPU_Top.u_Program_Rom.memory[2] = encode_addi(5'd10, 5'd0, 32'sd10);
            u_CPU_Top.u_Program_Rom.memory[3] = encode_addi(5'd11, 5'd0, 32'sd11);
            u_CPU_Top.u_Program_Rom.memory[4] = encode_addi(5'd12, 5'd0, 32'sd12);

            repeat (18) @(posedge clk);
            #1;
            check_reg(5'd10, 32'd0, "taken Branch flushes first wrong path");
            check_reg(5'd11, 32'd0, "taken Branch flushes second wrong path");
            check_reg(5'd12, 32'd12, "Branch target executes");
            check_stalls(1, "Load-to-Branch stalls exactly once");
            $display("[PASS] CPU load-use Branch consumer and flush");
        end
    endtask

    task automatic run_jalr_consumer;
        begin
            begin_case();
            u_CPU_Top.u_Data_Memory.memory[0] = 32'd16;

            u_CPU_Top.u_Program_Rom.memory[0] =
                encode_load(`F3_LW, 5'd13, 5'd0, 32'sd0);
            u_CPU_Top.u_Program_Rom.memory[1] = encode_jalr(5'd14, 5'd13, 32'sd0);
            u_CPU_Top.u_Program_Rom.memory[2] = encode_addi(5'd15, 5'd0, 32'sd15);
            u_CPU_Top.u_Program_Rom.memory[3] = encode_addi(5'd16, 5'd0, 32'sd16);
            u_CPU_Top.u_Program_Rom.memory[4] = encode_addi(5'd17, 5'd0, 32'sd17);

            repeat (18) @(posedge clk);
            #1;
            check_reg(5'd14, 32'd8, "JALR link is instruction PC plus four");
            check_reg(5'd15, 32'd0, "JALR flushes first wrong path");
            check_reg(5'd16, 32'd0, "JALR flushes second wrong path");
            check_reg(5'd17, 32'd17, "JALR loaded target executes");
            check_stalls(1, "Load-to-JALR stalls exactly once");
            $display("[PASS] CPU load-use JALR target consumer");
        end
    endtask

    task automatic run_false_dependency_cases;
        begin
            begin_case();
            u_CPU_Top.u_Data_Memory.memory[0] = 32'h1111_1111;
            u_CPU_Top.u_Data_Memory.memory[1] = 32'h2222_2222;

            // upper_immediate=0x00090 makes inst[19:15] equal 18, but LUI
            // does not consume rs1 and therefore must not stall behind x18.
            u_CPU_Top.u_Program_Rom.memory[0] =
                encode_load(`F3_LW, 5'd18, 5'd0, 32'sd0);
            u_CPU_Top.u_Program_Rom.memory[1] = encode_lui(5'd19, 20'h00090);
            // ADDI immediate 20 makes inst[24:20] equal 20, but that field is
            // not an rs2 source for I-type instructions.
            u_CPU_Top.u_Program_Rom.memory[2] =
                encode_load(`F3_LW, 5'd20, 5'd0, 32'sd4);
            u_CPU_Top.u_Program_Rom.memory[3] = encode_addi(5'd21, 5'd0, 32'sd20);
            // A Load targeting x0 must never create a dependency.
            u_CPU_Top.u_Program_Rom.memory[4] =
                encode_load(`F3_LW, 5'd0, 5'd0, 32'sd0);
            u_CPU_Top.u_Program_Rom.memory[5] = encode_addi(5'd25, 5'd0, 32'sd9);

            repeat (18) @(posedge clk);
            #1;
            check_reg(5'd18, 32'h1111_1111, "first false-dependency Load completes");
            check_reg(5'd19, 32'h0009_0000, "LUI ignores encoded rs fields");
            check_reg(5'd20, 32'h2222_2222, "second false-dependency Load completes");
            check_reg(5'd21, 32'd20, "I-type immediate is not rs2");
            check_reg(5'd25, 32'd9, "Load to x0 does not stall following instruction");
            check_stalls(0, "Unused encoded fields and x0 produce no false stall");
            $display("[PASS] CPU load-use false-dependency suppression");
        end
    endtask

    task automatic run_one_instruction_gap;
        begin
            begin_case();
            u_CPU_Top.u_Data_Memory.memory[0] = 32'd30;
            u_CPU_Top.u_Program_Rom.memory[0] =
                encode_load(`F3_LW, 5'd22, 5'd0, 32'sd0);
            u_CPU_Top.u_Program_Rom.memory[1] = encode_addi(5'd23, 5'd0, 32'sd5);
            u_CPU_Top.u_Program_Rom.memory[2] = encode_addi(5'd24, 5'd22, 32'sd1);

            repeat (14) @(posedge clk);
            #1;
            check_reg(5'd23, 32'd5, "independent gap instruction executes");
            check_reg(5'd24, 32'd31, "WB forwarding handles dependency after one gap");
            check_stalls(0, "Dependency after one gap needs no stall");
            $display("[PASS] CPU Load dependency after one instruction gap");
        end
    endtask

    initial begin
        rst = 1'b1;
        stall_count = 0;
        stall_hold_check_count = 0;
        check_stall_hold = 1'b0;
        clear_rom_and_data();

        run_rs1_consumer();
        run_both_source_consumer();
        run_store_consumers();
        run_branch_consumer();
        run_jalr_consumer();
        run_false_dependency_cases();
        run_one_instruction_gap();

        if (stall_hold_check_count !== 6)
            $fatal(1,
                "[FAIL] expected 6 cycle-level stall-hold checks, observed %0d",
                stall_hold_check_count
            );

        $display("[PASS] tb_CPU_Load_Hazard completed: 7 integration scenarios, 6 stall-hold checks.");
        $finish;
    end

    initial begin
        #25000;
        $fatal(1, "[FAIL] tb_CPU_Load_Hazard timeout");
    end

endmodule
