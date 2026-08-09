`timescale 1ns / 100ps

module tb_Data_Memory;

    logic        clk;
    logic        mem_en;
    logic        mem_write;
    logic [3:0]  byte_enable;
    logic [31:0] address;
    logic [31:0] write_data;
    logic [31:0] read_data;
    logic        read_valid;

    Data_Memory u_Data_Memory (
        .clk        (clk),
        .mem_en     (mem_en),
        .mem_write  (mem_write),
        .byte_enable(byte_enable),
        .address    (address),
        .write_data (write_data),
        .read_data  (read_data),
        .read_valid (read_valid)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic write_word(
        input logic [31:0] test_address,
        input logic [31:0] test_data,
        input logic [3:0]  test_byte_enable,
        input string       test_name
    );
        begin
            @(negedge clk);
            mem_en      = 1'b1;
            mem_write   = 1'b1;
            byte_enable = test_byte_enable;
            address     = test_address;
            write_data  = test_data;

            @(posedge clk);
            #1;
            if (read_valid !== 1'b0)
                $fatal(1,
                    "[FAIL] %s: write cycle must have read_valid=0, actual=%b",
                    test_name, read_valid
                );

            $display("[PASS] %s", test_name);
        end
    endtask

    task automatic read_word(
        input logic [31:0] test_address,
        input logic [31:0] expected_data,
        input string       test_name
    );
        begin
            @(negedge clk);
            mem_en      = 1'b1;
            mem_write   = 1'b0;
            byte_enable = 4'b0000;
            address     = test_address;
            write_data  = 32'd0;

            @(posedge clk);
            #1;
            if (read_valid !== 1'b1)
                $fatal(1,
                    "[FAIL] %s: expected read_valid=1, actual=%b",
                    test_name, read_valid
                );
            if (read_data !== expected_data)
                $fatal(1,
                    "[FAIL] %s: expected data=0x%08h actual=0x%08h",
                    test_name, expected_data, read_data
                );

            $display("[PASS] %s", test_name);
        end
    endtask

    task automatic idle_cycle(input string test_name);
        begin
            @(negedge clk);
            mem_en      = 1'b0;
            mem_write   = 1'b0;
            byte_enable = 4'b0000;
            address     = 32'd0;
            write_data  = 32'd0;

            @(posedge clk);
            #1;
            if (read_valid !== 1'b0)
                $fatal(1,
                    "[FAIL] %s: idle cycle must have read_valid=0, actual=%b",
                    test_name, read_valid
                );

            $display("[PASS] %s", test_name);
        end
    endtask

    initial begin
        mem_en      = 1'b0;
        mem_write   = 1'b0;
        byte_enable = 4'b0000;
        address     = 32'd0;
        write_data  = 32'd0;

        // Give output-valid logic one clock to enter a known idle state.
        @(posedge clk);
        #1;
        if (read_valid !== 1'b0)
            $fatal(1, "[FAIL] initial idle clock must clear read_valid");

        // Complete-word write and synchronous readback.
        write_word(32'h0000_0000, 32'h1122_3344, 4'b1111,
                   "full-word write does not produce a read response");
        read_word(32'h0000_0000, 32'h1122_3344,
                  "full-word synchronous readback");

        // Changing the read address between clock edges must not change data.
        write_word(32'h0000_0004, 32'hA5A5_5A5A, 4'b1111,
                   "write independent second word");
        read_word(32'h0000_0000, 32'h1122_3344,
                  "prepare synchronous-read timing check");
        @(negedge clk);
        mem_en    = 1'b1;
        mem_write = 1'b0;
        address   = 32'h0000_0004;
        #1;
        if (read_data !== 32'h1122_3344)
            $fatal(1,
                "[FAIL] read_data changed before the sampling edge: actual=0x%08h",
                read_data
            );
        @(posedge clk);
        #1;
        if (read_valid !== 1'b1 || read_data !== 32'hA5A5_5A5A)
            $fatal(1,
                "[FAIL] synchronous address sampling: valid=%b data=0x%08h",
                read_valid, read_data
            );
        $display("[PASS] read address is sampled synchronously");

        // Each byte lane may update independently while all disabled lanes hold.
        write_word(32'h0000_0008, 32'h1122_3344, 4'b1111,
                   "initialize byte-lane test word");
        write_word(32'h0000_0008, 32'hAABB_CCDD, 4'b0001,
                   "write byte lane 0 only");
        read_word(32'h0000_0008, 32'h1122_33DD,
                  "byte lane 0 preserves other lanes");
        write_word(32'h0000_0008, 32'hAABB_CCDD, 4'b0010,
                   "write byte lane 1 only");
        read_word(32'h0000_0008, 32'h1122_CCDD,
                  "byte lane 1 preserves other lanes");
        write_word(32'h0000_0008, 32'hAABB_CCDD, 4'b0100,
                   "write byte lane 2 only");
        read_word(32'h0000_0008, 32'h11BB_CCDD,
                  "byte lane 2 preserves other lanes");
        write_word(32'h0000_0008, 32'hAABB_CCDD, 4'b1000,
                   "write byte lane 3 only");
        read_word(32'h0000_0008, 32'hAABB_CCDD,
                  "byte lane 3 preserves other lanes");

        // byte_enable=0 and mem_en=0 must not modify stored data.
        write_word(32'h0000_0008, 32'hFFFF_FFFF, 4'b0000,
                   "zero byte-enable writes nothing");
        read_word(32'h0000_0008, 32'hAABB_CCDD,
                  "zero byte-enable preserves word");

        @(negedge clk);
        mem_en      = 1'b0;
        mem_write   = 1'b1;
        byte_enable = 4'b1111;
        address     = 32'h0000_0008;
        write_data  = 32'hDEAD_BEEF;
        @(posedge clk);
        #1;
        if (read_valid !== 1'b0)
            $fatal(1, "[FAIL] disabled write produced read_valid");
        read_word(32'h0000_0008, 32'hAABB_CCDD,
                  "mem_en=0 suppresses write");

        // Highest word in the declared 4 KiB range must be independent.
        write_word(32'h0000_0FFC, 32'hCAFE_BABE, 4'b1111,
                   "write highest 4 KiB word address");
        read_word(32'h0000_0FFC, 32'hCAFE_BABE,
                  "read highest 4 KiB word address");
        read_word(32'h0000_0000, 32'h1122_3344,
                  "highest address does not alias word zero");

        idle_cycle("idle request clears read_valid");

        $display("[PASS] tb_Data_Memory completed.");
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "[FAIL] tb_Data_Memory timeout");
    end

endmodule
