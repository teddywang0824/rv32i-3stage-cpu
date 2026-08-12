`timescale 1ns / 100ps
`include "defines.sv"

module tb_Hazard_Observe;

    logic clk;
    logic rst;

    CPU_Sim_Top u_CPU_Top (
        .clk (clk),
        .rst (rst),
        .trap_ack(1'b0),
        .trap_redirect_pc(32'd0)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("build/hazard_observe.vcd");
        $dumpvars(0, tb_Hazard_Observe);
    end

    task automatic load_forwarding_program;
        integer i;
        begin
            for (i = 0; i < 64; i = i + 1)
                u_CPU_Top.u_Program_Rom.memory[i] = `I_NOP;

            u_CPU_Top.u_Program_Rom.memory[0] = 32'h0050_0A93; // addi x21,x0,5
            u_CPU_Top.u_Program_Rom.memory[1] = 32'h003A_8B13; // addi x22,x21,3
            u_CPU_Top.u_Program_Rom.memory[2] = 32'h015B_0BB3; // add  x23,x22,x21
        end
    endtask

    initial begin
        rst = 1'b1;
        load_forwarding_program();
        #20 rst = 1'b0;

        // 等待 ROM 中的三條相依指令完成目前的三級 pipeline。
        #400;

        $display("[CHECK] forwarding integration");
        $display("          expected: x21=5, x22=8, x23=13");
        $display("          actual:   x21=%0d, x22=%0d, x23=%0d",
            u_CPU_Top.read_reg(21),
            u_CPU_Top.read_reg(22),
            u_CPU_Top.read_reg(23)
        );

        // Forwarding 完成後，三條相依指令都必須符合 architectural result。
        if (u_CPU_Top.read_reg(21) !== 32'd5) begin
            $fatal(1,
                "[FAIL] producer x21 is incorrect: expected=5 actual=%0d",
                u_CPU_Top.read_reg(21)
            );
        end

        if (u_CPU_Top.read_reg(22) !== 32'd8) begin
            $fatal(1,
                "[FAIL] forwarded x22 is incorrect: expected=8 actual=%0d",
                u_CPU_Top.read_reg(22)
            );
        end

        if (u_CPU_Top.read_reg(23) !== 32'd13) begin
            $fatal(1,
                "[FAIL] forwarded x23 is incorrect: expected=13 actual=%0d",
                u_CPU_Top.read_reg(23)
            );
        end

        $display("[PASS] forwarding integration");

        $finish;
    end

endmodule
