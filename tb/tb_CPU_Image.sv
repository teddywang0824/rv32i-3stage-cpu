`timescale 1ns / 100ps
`include "defines.sv"

module tb_CPU_Image;
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
    logic trap_valid_d;

    logic [31:0] expected_pc [0:3];
    logic [31:0] expected_inst [0:3];

    CPU_Sim_Top #(
        .IMEM_INIT_FILE("build/programs/image_smoke/image_smoke_imem.hex"),
        .DMEM_INIT_FILE("build/programs/image_smoke/image_smoke_dmem.hex")
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

    always @(posedge clk) begin
        if (rst) begin
            trap_valid_d <= 1'b0;
        end else begin
            cycles = cycles + 1;
            if (cycles > 80)
                $fatal(1, "[FAIL] image-loaded program timeout");

            if (trap_valid && !trap_valid_d)
                trap_event_count = trap_event_count + 1;
            trap_valid_d <= trap_valid;

            if (retire_valid) begin
                if (retire_count > 3)
                    $fatal(1, "[FAIL] unexpected retire after smoke program");
                if (retire_pc !== expected_pc[retire_count] ||
                    retire_inst !== expected_inst[retire_count])
                    $fatal(1,
                        "[FAIL] retire[%0d] pc=%08h inst=%08h",
                        retire_count, retire_pc, retire_inst);
                if ((retire_count == 3) && !retire_mem_write)
                    $fatal(1, "[FAIL] smoke Store did not retire as memory write");
                retire_count = retire_count + 1;
            end
        end
    end

    initial begin
        rst = 1'b1;
        cycles = 0;
        retire_count = 0;
        trap_event_count = 0;
        trap_valid_d = 1'b0;

        expected_pc[0] = 32'h0000_0000;
        expected_pc[1] = 32'h0000_0004;
        expected_pc[2] = 32'h0000_0008;
        expected_pc[3] = 32'h0000_000C;

        expected_inst[0] = 32'h0000_2083;
        expected_inst[1] = 32'h0040_2103;
        expected_inst[2] = 32'h0020_81B3;
        expected_inst[3] = 32'h0030_2423;

        // Check both explicit image contents and default-fill behavior before
        // releasing reset.  The test never writes either memory hierarchically.
        #1;
        if (dut.u_Program_Rom.memory[0] !== expected_inst[0] ||
            dut.u_Program_Rom.memory[4] !== `I_EBREAK ||
            dut.u_Program_Rom.memory[5] !== `I_NOP)
            $fatal(1, "[FAIL] instruction image/default NOP load");
        if (dut.u_Data_Memory.memory[0] !== 32'd5 ||
            dut.u_Data_Memory.memory[1] !== 32'd7 ||
            dut.u_Data_Memory.memory[3] !== 32'd0)
            $fatal(1, "[FAIL] data image/default zero load");

        repeat (3) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        wait (trap_valid);
        #1;
        if (trap_cause !== `TRAP_BREAKPOINT ||
            trap_pc !== 32'h0000_0010 || trap_tval !== 32'd0)
            $fatal(1, "[FAIL] smoke EBREAK metadata");

        // Allow the older Store to reach the unified retire point.
        repeat (2) @(posedge clk);
        #1;
        if (trap_event_count !== 1)
            $fatal(1, "[FAIL] expected one EBREAK event, got %0d",
                   trap_event_count);
        if (retire_count !== 4)
            $fatal(1, "[FAIL] expected four pre-EBREAK retires, got %0d",
                   retire_count);
        if (dut.read_reg(1) !== 32'd5 || dut.read_reg(2) !== 32'd7 ||
            dut.read_reg(3) !== 32'd12)
            $fatal(1, "[FAIL] image-loaded architectural registers");
        if (dut.u_Data_Memory.memory[2] !== 32'd12)
            $fatal(1, "[FAIL] image-loaded program Store result");

        $display("[PASS] tb_CPU_Image completed: external IMEM/DMEM images executed correctly.");
        $finish;
    end
endmodule
