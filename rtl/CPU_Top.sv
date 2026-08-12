// Backward-compatible board/simulation top.  New simulation testbenches should
// instantiate CPU_Sim_Top directly; synthesis should target CPU_Core.
module CPU_Top (
    input  logic        clk,
    input  logic        rst,
    output logic        trap_valid,
    output logic [3:0]  trap_cause,
    output logic [31:0] trap_pc,
    output logic [31:0] trap_tval,
    input  logic        trap_ack,
    input  logic [31:0] trap_redirect_pc,
    output logic        retire_valid,
    output logic [31:0] retire_pc,
    output logic [31:0] retire_inst,
    output logic        retire_rd_write,
    output logic [4:0]  retire_rd,
    output logic [31:0] retire_rd_data,
    output logic        retire_mem_write,
    output logic [31:0] retire_mem_addr,
    output logic [31:0] retire_mem_data,
    output logic [3:0]  retire_mem_byte_enable
);

    CPU_Sim_Top u_CPU_Sim_Top (
        .clk                    (clk),
        .rst                    (rst),
        .trap_valid             (trap_valid),
        .trap_cause             (trap_cause),
        .trap_pc                (trap_pc),
        .trap_tval              (trap_tval),
        .trap_ack               (trap_ack),
        .trap_redirect_pc       (trap_redirect_pc),
        .retire_valid           (retire_valid),
        .retire_pc              (retire_pc),
        .retire_inst            (retire_inst),
        .retire_rd_write        (retire_rd_write),
        .retire_rd              (retire_rd),
        .retire_rd_data         (retire_rd_data),
        .retire_mem_write       (retire_mem_write),
        .retire_mem_addr        (retire_mem_addr),
        .retire_mem_data        (retire_mem_data),
        .retire_mem_byte_enable (retire_mem_byte_enable)
    );

endmodule
