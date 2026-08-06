`timescale 1ns / 100ps

module tb_Hazard_Observe;

    logic clk;
    logic rst;

    CPU_Top u_CPU_Top (
        .clk (clk),
        .rst (rst)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("build/hazard_observe.vcd");
        $dumpvars(0, tb_Hazard_Observe);
    end

    initial begin
        rst = 1'b1;
        #20 rst = 1'b0;

        // 等待 ROM 中的三條相依指令完成目前的三級 pipeline。
        #400;

        $display("[CHECK] forwarding integration");
        $display("          expected: x21=5, x22=8, x23=13");
        $display("          actual:   x21=%0d, x22=%0d, x23=%0d",
            u_CPU_Top.u_Reg_File.regs[21],
            u_CPU_Top.u_Reg_File.regs[22],
            u_CPU_Top.u_Reg_File.regs[23]
        );

        // Forwarding 完成後，三條相依指令都必須符合 architectural result。
        if (u_CPU_Top.u_Reg_File.regs[21] !== 32'd5) begin
            $fatal(1,
                "[FAIL] producer x21 is incorrect: expected=5 actual=%0d",
                u_CPU_Top.u_Reg_File.regs[21]
            );
        end

        if (u_CPU_Top.u_Reg_File.regs[22] !== 32'd8) begin
            $fatal(1,
                "[FAIL] forwarded x22 is incorrect: expected=8 actual=%0d",
                u_CPU_Top.u_Reg_File.regs[22]
            );
        end

        if (u_CPU_Top.u_Reg_File.regs[23] !== 32'd13) begin
            $fatal(1,
                "[FAIL] forwarded x23 is incorrect: expected=13 actual=%0d",
                u_CPU_Top.u_Reg_File.regs[23]
            );
        end

        $display("[PASS] forwarding integration");

        $finish;
    end

endmodule
