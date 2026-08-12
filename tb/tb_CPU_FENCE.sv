`timescale 1ns / 100ps
`include "defines.sv"

module tb_CPU_FENCE;
    logic clk;
    logic rst;
    logic trap_valid;
    logic [3:0] trap_cause;
    logic [31:0] trap_pc;
    logic [31:0] trap_tval;
    logic retire_valid;
    logic [31:0] retire_pc;
    logic [31:0] retire_inst;
    logic retire_rd_write;
    logic retire_mem_write;

    wire trap_ack = trap_valid;
    wire [31:0] trap_redirect_pc = trap_pc + 32'd4;

    integer cycles;
    integer retire_count;
    integer fence_decode_count;
    integer fence_retire_count;
    integer dmem_request_count;
    integer trap_count;
    logic [31:0] expected_retire_pc [0:6];

    localparam logic [31:0] FENCE_A = 32'h0FF0_000F;
    // Non-zero rd/rs1 fields are reserved for future finer-grain use and are
    // ignored by the base FENCE implementation.  They must not form hazards.
    localparam logic [31:0] FENCE_B = {12'hA55, 5'd5, `F3_FENCE,
                                       5'd5, `Opcode_MISC_MEM};
    localparam logic [31:0] RESERVED_MISC = {12'h000, 5'd0, 3'b001,
                                             5'd0, `Opcode_MISC_MEM};

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
        .retire_inst(retire_inst),
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

    function automatic [31:0] encode_load(
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic signed [31:0] immediate
    );
        encode_load = {immediate[11:0], rs1, `F3_LW, rd, `Opcode_LOAD};
    endfunction

    function automatic [31:0] encode_store(
        input logic [4:0] rs1,
        input logic [4:0] rs2,
        input logic signed [31:0] immediate
    );
        encode_store = {immediate[11:5], rs2, rs1, `F3_SW,
                        immediate[4:0], `Opcode_STORE};
    endfunction

    always @(posedge clk) begin
        if (!rst) begin
            cycles = cycles + 1;
            if (cycles > 100)
                $fatal(1, "[FAIL] FENCE integration timeout");

            if (dut.dmem_req_valid)
                dmem_request_count = dmem_request_count + 1;

            if (dut.fetch_response_valid &&
                dut.fetch_response_inst[6:0] == `Opcode_MISC_MEM &&
                dut.fetch_response_inst[14:12] == `F3_FENCE) begin
                fence_decode_count = fence_decode_count + 1;
                if (!dut.valid_inst_ || dut.reg_write_ || dut.mem_en ||
                    dut.mem_write || dut.branch_en_ || dut.jump_op_ ||
                    dut.id_uses_rs1 || dut.id_uses_rs2)
                    $fatal(1, "[FAIL] FENCE decode has a side effect/dependency");
                if (dut.u_CPU_Core.stall_)
                    $fatal(1, "[FAIL] FENCE caused a false load-use stall");
            end

            if (retire_valid) begin
                if (retire_inst[6:0] == `Opcode_MISC_MEM) begin
                    fence_retire_count = fence_retire_count + 1;
                    if (retire_rd_write || retire_mem_write)
                        $fatal(1, "[FAIL] FENCE retired with a side effect");
                end

                // The ROM is filled with legal NOPs after the test program;
                // only the first seven architectural events form the expected
                // sequence under test.
                if (retire_count < 7) begin
                    if (retire_pc !== expected_retire_pc[retire_count])
                        $fatal(1, "[FAIL] retire order index=%0d pc=%08h",
                               retire_count, retire_pc);
                    retire_count = retire_count + 1;
                end
            end

            if (trap_valid) begin
                trap_count = trap_count + 1;
                if (trap_count != 1 ||
                    trap_cause !== `TRAP_ILLEGAL_INSTRUCTION ||
                    trap_pc !== 32'h0000_0018 ||
                    trap_tval !== RESERVED_MISC)
                    $fatal(1, "[FAIL] reserved MISC-MEM trap metadata");
            end
        end
    end

    initial begin
        integer i;
        rst = 1'b1;
        cycles = 0;
        retire_count = 0;
        fence_decode_count = 0;
        fence_retire_count = 0;
        dmem_request_count = 0;
        trap_count = 0;

        expected_retire_pc[0] = 32'h0000_0000;
        expected_retire_pc[1] = 32'h0000_0004;
        expected_retire_pc[2] = 32'h0000_0008;
        expected_retire_pc[3] = 32'h0000_000C;
        expected_retire_pc[4] = 32'h0000_0010;
        expected_retire_pc[5] = 32'h0000_0014;
        expected_retire_pc[6] = 32'h0000_001C;

        for (i = 0; i < 64; i = i + 1)
            dut.u_Program_Rom.memory[i] = `I_NOP;
        for (i = 0; i < 1024; i = i + 1)
            dut.u_Data_Memory.memory[i] = 32'd0;

        dut.u_Program_Rom.memory[0] = encode_addi(5'd1, 5'd0, 42);
        dut.u_Program_Rom.memory[1] = encode_store(5'd0, 5'd1, 0);
        dut.u_Program_Rom.memory[2] = FENCE_A;
        dut.u_Program_Rom.memory[3] = encode_load(5'd5, 5'd0, 0);
        dut.u_Program_Rom.memory[4] = FENCE_B;
        dut.u_Program_Rom.memory[5] = encode_addi(5'd2, 5'd0, 2);
        dut.u_Program_Rom.memory[6] = RESERVED_MISC;
        dut.u_Program_Rom.memory[7] = encode_addi(5'd3, 5'd0, 3);

        repeat (3) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        wait (retire_count == 7);
        @(posedge clk);
        #1;

        if (dut.u_Data_Memory.memory[0] !== 32'd42 ||
            dut.read_reg(5) !== 32'd42 || dut.read_reg(2) !== 32'd2 ||
            dut.read_reg(3) !== 32'd3)
            $fatal(1, "[FAIL] architectural state around FENCE is incorrect");
        if (fence_decode_count !== 2 || fence_retire_count !== 2)
            $fatal(1, "[FAIL] FENCE decode/retire count decode=%0d retire=%0d",
                   fence_decode_count, fence_retire_count);
        if (dmem_request_count !== 2)
            $fatal(1, "[FAIL] expected only Store and Load memory requests, got %0d",
                   dmem_request_count);
        if (trap_count !== 1)
            $fatal(1, "[FAIL] reserved MISC-MEM must trap exactly once");

        $display("[PASS] tb_CPU_FENCE completed: ordered Store/FENCE/Load, two legal retires, one reserved-encoding trap.");
        $finish;
    end
endmodule
