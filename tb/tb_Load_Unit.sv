`timescale 1ns / 100ps
`include "defines.sv"

module tb_Load_Unit;

    logic [2:0]  load_op;
    logic [31:0] address;
    logic [31:0] read_data;
    logic [31:0] load_value;
    logic        load_misaligned;

    Load_Unit dut (
        .load_op(load_op),
        .address(address),
        .read_data(read_data),
        .load_value(load_value),
        .load_misaligned(load_misaligned)
    );

    task automatic check_load(
        input logic [2:0]  test_op,
        input logic [1:0]  byte_offset,
        input logic [31:0] expected_value,
        input logic        expected_misaligned,
        input string       test_name
    );
        begin
            load_op = test_op;
            address = {30'd0, byte_offset};
            #1;

            if (load_value !== expected_value)
                $fatal(1,
                    "[FAIL] %s value: expected=0x%08h actual=0x%08h",
                    test_name, expected_value, load_value
                );
            if (load_misaligned !== expected_misaligned)
                $fatal(1,
                    "[FAIL] %s misaligned: expected=%b actual=%b",
                    test_name, expected_misaligned, load_misaligned
                );

            $display("[PASS] %s", test_name);
        end
    endtask

    initial begin
        // Little-endian byte lanes, from low to high address: 01, 7F, FF, 80.
        read_data = 32'h80FF_7F01;
        load_op = `F3_LOAD_NONE;
        address = 32'd0;
        #1;

        check_load(`F3_LB,  2'd0, 32'h0000_0001, 1'b0,
                   "LB reads positive byte at offset 0");
        check_load(`F3_LB,  2'd2, 32'hFFFF_FFFF, 1'b0,
                   "LB sign-extends byte at offset 2");
        check_load(`F3_LB,  2'd3, 32'hFFFF_FF80, 1'b0,
                   "LB sign-extends byte at offset 3");
        check_load(`F3_LBU, 2'd2, 32'h0000_00FF, 1'b0,
                   "LBU zero-extends byte at offset 2");
        check_load(`F3_LBU, 2'd3, 32'h0000_0080, 1'b0,
                   "LBU zero-extends byte at offset 3");

        check_load(`F3_LH,  2'd0, 32'h0000_7F01, 1'b0,
                   "LH reads aligned positive halfword");
        check_load(`F3_LH,  2'd2, 32'hFFFF_80FF, 1'b0,
                   "LH sign-extends aligned upper halfword");
        check_load(`F3_LHU, 2'd2, 32'h0000_80FF, 1'b0,
                   "LHU zero-extends aligned upper halfword");
        check_load(`F3_LH,  2'd1, 32'h0000_0000, 1'b1,
                   "LH rejects offset 1");
        check_load(`F3_LHU, 2'd3, 32'h0000_0000, 1'b1,
                   "LHU rejects offset 3");

        check_load(`F3_LW, 2'd0, 32'h80FF_7F01, 1'b0,
                   "LW reads aligned word");
        check_load(`F3_LW, 2'd1, 32'h0000_0000, 1'b1,
                   "LW rejects offset 1");
        check_load(`F3_LW, 2'd2, 32'h0000_0000, 1'b1,
                   "LW rejects offset 2");
        check_load(`F3_LW, 2'd3, 32'h0000_0000, 1'b1,
                   "LW rejects offset 3");

        check_load(3'b011, 2'd0, 32'h0000_0000, 1'b1,
                   "reserved Load operation is rejected");
        check_load(3'bxxx, 2'd0, 32'h0000_0000, 1'b1,
                   "unknown Load operation is rejected safely");

        // Change the memory word after prior signed cases to catch stale/latch data.
        read_data = 32'h1234_5678;
        check_load(`F3_LW, 2'd0, 32'h1234_5678, 1'b0,
                   "Load output follows changed read data");

        $display("[PASS] tb_Load_Unit completed.");
        $finish;
    end

endmodule
