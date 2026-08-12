`timescale 1ns / 100ps
`include "defines.sv"

module tb_CPU_Trap;
    logic clk;
    logic rst;
    logic trap_ack;
    logic [31:0] trap_redirect_pc;
    logic trap_valid;
    logic [3:0] trap_cause;
    logic [31:0] trap_pc;
    logic [31:0] trap_tval;
    logic retire_valid;
    logic [31:0] retire_pc;
    logic retire_rd_write;
    logic [4:0] retire_rd;
    logic [31:0] retire_rd_data;
    logic retire_mem_write;
    logic [31:0] forbidden_retire_pc_a;
    logic [31:0] forbidden_retire_pc_b;
    integer scenario;
    integer total_cycles;
    integer trap_event_count;
    logic   trap_valid_d;
    logic   saw_older_retire_a;
    logic   saw_older_retire_b;

    CPU_Sim_Top dut (
        .clk(clk),
        .rst(rst),
        .trap_valid(trap_valid),
        .trap_cause(trap_cause),
        .trap_pc(trap_pc),
        .trap_tval(trap_tval),
        .trap_ack(trap_ack),
        .trap_redirect_pc(trap_redirect_pc),
        .retire_valid(retire_valid),
        .retire_rd_write(retire_rd_write),
        .retire_rd(retire_rd),
        .retire_rd_data(retire_rd_data),
        .retire_mem_write(retire_mem_write),
        .retire_pc(retire_pc)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk) begin
        total_cycles = total_cycles + 1;
        if (total_cycles > 250)
            $fatal(1,
                "[FAIL] global watchdog: scenario=%0d pc=%08h idex_pc=%08h mem_en=%b mem_write=%b addr=%08h misaligned=%b ex_trap=%b pending=%b trap_valid=%b",
                scenario, dut.pc, dut.u_CPU_Core.idex_pc_r,
                dut.u_CPU_Core.mem_en_r, dut.u_CPU_Core.mem_write_r,
                dut.u_CPU_Core.alu_result_, dut.u_CPU_Core.misaligned,
                dut.u_CPU_Core.ex_trap_req_valid,
                dut.u_CPU_Core.trap_pending, trap_valid);

        if (rst) begin
            trap_valid_d <= 1'b0;
        end else begin
            if (trap_valid && !trap_valid_d)
                trap_event_count = trap_event_count + 1;
            trap_valid_d <= trap_valid;
        end

        if (!rst && retire_valid) begin
            if (scenario == 1 && retire_pc == 32'h0000_0000)
                saw_older_retire_a = 1'b1;
            if (scenario == 2 && retire_pc == 32'h0000_0000)
                saw_older_retire_a = 1'b1;
            if (scenario == 2 && retire_pc == 32'h0000_0004)
                saw_older_retire_b = 1'b1;
        end
    end

    function automatic [31:0] encode_addi(
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic signed [31:0] immediate
    );
        encode_addi = {immediate[11:0], rs1, `F_ADDI, rd, `Opcode_I};
    endfunction

    function automatic [31:0] encode_store(
        input logic [2:0] funct3,
        input logic [4:0] rs1,
        input logic [4:0] rs2,
        input logic signed [31:0] immediate
    );
        encode_store = {immediate[11:5], rs2, rs1, funct3,
                        immediate[4:0], `Opcode_STORE};
    endfunction

    task automatic clear_memories;
        integer i;
        begin
            for (i = 0; i < 64; i = i + 1)
                dut.u_Program_Rom.memory[i] = `I_NOP;
            for (i = 0; i < 1024; i = i + 1)
                dut.u_Data_Memory.memory[i] = 32'd0;
        end
    endtask

    task automatic reset_cpu;
        begin
            rst = 1'b1;
            trap_ack = 1'b0;
            trap_redirect_pc = 32'h0000_0010;
            repeat (3) @(posedge clk);
            @(negedge clk);
            rst = 1'b0;
        end
    endtask

    task automatic wait_for_trap(
        input logic [3:0] expected_cause,
        input logic [31:0] expected_pc,
        input logic [31:0] expected_tval
    );
        integer timeout;
        begin
            timeout = 0;
            while (!trap_valid && timeout < 40) begin
                @(posedge clk);
                #1;
                timeout = timeout + 1;
            end
            // $display("test");
            if (!trap_valid)
                $fatal(1, "[FAIL] timeout waiting for trap");
            if (trap_cause !== expected_cause || trap_pc !== expected_pc ||
                trap_tval !== expected_tval)
                $fatal(1, "[FAIL] trap metadata cause=%0d pc=%08h tval=%08h",
                       trap_cause, trap_pc, trap_tval);
            
            // Pending metadata and architectural state must remain stable.
            repeat (2) begin
                @(posedge clk);
                #1;
                if (!trap_valid || trap_cause !== expected_cause ||
                    trap_pc !== expected_pc || trap_tval !== expected_tval)
                    $fatal(1, "[FAIL] pending trap metadata changed");
                // $display("test");
            end
            // $display("test");
        end
    endtask

    task automatic acknowledge_and_run_handler;
        integer timeout;
        begin
            @(negedge clk);
            trap_ack = 1'b1;
            @(posedge clk);
            #1;
            trap_ack = 1'b0;
            if (trap_valid)
                $fatal(1, "[FAIL] trap did not clear after ack");

            timeout = 0;
            while (dut.read_reg(4) !== 32'd44 && timeout < 30) begin
                @(posedge clk);
                #1;
                timeout = timeout + 1;
            end
            if (dut.read_reg(4) !== 32'd44)
                $fatal(1, "[FAIL] handler at redirect PC did not execute");
        end
    endtask

    // At the EX detection boundary, the faulting instruction is already
    // suppressed before the clock edge that captures EX/WB.
    always @(negedge clk) begin
        if (!rst && dut.u_CPU_Core.ex_trap_req_valid) begin
            if (dut.dmem_req_valid)
                $fatal(1, "[FAIL] faulting instruction issued Data Memory request");
            if (dut.u_CPU_Core.effective_ex_valid ||
                dut.u_CPU_Core.effective_ex_reg_write ||
                dut.u_CPU_Core.normal_redirect)
                $fatal(1, "[FAIL] faulting instruction retained an EX side effect");
        end
    end

    always @(posedge clk) begin
        if (!rst && retire_valid && (retire_pc == forbidden_retire_pc_a ||
                                    retire_pc == forbidden_retire_pc_b))
            $fatal(1, "[FAIL] faulting/younger instruction retired at PC %08h",
                   retire_pc);
    end

    initial begin
        rst = 1'b1;
        trap_ack = 1'b0;
        trap_redirect_pc = 32'h0000_0010;
        scenario = 1;
        total_cycles = 0;
        trap_event_count = 0;
        trap_valid_d = 1'b0;
        saw_older_retire_a = 1'b0;
        saw_older_retire_b = 1'b0;
        forbidden_retire_pc_a = 32'h0000_0004;
        forbidden_retire_pc_b = 32'h0000_0008;

        // Scenario 1: an older ADDI commits; illegal and younger instructions
        // do not retire.  Ack redirects to the handler at PC 0x10.
        clear_memories();
        dut.u_Program_Rom.memory[0] = encode_addi(5'd1, 5'd0, 11);
        dut.u_Program_Rom.memory[1] = 32'hFFFF_FFFF;
        dut.u_Program_Rom.memory[2] = encode_addi(5'd2, 5'd0, 22);
        dut.u_Program_Rom.memory[4] = encode_addi(5'd4, 5'd0, 44);
        reset_cpu();
        wait_for_trap(`TRAP_ILLEGAL_INSTRUCTION, 32'h0000_0004,
                      32'hFFFF_FFFF);
        if (dut.read_reg(1) !== 32'd11 || dut.read_reg(2) !== 32'd0)
            $fatal(1, "[FAIL] precise ordering around illegal trap");
        if (!saw_older_retire_a)
            $fatal(1, "[FAIL] older instruction did not retire before illegal trap");
        if (trap_event_count !== 1)
            $fatal(1, "[FAIL] illegal fault produced %0d trap events",
                   trap_event_count);
        acknowledge_and_run_handler();
        repeat (3) @(posedge clk);
        #1;
        if (trap_event_count !== 1)
            $fatal(1, "[FAIL] illegal trap reasserted after ack");
        $display("[PASS] illegal trap preserves older and kills younger instruction");

        // Scenario 2: a misaligned Store must not reach memory or retire.
        @(negedge clk);
        clear_memories();
        dut.u_Data_Memory.memory[0] = 32'hDEAD_BEEF;
        dut.u_Program_Rom.memory[0] = encode_addi(5'd1, 5'd0, 0);
        dut.u_Program_Rom.memory[1] = encode_addi(5'd2, 5'd0, 8'h55);
        dut.u_Program_Rom.memory[2] = encode_store(`F3_SW, 5'd1, 5'd2, 2);
        dut.u_Program_Rom.memory[3] = encode_addi(5'd3, 5'd0, 33);
        dut.u_Program_Rom.memory[4] = encode_addi(5'd4, 5'd0, 44);
        forbidden_retire_pc_a = 32'h0000_0008;
        forbidden_retire_pc_b = 32'h0000_000C;
        scenario = 2;
        saw_older_retire_a = 1'b0;
        saw_older_retire_b = 1'b0;
        reset_cpu();
        // $display("reset complete");
        wait_for_trap(`TRAP_STORE_ADDR_MISALIGNED, 32'h0000_0008,
                      32'h0000_0002);
        // $display("test");
        if (dut.u_Data_Memory.memory[0] !== 32'hDEAD_BEEF ||
            dut.read_reg(3) !== 32'd0)
            $fatal(1, "[FAIL] Store trap allowed memory/younger side effect");
        if (!saw_older_retire_a || !saw_older_retire_b)
            $fatal(1, "[FAIL] older instructions did not retire before Store trap");
        if (trap_event_count !== 2)
            $fatal(1, "[FAIL] Store fault did not produce exactly one new trap event");
        // $display("test");
        acknowledge_and_run_handler();
        repeat (3) @(posedge clk);
        #1;
        if (trap_event_count !== 2)
            $fatal(1, "[FAIL] Store trap reasserted after ack");
        $display("[PASS] Store trap blocks memory request and resumes at handler");

        $display("[PASS] tb_CPU_Trap completed.");
        $finish;
    end
endmodule
