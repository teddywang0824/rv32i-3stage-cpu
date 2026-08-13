`timescale 1ns / 100ps

module tb_ACT4;
    localparam logic [31:0] TEST_STATUS = 32'h01ff_fff0;
    localparam integer MEMORY_WORDS = 8388608;

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
    logic [31:0] retire_mem_addr;
    logic [31:0] retire_mem_data;
    logic [3:0] retire_mem_byte_enable;

    integer cycles;
    integer retired;
    integer max_cycles;
    integer trace_enabled;
    string test_name;

    CPU_Sim_Top #(
        .USE_UNIFIED_MEMORY (1),
        .UNIFIED_MEMORY_WORDS(MEMORY_WORDS)
    ) dut (
        .clk                    (clk),
        .rst                    (rst),
        .trap_valid             (trap_valid),
        .trap_cause             (trap_cause),
        .trap_pc                (trap_pc),
        .trap_tval              (trap_tval),
        .trap_ack               (1'b0),
        .trap_redirect_pc       (32'd0),
        .retire_valid           (retire_valid),
        .retire_pc              (retire_pc),
        .retire_inst            (retire_inst),
        .retire_mem_write       (retire_mem_write),
        .retire_mem_addr        (retire_mem_addr),
        .retire_mem_data        (retire_mem_data),
        .retire_mem_byte_enable (retire_mem_byte_enable)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        cycles = 0;
        retired = 0;
        max_cycles = 2000000;
        trace_enabled = 0;
        test_name = "unnamed";
        if ($value$plusargs("MAX_CYCLES=%d", max_cycles)) begin end
        if ($value$plusargs("TEST_NAME=%s", test_name)) begin end
        if ($test$plusargs("TRACE"))
            trace_enabled = 1;

        rst = 1'b1;
        repeat (5) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
    end

    always @(posedge clk) begin
        if (!rst) begin
            cycles = cycles + 1;
            if (cycles > max_cycles)
                $fatal(1, "[ACT4 FAIL] %s timeout after %0d cycles (%0d retired)",
                       test_name, cycles, retired);

            if (trap_valid)
                $fatal(1, "[ACT4 FAIL] %s unexpected trap cause=%0d pc=%08h tval=%08h",
                       test_name, trap_cause, trap_pc, trap_tval);

            if (retire_valid) begin
                retired = retired + 1;
                if (trace_enabled)
                    $display("[RETIRE] pc=%08h inst=%08h", retire_pc, retire_inst);

                if (retire_mem_write && retire_mem_addr == TEST_STATUS) begin
                    if (retire_mem_byte_enable !== 4'b1111)
                        $fatal(1, "[ACT4 FAIL] %s status Store byte enable=%b",
                               test_name, retire_mem_byte_enable);
                    if (retire_mem_data == 32'd1) begin
                        $display("[ACT4 PASS] %s cycles=%0d retired=%0d",
                                 test_name, cycles, retired);
                        $finish;
                    end
                    if (retire_mem_data == 32'd3)
                        $fatal(1, "[ACT4 FAIL] %s self-check reported failure", test_name);
                    $fatal(1, "[ACT4 FAIL] %s invalid status value=%08h",
                           test_name, retire_mem_data);
                end
            end
        end
    end
endmodule
