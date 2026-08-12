`include "defines.sv"

module Trap_Detect (
    input  logic        idex_trap_valid,
    input  logic [3:0]  idex_trap_cause,
    input  logic [31:0] idex_trap_tval,

    input  logic        ex_valid,
    input  logic [31:0] fault_pc,
    input  logic        control_redirect,
    input  logic [31:0] control_target,

    input  logic        mem_en,
    input  logic        mem_write,
    input  logic [2:0]  load_op,
    input  logic [31:0] effective_address,
    input  logic        store_misaligned,

    output logic        trap_req_valid,
    output logic [3:0]  trap_req_cause,
    output logic [31:0] trap_req_pc,
    output logic [31:0] trap_req_tval
);

    logic control_misaligned;
    logic load_misaligned;
    logic store_fault;

    assign control_misaligned = ex_valid && control_redirect
                              && (control_target[1:0] != 2'b00);

    assign load_misaligned = ex_valid && mem_en && !mem_write
                           && ((((load_op == `F3_LH) || (load_op == `F3_LHU))
                                && effective_address[0])
                               || ((load_op == `F3_LW)
                                   && (|effective_address[1:0])));

    assign store_fault = ex_valid && mem_en && mem_write && store_misaligned;

    always_comb begin
        trap_req_valid = 1'b0;
        trap_req_cause = 4'd0;
        trap_req_pc    = 32'd0;
        trap_req_tval  = 32'd0;

        if (idex_trap_valid) begin
            trap_req_valid = 1'b1;
            trap_req_cause = idex_trap_cause;
            trap_req_pc    = fault_pc;
            trap_req_tval  = idex_trap_tval;
        end else if (control_misaligned) begin
            trap_req_valid = 1'b1;
            trap_req_cause = `TRAP_INST_ADDR_MISALIGNED;
            trap_req_pc    = fault_pc;
            trap_req_tval  = control_target;
        end else if (load_misaligned) begin
            trap_req_valid = 1'b1;
            trap_req_cause = `TRAP_LOAD_ADDR_MISALIGNED;
            trap_req_pc    = fault_pc;
            trap_req_tval  = effective_address;
        end else if (store_fault) begin
            trap_req_valid = 1'b1;
            trap_req_cause = `TRAP_STORE_ADDR_MISALIGNED;
            trap_req_pc    = fault_pc;
            trap_req_tval  = effective_address;
        end
    end

endmodule
