module tb_Harzard_Observe;

    logic clk;
    logic rst;

    CPU_Sim_Top u_CPU_Top (
        .clk(clk),
        .rst(rst),
        .trap_ack(1'b0),
        .trap_redirect_pc(32'd0)
    );

    initial begin
        $dumpfile("build/cpu_top.vcd");
        $dumpvars(0, tb_CPU_Top);
    end

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst = 1'b1;

        #20 rst = 1'b0;

        #400;

        $display("x21 actual = 0x%08h", u_CPU_Top.read_reg(21));
        $display("x22 actual = 0x%08h", u_CPU_Top.read_reg(22));
        $display("x23 actual = 0x%08h", u_CPU_Top.read_reg(23));

        $display("expected: x21=5, x22=8, x23=13");

        if (x21 !== 32'd5)
            $fatal(1, "Producer instruction failed; this is not only a RAW hazard");
        if (x22 !== 32'd8 || x23 !== 32'd13) begin
            $display("[OBSERVED] RAW hazard successfully reproduced.");
        end
        else begin
            $fatal(1, "Hazard was not reproduced; results are already correct.");
        end

        $finish;
    end

endmodule
