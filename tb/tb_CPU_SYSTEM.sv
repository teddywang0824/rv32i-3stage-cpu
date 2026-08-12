`timescale 1ns / 100ps
`include "defines.sv"

module tb_CPU_SYSTEM;
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
    logic retire_mem_write;

    integer cycles;
    integer trap_event_count;
    integer retire_count;
    integer dmem_request_count;
    logic trap_valid_d;
    logic [31:0] expected_retire_pc [0:3];

    localparam logic [31:0] RESERVED_SYSTEM = 32'h0020_0073;

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
        .retire_pc(retire_pc),
        .retire_rd_write(retire_rd_write),
        .retire_mem_write(retire_mem_write)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    function automatic [31:0] encode_addi(
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic signed [31:0] immediate
    );
        encode_addi = {immediate[11:0], rs1, `F_ADDI, rd, `Opcode_I};
    endfunction

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
            if (!trap_valid)
                $fatal(1, "[FAIL] timeout waiting for SYSTEM trap");
            if (trap_cause !== expected_cause || trap_pc !== expected_pc ||
                trap_tval !== expected_tval)
                $fatal(1,
                    "[FAIL] SYSTEM metadata cause=%0d pc=%08h tval=%08h",
                    trap_cause, trap_pc, trap_tval);

            // Holding ack low must preserve one stable pending event.
            repeat (2) begin
                @(posedge clk);
                #1;
                if (!trap_valid || trap_cause !== expected_cause ||
                    trap_pc !== expected_pc || trap_tval !== expected_tval)
                    $fatal(1, "[FAIL] pending SYSTEM metadata changed");
            end
        end
    endtask

    task automatic acknowledge_to(input logic [31:0] redirect_pc);
        begin
            @(negedge clk);
            trap_redirect_pc = redirect_pc;
            trap_ack = 1'b1;
            @(posedge clk);
            #1;
            trap_ack = 1'b0;
            if (trap_valid)
                $fatal(1, "[FAIL] SYSTEM trap did not clear after ack");
        end
    endtask

    always @(posedge clk) begin
        if (rst) begin
            trap_valid_d <= 1'b0;
        end else begin
            cycles = cycles + 1;
            if (cycles > 150)
                $fatal(1, "[FAIL] SYSTEM integration timeout");

            if (trap_valid && !trap_valid_d)
                trap_event_count = trap_event_count + 1;
            trap_valid_d <= trap_valid;

            if (dut.dmem_req_valid)
                dmem_request_count = dmem_request_count + 1;

            if (retire_valid) begin
                if (retire_pc == 32'h0000_0004 ||
                    retire_pc == 32'h0000_000C ||
                    retire_pc == 32'h0000_0014)
                    $fatal(1, "[FAIL] faulting SYSTEM instruction retired");
                if (retire_rd_write && retire_mem_write)
                    $fatal(1, "[FAIL] impossible mixed retire side effect");

                if (retire_count < 4) begin
                    if (retire_pc !== expected_retire_pc[retire_count])
                        $fatal(1, "[FAIL] retire order index=%0d pc=%08h",
                               retire_count, retire_pc);
                    retire_count = retire_count + 1;
                end
            end
        end
    end

    initial begin
        integer i;
        rst = 1'b1;
        trap_ack = 1'b0;
        trap_redirect_pc = 32'd0;
        cycles = 0;
        trap_event_count = 0;
        retire_count = 0;
        dmem_request_count = 0;
        trap_valid_d = 1'b0;

        expected_retire_pc[0] = 32'h0000_0000;
        expected_retire_pc[1] = 32'h0000_0008;
        expected_retire_pc[2] = 32'h0000_0010;
        expected_retire_pc[3] = 32'h0000_0018;

        for (i = 0; i < 64; i = i + 1)
            dut.u_Program_Rom.memory[i] = `I_NOP;
        for (i = 0; i < 1024; i = i + 1)
            dut.u_Data_Memory.memory[i] = 32'd0;

        dut.u_Program_Rom.memory[0] = encode_addi(5'd1, 5'd0, 1);
        dut.u_Program_Rom.memory[1] = `I_ECALL;
        dut.u_Program_Rom.memory[2] = encode_addi(5'd2, 5'd0, 2);
        dut.u_Program_Rom.memory[3] = `I_EBREAK;
        dut.u_Program_Rom.memory[4] = encode_addi(5'd3, 5'd0, 3);
        dut.u_Program_Rom.memory[5] = RESERVED_SYSTEM;
        dut.u_Program_Rom.memory[6] = encode_addi(5'd4, 5'd0, 4);

        repeat (3) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        wait_for_trap(`TRAP_ENV_CALL, 32'h0000_0004, 32'd0);
        if (dut.read_reg(1) !== 32'd1 || dut.read_reg(2) !== 32'd0)
            $fatal(1, "[FAIL] ECALL did not preserve precise ordering");
        if (trap_event_count !== 1)
            $fatal(1, "[FAIL] ECALL produced %0d events", trap_event_count);
        acknowledge_to(32'h0000_0008);

        wait_for_trap(`TRAP_BREAKPOINT, 32'h0000_000C, 32'd0);
        if (dut.read_reg(2) !== 32'd2 || dut.read_reg(3) !== 32'd0)
            $fatal(1, "[FAIL] EBREAK did not preserve precise ordering");
        if (trap_event_count !== 2)
            $fatal(1, "[FAIL] EBREAK did not produce one new event");
        acknowledge_to(32'h0000_0010);

        wait_for_trap(`TRAP_ILLEGAL_INSTRUCTION, 32'h0000_0014,
                      RESERVED_SYSTEM);
        if (dut.read_reg(3) !== 32'd3 || dut.read_reg(4) !== 32'd0)
            $fatal(1, "[FAIL] reserved SYSTEM did not preserve ordering");
        if (trap_event_count !== 3)
            $fatal(1, "[FAIL] reserved SYSTEM did not produce one event");
        acknowledge_to(32'h0000_0018);

        wait (retire_count == 4);
        @(posedge clk);
        #1;
        if (dut.read_reg(4) !== 32'd4)
            $fatal(1, "[FAIL] post-trap redirect instruction did not execute");
        if (dmem_request_count !== 0)
            $fatal(1, "[FAIL] SYSTEM program issued Data Memory requests");
        if (trap_event_count !== 3)
            $fatal(1, "[FAIL] a SYSTEM trap reasserted after ack");

        $display("[PASS] tb_CPU_SYSTEM completed: ECALL, EBREAK, and reserved SYSTEM precise traps.");
        $finish;
    end
endmodule
