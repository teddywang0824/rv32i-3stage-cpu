`timescale 1ns / 100ps
`include "defines.sv"

module tb_Trap_Detect;
    logic idex_trap_valid;
    logic [3:0] idex_trap_cause;
    logic [31:0] idex_trap_tval;
    logic ex_valid;
    logic [31:0] fault_pc;
    logic control_redirect;
    logic [31:0] control_target;
    logic mem_en;
    logic mem_write;
    logic [2:0] load_op;
    logic [31:0] effective_address;
    logic store_misaligned;
    logic trap_req_valid;
    logic [3:0] trap_req_cause;
    logic [31:0] trap_req_pc;
    logic [31:0] trap_req_tval;

    Trap_Detect dut (.*);

    task automatic check(
        input logic expected_valid,
        input logic [3:0] expected_cause,
        input logic [31:0] expected_tval,
        input string name
    );
        #1;
        if (trap_req_valid !== expected_valid ||
            trap_req_cause !== expected_cause ||
            trap_req_tval !== expected_tval ||
            (expected_valid && trap_req_pc !== fault_pc))
            $fatal(1, "[FAIL] %s: valid=%b cause=%0d pc=%08h tval=%08h",
                   name, trap_req_valid, trap_req_cause,
                   trap_req_pc, trap_req_tval);
        $display("[PASS] %s", name);
    endtask

    initial begin
        idex_trap_valid = 0;
        idex_trap_cause = 0;
        idex_trap_tval = 0;
        ex_valid = 1;
        fault_pc = 32'h20;
        control_redirect = 0;
        control_target = 0;
        mem_en = 0;
        mem_write = 0;
        load_op = `F3_LB;
        effective_address = 0;
        store_misaligned = 0;
        check(0, 0, 0, "normal EX instruction has no trap");

        control_redirect = 1;
        control_target = 32'h102;
        check(1, `TRAP_INST_ADDR_MISALIGNED, 32'h102,
              "taken control target violates IALIGN=32");

        control_redirect = 0;
        control_target = 32'h102;
        check(0, 0, 0, "not-taken branch ignores misaligned candidate target");

        mem_en = 1;
        load_op = `F3_LH;
        effective_address = 32'h101;
        check(1, `TRAP_LOAD_ADDR_MISALIGNED, 32'h101,
              "LH rejects odd effective address");

        load_op = `F3_LW;
        effective_address = 32'h102;
        check(1, `TRAP_LOAD_ADDR_MISALIGNED, 32'h102,
              "LW requires word alignment");

        load_op = `F3_LBU;
        effective_address = 32'h103;
        check(0, 0, 0, "byte Load accepts every byte address");

        mem_write = 1;
        store_misaligned = 1;
        effective_address = 32'h202;
        check(1, `TRAP_STORE_ADDR_MISALIGNED, 32'h202,
              "Store_Unit misalignment becomes Store trap");

        ex_valid = 0;
        check(0, 0, 0, "invalid EX payload cannot raise runtime trap");

        idex_trap_valid = 1;
        idex_trap_cause = `TRAP_ILLEGAL_INSTRUCTION;
        idex_trap_tval = 32'hFFFF_FFFF;
        check(1, `TRAP_ILLEGAL_INSTRUCTION, 32'hFFFF_FFFF,
              "decode-time trap survives even though normal valid is zero");

        $display("[PASS] tb_Trap_Detect completed.");
        $finish;
    end
endmodule
