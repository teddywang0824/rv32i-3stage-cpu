`timescale 1ns / 100ps

module tb_Program_ROM;

    logic        clk;
    logic        rst;
    logic        fetch_en;
    logic        kill_response;
    logic [31:0] fetch_addr;

    logic        response_valid;
    logic [31:0] response_pc;
    logic [31:0] response_inst;

    localparam logic [31:0] INST_AT_0 = 32'h1111_AAAA;
    localparam logic [31:0] INST_AT_4 = 32'h2222_BBBB;

    Program_ROM u_Program_ROM (
        .clk           (clk),
        .rst           (rst),
        .fetch_en      (fetch_en),
        .kill_response (kill_response),
        .fetch_addr    (fetch_addr),
        .response_valid(response_valid),
        .response_pc   (response_pc),
        .response_inst (response_inst)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic drive_request(
        input logic        next_fetch_en,
        input logic        next_kill_response,
        input logic [31:0] next_fetch_addr
    );
        begin
            @(negedge clk);
            fetch_en = next_fetch_en;
            kill_response = next_kill_response;
            fetch_addr = next_fetch_addr;
        end
    endtask

    task automatic expect_response(
        input logic        expected_valid,
        input logic [31:0] expected_pc,
        input logic [31:0] expected_inst,
        input string       test_name
    );
        begin
            @(posedge clk);
            #1;

            if (response_valid !== expected_valid)
                $fatal(1,
                    "[FAIL] %s response_valid: expected=%b actual=%b",
                    test_name, expected_valid, response_valid
                );

            if (response_pc !== expected_pc)
                $fatal(1,
                    "[FAIL] %s response_pc: expected=0x%08h actual=0x%08h",
                    test_name, expected_pc, response_pc
                );

            if (response_inst !== expected_inst)
                $fatal(1,
                    "[FAIL] %s response_inst: expected=0x%08h actual=0x%08h",
                    test_name, expected_inst, response_inst
                );

            $display("[PASS] %s", test_name);
        end
    endtask

    initial begin
        rst = 1'b1;
        fetch_en = 1'b0;
        kill_response = 1'b0;
        fetch_addr = 32'd0;

        // Distinct payloads make a response PC/instruction mismatch visible.
        u_Program_ROM.memory[0] = INST_AT_0;
        u_Program_ROM.memory[1] = INST_AT_4;
        // $display("u_Program_ROM.memory[0] : %h",u_Program_ROM.memory[0]);
        // $display("u_Program_ROM.memory[1] : %h",u_Program_ROM.memory[1]);

        // Reset only promises an invalid response; payload is don't-care until
        // the first accepted request.
        @(posedge clk);
        #1;
        if (response_valid !== 1'b0)
            $fatal(1, "[FAIL] reset must invalidate the response");
        $display("[PASS] reset invalidates response");
        rst = 0;

        // Address 0 and address 4 are accepted on consecutive cycles.  Each
        // response must contain the PC and instruction sampled together.
        drive_request(1'b1, 1'b0, 32'd0);
        expect_response(1'b1, 32'd0, INST_AT_0,
                        "fetch_addr=0 returns memory[0] with matching PC");

        drive_request(1'b1, 1'b0, 32'd4);
        expect_response(1'b1, 32'd4, INST_AT_4,
                        "consecutive fetch_addr=4 returns memory[1] with matching PC");
        $display("[PASS] one fetch request is accepted every cycle");

        // With no accepted request, the complete valid response is held so it
        // can remain in ID across a pipeline stall.
        drive_request(1'b0, 1'b0, 32'h0000_0020);
        expect_response(1'b1, 32'd4, INST_AT_4,
                        "fetch_en=0 holds a valid response and its payload");

        // First create a known valid response, then kill it on the next edge.
        drive_request(1'b1, 1'b0, 32'd0);
        expect_response(1'b1, 32'd0, INST_AT_0,
                        "response before kill is valid");

        drive_request(1'b0, 1'b1, 32'd4);
        expect_response(1'b0, 32'd0, INST_AT_0,
                        "kill_response invalidates and holds payload");

        // Once killed, an idle cycle must not accidentally make the stale
        // response valid again.
        drive_request(1'b0, 1'b0, 32'h0000_0020);
        expect_response(1'b0, 32'd0, INST_AT_0,
                        "fetch_en=0 also holds an invalid response");

        // A simultaneous fetch must not overwrite the killed response.
        drive_request(1'b1, 1'b1, 32'd4);
        expect_response(1'b0, 32'd0, INST_AT_0,
                        "kill_response has priority over fetch_en");

        // Confirm normal operation resumes after kill_response is released.
        drive_request(1'b1, 1'b0, 32'd4);
        expect_response(1'b1, 32'd4, INST_AT_4,
                        "fetch resumes after kill_response");

        $display("[PASS] tb_Program_ROM completed.");
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "[FAIL] tb_Program_ROM timeout");
    end

endmodule
