module CPU_Sim_Top (
    input  logic        clk,
    input  logic        rst,

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

    logic        imem_req_valid;
    logic [31:0] imem_req_addr;
    logic        imem_resp_kill;
    logic        imem_resp_valid;
    logic [31:0] imem_resp_pc;
    logic [31:0] imem_resp_inst;

    logic        dmem_req_valid;
    logic        dmem_req_write;
    logic [3:0]  dmem_req_byte_enable;
    logic [31:0] dmem_req_addr;
    logic [31:0] dmem_req_wdata;
    logic        dmem_resp_valid;
    logic [31:0] dmem_resp_rdata;

    CPU_Core u_CPU_Core (
        .clk                    (clk),
        .rst                    (rst),
        .imem_req_valid         (imem_req_valid),
        .imem_req_addr          (imem_req_addr),
        .imem_resp_kill         (imem_resp_kill),
        .imem_resp_valid        (imem_resp_valid),
        .imem_resp_pc           (imem_resp_pc),
        .imem_resp_inst         (imem_resp_inst),
        .dmem_req_valid         (dmem_req_valid),
        .dmem_req_write         (dmem_req_write),
        .dmem_req_byte_enable   (dmem_req_byte_enable),
        .dmem_req_addr          (dmem_req_addr),
        .dmem_req_wdata         (dmem_req_wdata),
        .dmem_resp_valid        (dmem_resp_valid),
        .dmem_resp_rdata        (dmem_resp_rdata),
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

    Program_ROM u_Program_Rom (
        .clk            (clk),
        .rst            (rst),
        .fetch_en       (imem_req_valid),
        .kill_response  (imem_resp_kill),
        .fetch_addr     (imem_req_addr),
        .response_valid (imem_resp_valid),
        .response_pc    (imem_resp_pc),
        .response_inst  (imem_resp_inst)
    );

    Data_Memory u_Data_Memory (
        .clk         (clk),
        .mem_en      (dmem_req_valid),
        .mem_write   (dmem_req_write),
        .byte_enable (dmem_req_byte_enable),
        .address     (dmem_req_addr),
        .write_data  (dmem_req_wdata),
        .read_data   (dmem_resp_rdata),
        .read_valid  (dmem_resp_valid)
    );

    // Simulation-only observation aliases keep testbenches independent of the
    // Core's internal hierarchy.  Architectural checking should prefer retire.
    wire [4:0]  addr_rd_r           = u_CPU_Core.addr_rd_r;
    wire [31:0] alu_result_         = u_CPU_Core.alu_result_;
    wire        branch_en_          = u_CPU_Core.branch_en_;
    wire        branch_en_r         = u_CPU_Core.branch_en_r;
    wire [2:0]  branch_op_r         = u_CPU_Core.branch_op_r;
    wire        branch_taken        = u_CPU_Core.branch_taken;
    wire [31:0] branch_target       = u_CPU_Core.branch_target;
    wire        fetch_response_valid = imem_resp_valid;
    wire [31:0] fetch_response_pc    = imem_resp_pc;
    wire [31:0] fetch_response_inst  = imem_resp_inst;
    wire        id_uses_rs1         = u_CPU_Core.id_uses_rs1;
    wire        id_uses_rs2         = u_CPU_Core.id_uses_rs2;
    wire        idex_valid_inst_r   = u_CPU_Core.idex_valid_inst_r;
    wire        jump_op_            = u_CPU_Core.jump_op_;
    wire        jump_op_r           = u_CPU_Core.jump_op_r;
    wire        load_use_stall      = u_CPU_Core.load_use_stall;
    wire        mem_en              = u_CPU_Core.mem_en;
    wire        mem_en_r            = u_CPU_Core.mem_en_r;
    wire        mem_write           = u_CPU_Core.mem_write;
    wire        mem_write_r         = u_CPU_Core.mem_write_r;
    wire        misaligned          = u_CPU_Core.misaligned;
    wire [31:0] pc                  = u_CPU_Core.pc;
    wire        reg_write_          = u_CPU_Core.reg_write_;
    wire        valid_inst_         = u_CPU_Core.valid_inst_;
    wire        write_regf_en_r     = u_CPU_Core.write_regf_en_r;

    function automatic [31:0] read_reg(input integer index);
        read_reg = u_CPU_Core.u_Reg_File.regs[index];
    endfunction

    task automatic write_reg(input integer index, input logic [31:0] value);
        u_CPU_Core.u_Reg_File.regs[index] = value;
    endtask

endmodule
