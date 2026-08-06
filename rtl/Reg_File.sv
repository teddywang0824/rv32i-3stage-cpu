// RISC-V 的 32 個暫存器，另外 x0 是 hard-wired zero，只能讀不能寫
module Reg_File (
    input logic clk,
    input logic rst,
    
    // write port
    input logic write_regf_en_r,
    input logic [4:0] addr_rd_r,
    input logic [31:0] rd_value_,

    // read port
    input logic [4:0] addr_rs1_,
    input logic [4:0] addr_rs2_,
    output logic [31:0] rs1_value_,
    output logic [31:0] rs2_value_
);

    logic [31:0] regs [0:31];

    integer i;

    // write logic 
    always_ff @(posedge clk) begin
        if (rst) begin
            for (i=0;i<32;i=i+1) begin
                regs[i] <= 0;
            end
        end
        else begin
            if (write_regf_en_r && addr_rd_r != 5'd0) begin
                regs[addr_rd_r] <= rd_value_;
            end
        end
    end

    // read logic
    assign rs1_value_ = (addr_rs1_ == 5'd0) ? 32'd0 : regs[addr_rs1_];
    assign rs2_value_ = (addr_rs2_ == 5'd0) ? 32'd0 : regs[addr_rs2_];
    
endmodule
