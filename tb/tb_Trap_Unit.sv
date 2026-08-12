`include "defines.sv"

module tb_Trap_Unit;

    logic        clk;
    logic        rst;
    logic        trap_req_valid;
    logic [3:0]  trap_req_cause;
    logic [31:0] trap_req_pc;
    logic [31:0] trap_req_tval;
    logic        trap_ack;
    logic [31:0] trap_redirect_pc;

    logic        trap_valid;
    logic [3:0]  trap_cause;
    logic [31:0] trap_pc;
    logic [31:0] trap_tval;
    logic        trap_pending;
    logic        trap_redirect;
    logic [31:0] trap_target;

    Trap_Unit u_Trap_Unit (
        .clk              (clk),
        .rst              (rst),
        .trap_req_valid   (trap_req_valid),
        .trap_req_cause   (trap_req_cause),
        .trap_req_pc      (trap_req_pc),
        .trap_req_tval    (trap_req_tval),
        .trap_ack         (trap_ack),
        .trap_redirect_pc (trap_redirect_pc),
        .trap_valid       (trap_valid),
        .trap_cause       (trap_cause),
        .trap_pc          (trap_pc),
        .trap_tval        (trap_tval),
        .trap_pending     (trap_pending),
        .trap_redirect    (trap_redirect),
        .trap_target      (trap_target)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic check_pending_metadata(
        input logic [3:0]  expected_cause,
        input logic [31:0] expected_pc,
        input logic [31:0] expected_tval,
        input string       test_name
    );
        begin
            if (trap_valid !== 1'b1)
                $fatal(1, "[FAIL] %s: trap_valid expected 1, got %b",
                       test_name, trap_valid);
            if (trap_pending !== 1'b1)
                $fatal(1, "[FAIL] %s: trap_pending expected 1, got %b",
                       test_name, trap_pending);
            if (trap_cause !== expected_cause ||
                trap_pc    !== expected_pc    ||
                trap_tval  !== expected_tval)
                $fatal(1,
                       "[FAIL] %s metadata: cause=%0d pc=0x%08h tval=0x%08h",
                       test_name, trap_cause, trap_pc, trap_tval);
            $display("[PASS] %s", test_name);
        end
    endtask

    task automatic issue_trap(
        input logic [3:0]  cause,
        input logic [31:0] fault_pc,
        input logic [31:0] fault_tval
    );
        begin
            @(negedge clk);
            trap_req_valid = 1'b1;
            trap_req_cause = cause;
            trap_req_pc    = fault_pc;
            trap_req_tval  = fault_tval;
            @(posedge clk);
            #1;
            trap_req_valid = 1'b0;
        end
    endtask

    initial begin
        rst              = 1'b1;
        trap_req_valid   = 1'b0;
        trap_req_cause   = 4'd0;
        trap_req_pc      = 32'd0;
        trap_req_tval    = 32'd0;
        trap_ack         = 1'b0;
        trap_redirect_pc = 32'd0;

        // Reset must clear the pending event and all externally valid state.
        repeat (2) @(posedge clk);
        #1;
        if (trap_valid !== 1'b0 || trap_pending !== 1'b0 ||
            trap_redirect !== 1'b0)
            $fatal(1, "[FAIL] reset did not clear trap state");
        $display("[PASS] reset clears trap state");

        @(negedge clk);
        rst = 1'b0;

        // Capture one illegal-instruction request.
        issue_trap(`TRAP_ILLEGAL_INSTRUCTION,
                   32'h0000_0100,
                   32'hFFFF_FFFF);
        check_pending_metadata(`TRAP_ILLEGAL_INSTRUCTION,
                               32'h0000_0100,
                               32'hFFFF_FFFF,
                               "request captures cause, PC, and tval");

        // Request inputs are transient.  Pending metadata must not follow them.
        @(negedge clk);
        trap_req_cause = `TRAP_BREAKPOINT;
        trap_req_pc    = 32'hAAAA_AAAA;
        trap_req_tval  = 32'hBBBB_BBBB;
        repeat (2) begin
            @(posedge clk);
            #1;
            check_pending_metadata(`TRAP_ILLEGAL_INSTRUCTION,
                                   32'h0000_0100,
                                   32'hFFFF_FFFF,
                                   "pending metadata remains stable without ack");
        end

        // A second request while pending must not overwrite the first event.
        @(negedge clk);
        trap_req_valid = 1'b1;
        trap_req_cause = `TRAP_LOAD_ADDR_MISALIGNED;
        trap_req_pc    = 32'h0000_0200;
        trap_req_tval  = 32'h0000_0003;
        @(posedge clk);
        #1;
        trap_req_valid = 1'b0;
        check_pending_metadata(`TRAP_ILLEGAL_INSTRUCTION,
                               32'h0000_0100,
                               32'hFFFF_FFFF,
                               "pending trap ignores a second request");

        // Acknowledge the pending event.  Redirect is valid only with ack.
        @(negedge clk);
        trap_redirect_pc = 32'h0000_0080;
        if (trap_redirect !== 1'b0)
            $fatal(1, "[FAIL] redirect asserted before ack");
        trap_ack = 1'b1;
        #1;
        if (trap_redirect !== 1'b1 || trap_target !== 32'h0000_0080)
            $fatal(1,
                   "[FAIL] ack redirect: redirect=%b target=0x%08h",
                   trap_redirect, trap_target);
        $display("[PASS] ack produces redirect with requested target");

        @(posedge clk);
        #1;
        trap_ack = 1'b0;
        if (trap_valid !== 1'b0 || trap_pending !== 1'b0 ||
            trap_redirect !== 1'b0)
            $fatal(1, "[FAIL] ack did not clear pending trap");
        $display("[PASS] ack clears pending trap and redirect pulse");

        // The unit must accept a later independent event after completion.
        issue_trap(`TRAP_STORE_ADDR_MISALIGNED,
                   32'h0000_0300,
                   32'h0000_0002);
        check_pending_metadata(`TRAP_STORE_ADDR_MISALIGNED,
                               32'h0000_0300,
                               32'h0000_0002,
                               "unit accepts a new trap after ack");

        // Reset has priority over both an outstanding trap and ack.
        @(negedge clk);
        rst      = 1'b1;
        trap_ack = 1'b1;
        @(posedge clk);
        #1;
        if (trap_valid !== 1'b0 || trap_pending !== 1'b0 ||
            trap_redirect !== 1'b0)
            $fatal(1, "[FAIL] reset did not override pending trap and ack");
        $display("[PASS] reset has priority over pending trap and ack");

        @(negedge clk);
        rst      = 1'b0;
        trap_ack = 1'b1;
        #1;
        if (trap_redirect !== 1'b0)
            $fatal(1, "[FAIL] ack while idle produced redirect");
        $display("[PASS] ack while idle is ignored");

        trap_ack = 1'b0;
        $display("[PASS] tb_Trap_Unit completed: 8 contract scenarios.");
        $finish;
    end

endmodule
