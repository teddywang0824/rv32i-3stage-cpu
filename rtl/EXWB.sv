module EXWB (
    input  logic        clk,
    input  logic        rst,

    input  logic [31:0] alu_result_,
    input  logic [4:0]  addr_rd_,
    input  logic        reg_write_,
    input  logic        valid_inst_,

    // Travel beside a synchronous memory request for the future Load Unit.
    input  logic        mem_en_,
    input  logic        mem_write_,
    input  logic [2:0]  load_op_,

    output logic [31:0] alu_result_r,
    output logic [4:0]  addr_rd_r,
    output logic        reg_write_r,
    output logic        valid_inst_r,
    output logic        mem_en_r,
    output logic        mem_write_r,
    output logic [2:0]  load_op_r
);

    always_ff @(posedge clk) begin
        if (rst) begin
            alu_result_r <= 32'd0;
            addr_rd_r     <= 5'd0;
            reg_write_r   <= 1'b0;
            valid_inst_r  <= 1'b0;
            mem_en_r      <= 1'b0;
            mem_write_r   <= 1'b0;
            load_op_r     <= 3'd0;
        end
        else begin
            alu_result_r <= alu_result_;
            addr_rd_r     <= addr_rd_;
            reg_write_r   <= reg_write_;
            valid_inst_r  <= valid_inst_;
            mem_en_r      <= mem_en_;
            mem_write_r   <= mem_write_;
            load_op_r     <= load_op_;
        end
    end

endmodule
