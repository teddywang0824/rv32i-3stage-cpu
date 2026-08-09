`timescale 1ns / 100ps
`include "defines.sv"

module tb_Store_Unit;

    logic [2:0]  store_op;
    logic [31:0] address;
    logic [31:0] value;

    logic [3:0]  byte_enable;
    logic [31:0] aligned_write_data;
    logic        misaligned;

    Store_Unit u_Store_Unit (
        .store_op         (store_op),
        .address          (address),
        .value            (value),
        .byte_enable      (byte_enable),
        .aligned_write_data(aligned_write_data),
        .misaligned       (misaligned)
    );

    task automatic check_store(
        input logic [2:0]  test_store_op,
        input logic [31:0] test_address,
        input logic [31:0] test_value,
        input logic [3:0]  expected_byte_enable,
        input logic [31:0] expected_write_data,
        input logic        expected_misaligned,
        input string       test_name
    );
        begin
            store_op = test_store_op;
            address  = test_address;
            value    = test_value;
            #1;

            if (byte_enable !== expected_byte_enable)
                $fatal(1,
                    "[FAIL] %s byte_enable: expected=%04b actual=%04b",
                    test_name, expected_byte_enable, byte_enable
                );

            if (aligned_write_data !== expected_write_data)
                $fatal(1,
                    "[FAIL] %s aligned_write_data: expected=0x%08h actual=0x%08h",
                    test_name, expected_write_data, aligned_write_data
                );

            if (misaligned !== expected_misaligned)
                $fatal(1,
                    "[FAIL] %s misaligned: expected=%b actual=%b",
                    test_name, expected_misaligned, misaligned
                );

            $display("[PASS] %s", test_name);
        end
    endtask

    initial begin
        // SB is legal at every byte offset and uses only value[7:0].
        check_store(`F3_SB, 32'h0000_0100, 32'hDEAD_BEEF,
                    4'b0001, 32'h0000_00EF, 1'b0,
                    "SB at byte offset 0");
        check_store(`F3_SB, 32'h0000_0101, 32'hDEAD_BEEF,
                    4'b0010, 32'h0000_EF00, 1'b0,
                    "SB at byte offset 1");
        check_store(`F3_SB, 32'h0000_0102, 32'hDEAD_BEEF,
                    4'b0100, 32'h00EF_0000, 1'b0,
                    "SB at byte offset 2");
        check_store(`F3_SB, 32'h0000_0103, 32'hDEAD_BEEF,
                    4'b1000, 32'hEF00_0000, 1'b0,
                    "SB at byte offset 3");

        // SH is legal only at offsets 0 and 2.
        check_store(`F3_SH, 32'h0000_0200, 32'hCAFE_BEEF,
                    4'b0011, 32'h0000_BEEF, 1'b0,
                    "SH at aligned offset 0");
        check_store(`F3_SH, 32'h0000_0202, 32'hCAFE_BEEF,
                    4'b1100, 32'hBEEF_0000, 1'b0,
                    "SH at aligned offset 2");
        check_store(`F3_SH, 32'h0000_0201, 32'hCAFE_BEEF,
                    4'b0000, 32'h0000_0000, 1'b1,
                    "SH rejects misaligned offset 1");
        check_store(`F3_SH, 32'h0000_0203, 32'hCAFE_BEEF,
                    4'b0000, 32'h0000_0000, 1'b1,
                    "SH rejects misaligned offset 3");

        // SW is legal only at offset 0.
        check_store(`F3_SW, 32'h0000_0300, 32'h1234_5678,
                    4'b1111, 32'h1234_5678, 1'b0,
                    "SW at aligned offset 0");
        check_store(`F3_SW, 32'h0000_0301, 32'h1234_5678,
                    4'b0000, 32'h0000_0000, 1'b1,
                    "SW rejects misaligned offset 1");
        check_store(`F3_SW, 32'h0000_0302, 32'h1234_5678,
                    4'b0000, 32'h0000_0000, 1'b1,
                    "SW rejects misaligned offset 2");
        check_store(`F3_SW, 32'h0000_0303, 32'h1234_5678,
                    4'b0000, 32'h0000_0000, 1'b1,
                    "SW rejects misaligned offset 3");

        // Unsupported store operations must leave the write interface safe.
        check_store(`F3_STORE_NONE, 32'h0000_0000, 32'hFFFF_FFFF,
                    4'b0000, 32'h0000_0000, 1'b0,
                    "reserved store operation uses safe outputs");
        check_store(3'b111, 32'hFFFF_FFFF, 32'h89AB_CDEF,
                    4'b0000, 32'h0000_0000, 1'b0,
                    "unknown store operation uses safe outputs");

        // Return to SB after invalid inputs to catch retained combinational state.
        check_store(`F3_SB, 32'h0000_0003, 32'h0000_005A,
                    4'b1000, 32'h5A00_0000, 1'b0,
                    "valid operation after invalid transition");

        $display("[PASS] tb_Store_Unit completed: 15 scenarios.");
        $finish;
    end

endmodule
