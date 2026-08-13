`timescale 1ns / 100ps
`include "defines.sv"

module tb_CPU_Directed;
    logic clk;
    logic rst;
    logic trap_valid;
    logic [3:0] trap_cause;
    logic [31:0] trap_pc;
    logic [31:0] trap_tval;
    logic retire_valid;
    logic [31:0] retire_pc;
    logic [31:0] retire_inst;
    logic retire_mem_write;

    integer cycles;
    integer retire_count;
    integer trap_event_count;
    integer redirect_count;
    integer store_retire_count;
    integer fence_retire_count;
    logic trap_valid_d;

    CPU_Sim_Top #(
        .IMEM_INIT_FILE("build/programs/rv32i_directed/rv32i_directed_imem.hex"),
        .DMEM_INIT_FILE("build/programs/rv32i_directed/rv32i_directed_dmem.hex")
    ) dut (
        .clk(clk),
        .rst(rst),
        .trap_valid(trap_valid),
        .trap_cause(trap_cause),
        .trap_pc(trap_pc),
        .trap_tval(trap_tval),
        .trap_ack(1'b0),
        .trap_redirect_pc(32'd0),
        .retire_valid(retire_valid),
        .retire_pc(retire_pc),
        .retire_inst(retire_inst),
        .retire_mem_write(retire_mem_write)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(negedge clk) begin
        if (!rst && dut.branch_taken)
            redirect_count = redirect_count + 1;
    end

    always @(posedge clk) begin
        if (rst) begin
            trap_valid_d <= 1'b0;
        end else begin
            cycles = cycles + 1;
            if (cycles > 220)
                $fatal(1, "[FAIL] RV32I directed program timeout");

            if (trap_valid && !trap_valid_d)
                trap_event_count = trap_event_count + 1;
            trap_valid_d <= trap_valid;

            if (retire_valid) begin
                if (retire_count >= 42)
                    $fatal(1, "[FAIL] unexpected retire after directed program");
                if (retire_pc !== retire_count * 4 ||
                    retire_inst !== dut.u_Program_Rom.memory[retire_count])
                    $fatal(1,
                        "[FAIL] directed retire[%0d] pc=%08h inst=%08h",
                        retire_count, retire_pc, retire_inst);
                if (retire_mem_write)
                    store_retire_count = store_retire_count + 1;
                if (retire_inst[6:0] == `Opcode_MISC_MEM &&
                    retire_inst[14:12] == `F3_FENCE)
                    fence_retire_count = fence_retire_count + 1;
                retire_count = retire_count + 1;
            end
        end
    end

    task automatic check_reg(
        input integer index,
        input logic [31:0] expected,
        input string name
    );
        begin
            if (dut.read_reg(index) !== expected)
                $fatal(1, "[FAIL] %s: x%0d expected=%08h actual=%08h",
                       name, index, expected, dut.read_reg(index));
        end
    endtask

    initial begin
        rst = 1'b1;
        cycles = 0;
        retire_count = 0;
        trap_event_count = 0;
        redirect_count = 0;
        store_retire_count = 0;
        fence_retire_count = 0;
        trap_valid_d = 1'b0;

        repeat (3) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        wait (trap_valid);
        repeat (2) @(posedge clk);
        #1;

        if (trap_cause !== `TRAP_BREAKPOINT ||
            trap_pc !== 32'h0000_00A8 || trap_tval !== 32'd0)
            $fatal(1, "[FAIL] directed EBREAK metadata");
        if (trap_event_count !== 1)
            $fatal(1, "[FAIL] directed program expected one trap event");
        if (retire_count !== 42)
            $fatal(1, "[FAIL] expected 42 pre-EBREAK retires, got %0d",
                   retire_count);
        if (redirect_count !== 8)
            $fatal(1, "[FAIL] expected 8 Branch/JAL/JALR redirects, got %0d",
                   redirect_count);
        if (store_retire_count !== 4 || fence_retire_count !== 1)
            $fatal(1, "[FAIL] Store/FENCE retire counts store=%0d fence=%0d",
                   store_retire_count, fence_retire_count);

        check_reg(1,  32'hFFFF_FFFF, "ADDI negative immediate");
        check_reg(2,  32'd1, "SLTI signed result");
        check_reg(3,  32'd0, "SLTIU unsigned result");
        check_reg(4,  32'd0, "XORI complement");
        check_reg(5,  32'h55, "ORI result");
        check_reg(6,  32'h05, "ANDI result");
        check_reg(7,  32'h8000_0000, "SLLI shamt 31");
        check_reg(8,  32'd1, "SRLI shamt 31");
        check_reg(9,  32'hFFFF_FFFF, "SRAI sign fill");
        check_reg(10, 32'd2, "ADD result");
        check_reg(11, 32'd1, "SUB result");
        check_reg(12, 32'd2, "SLL result");
        check_reg(13, 32'd1, "SLT result");
        check_reg(14, 32'd1, "SLTU result");
        check_reg(15, 32'h50, "XOR result");
        check_reg(16, 32'h4000_0000, "SRL result");
        check_reg(17, 32'hC000_0000, "SRA result");
        check_reg(18, 32'h55, "OR result");
        check_reg(19, 32'h05, "AND result");
        check_reg(20, 32'h1234_5000, "LUI result");
        check_reg(21, 32'h0000_0050, "AUIPC nonzero PC");
        check_reg(22, 32'h1234_5000, "LW result");
        check_reg(23, 32'h0000_0055, "LH result");
        check_reg(24, 32'h0000_0055, "LHU result");
        check_reg(25, 32'h0000_0005, "LB result");
        check_reg(26, 32'h0000_0005, "LBU result");
        check_reg(27, 32'h0000_0090, "JAL link");
        check_reg(28, 32'h0000_009C, "JALR link");
        check_reg(29, 32'h0000_009C, "JALR target base");
        check_reg(30, 32'd40, "completion value");

        if (dut.u_Data_Memory.memory[0] !== 32'h1234_5000 ||
            dut.u_Data_Memory.memory[1] !== 32'h0005_0055 ||
            dut.u_Data_Memory.memory[2] !== 32'd40)
            $fatal(1, "[FAIL] directed memory/signature mismatch");

        $display("[PASS] tb_CPU_Directed completed: 42 ordered retires, 38 normal RV32I instructions, 8 redirects, and signature 40.");
        $finish;
    end
endmodule
