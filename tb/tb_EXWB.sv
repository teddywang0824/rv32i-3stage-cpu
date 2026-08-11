`timescale 1ns / 100ps

module tb_EXWB;
    logic clk;
    logic rst;
    logic [31:0] alu_result_;
    logic [4:0] addr_rd_;
    logic reg_write_;
    logic valid_inst_;
    logic [31:0] pc_;
    logic [31:0] inst_;
    logic mem_en_;
    logic mem_write_;
    logic [2:0] load_op_;
    logic store_commit_;
    logic [31:0] store_data_;
    logic [3:0] store_byte_enable_;
    logic [31:0] alu_result_r;
    logic [4:0] addr_rd_r;
    logic reg_write_r;
    logic valid_inst_r;
    logic [31:0] pc_r;
    logic [31:0] inst_r;
    logic mem_en_r;
    logic mem_write_r;
    logic [2:0] load_op_r;
    logic store_commit_r;
    logic [31:0] store_data_r;
    logic [3:0] store_byte_enable_r;

    EXWB dut (.*);

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic check_outputs(
        input logic [31:0] expected_result,
        input logic [4:0] expected_rd,
        input logic expected_reg_write,
        input logic expected_valid,
        input logic [31:0] expected_pc,
        input logic [31:0] expected_inst,
        input logic expected_mem_en,
        input logic expected_mem_write,
        input logic [2:0] expected_load_op,
        input logic expected_store_commit,
        input logic [31:0] expected_store_data,
        input logic [3:0] expected_store_byte_enable,
        input string test_name
    );
        begin
            #1;
            if (alu_result_r !== expected_result || addr_rd_r !== expected_rd ||
                reg_write_r !== expected_reg_write || valid_inst_r !== expected_valid ||
                pc_r !== expected_pc || inst_r !== expected_inst ||
                mem_en_r !== expected_mem_en || mem_write_r !== expected_mem_write ||
                load_op_r !== expected_load_op ||
                store_commit_r !== expected_store_commit ||
                store_data_r !== expected_store_data ||
                store_byte_enable_r !== expected_store_byte_enable)
                $fatal(1, "[FAIL] %s", test_name);
            $display("[PASS] %s", test_name);
        end
    endtask

    initial begin
        rst = 1'b1;
        alu_result_ = 32'hDEAD_BEEF;
        addr_rd_ = 5'd7;
        reg_write_ = 1'b1;
        valid_inst_ = 1'b1;
        pc_ = 32'hFFFF_FFFC;
        inst_ = 32'hFFFF_FFFF;
        mem_en_ = 1'b1;
        mem_write_ = 1'b0;
        load_op_ = 3'b101;
        store_commit_ = 1'b1;
        store_data_ = 32'hAAAA_5555;
        store_byte_enable_ = 4'b1111;

        @(posedge clk);
        check_outputs(32'd0, 5'd0, 1'b0, 1'b0, 32'd0, 32'd0,
                      1'b0, 1'b0, 3'd0, 1'b0, 32'd0, 4'd0,
                      "reset clears EX/WB");

        @(negedge clk);
        rst = 1'b0;
        alu_result_ = 32'h1234_5678;
        addr_rd_ = 5'd12;
        reg_write_ = 1'b1;
        valid_inst_ = 1'b1;
        pc_ = 32'h0000_0010;
        inst_ = 32'h0000_A603;
        mem_en_ = 1'b1;
        mem_write_ = 1'b0;
        load_op_ = 3'b010;
        store_commit_ = 1'b0;
        store_data_ = 32'd0;
        store_byte_enable_ = 4'd0;
        @(posedge clk);
        check_outputs(32'h1234_5678, 5'd12, 1'b1, 1'b1,
                      32'h0000_0010, 32'h0000_A603,
                      1'b1, 1'b0, 3'b010, 1'b0, 32'd0, 4'd0,
                      "captures ALU and load metadata");

        @(negedge clk);
        alu_result_ = 32'hCAFE_BABE;
        addr_rd_ = 5'd0;
        reg_write_ = 1'b0;
        valid_inst_ = 1'b1;
        pc_ = 32'h0000_0014;
        inst_ = 32'h0030_2823;
        mem_en_ = 1'b1;
        mem_write_ = 1'b1;
        load_op_ = 3'b000;
        store_commit_ = 1'b1;
        store_data_ = 32'hCAFE_BABE;
        store_byte_enable_ = 4'b1111;
        @(posedge clk);
        check_outputs(32'hCAFE_BABE, 5'd0, 1'b0, 1'b1,
                      32'h0000_0014, 32'h0030_2823,
                      1'b1, 1'b1, 3'b000, 1'b1,
                      32'hCAFE_BABE, 4'b1111,
                      "captures following instruction independently");

        $display("[PASS] tb_EXWB completed.");
        $finish;
    end
endmodule
