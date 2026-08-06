`timescale 1ns / 100ps

module tb_CPU_Top ;

    logic clk;
    logic rst;
    logic saw_x4_write;
    logic saw_x15_write;
    logic saw_x24_write;
    logic saw_x25_write;

    CPU_Top u_CPU_Top (
        .clk(clk),
        .rst(rst)
    );

    // 產生波形檔，之後可使用 GTKWave 查看 pipeline 訊號。
    initial begin
        $dumpfile("build/cpu_top.vcd");
        $dumpvars(0, tb_CPU_Top);
    end

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Step 13 directed instructions. Program ROM currently uses these addresses
    // as NOP, so the testbench injects one instruction for each fetch cycle.
    // 0x0000005C: lui   x24, 0x12345
    // 0x00000060: auipc x25, 0x00001
    initial begin
        wait (rst === 1'b0);
        wait (u_CPU_Top.pc === 32'h0000_005C);
        force u_CPU_Top.inst_ = 32'h1234_5C37;
        @(posedge clk);
        #1;
        release u_CPU_Top.inst_;

        wait (u_CPU_Top.pc === 32'h0000_0060);
        force u_CPU_Top.inst_ = 32'h0000_1C97;
        @(posedge clk);
        #1;
        release u_CPU_Top.inst_;
    end

    // x4 的預期結果是 0，僅檢查最終值無法區分「正確寫回 0」和「從未執行」。
    // 因此另外記錄是否真的發生過對 x4 的 write-back。
    always @(posedge clk) begin
        if (rst) begin
            saw_x4_write <= 1'b0;
            saw_x15_write <= 1'b0;
            saw_x24_write <= 1'b0;
            saw_x25_write <= 1'b0;
        end
        else begin
            if (u_CPU_Top.write_regf_en_r && u_CPU_Top.addr_rd_r == 5'd4)
                saw_x4_write <= 1'b1;
            if (u_CPU_Top.write_regf_en_r && u_CPU_Top.addr_rd_r == 5'd15)
                saw_x15_write <= 1'b1;
            if (u_CPU_Top.write_regf_en_r && u_CPU_Top.addr_rd_r == 5'd24)
                saw_x24_write <= 1'b1;
            if (u_CPU_Top.write_regf_en_r && u_CPU_Top.addr_rd_r == 5'd25)
                saw_x25_write <= 1'b1;
        end
    end

    initial begin
        rst = 1'b1;
        
        #20 rst = 1'b0;

        #300;

        if (u_CPU_Top.u_Reg_File.regs[1] !== 32'hFFFF_FFFB) begin
            $fatal(1,
                "[FAIL] x1: expected=0x%08h actual=0x%08h",
                32'hFFFF_FFFB,
                u_CPU_Top.u_Reg_File.regs[1]
            );
        end

        if (u_CPU_Top.u_Reg_File.regs[2] !== 32'h0000_0001) begin
            $fatal(1,
                "[FAIL] x2: expected=0x%08h actual=0x%08h",
                32'h0000_0001,
                u_CPU_Top.u_Reg_File.regs[2]
            );
        end

        // slti x3, x0, 6：有號比較 0 < 6，結果應為 1。
        if (u_CPU_Top.u_Reg_File.regs[3] !== 32'h0000_0001) begin
            $fatal(1,
                "[FAIL] x3 (SLTI): expected=0x%08h actual=0x%08h",
                32'h0000_0001,
                u_CPU_Top.u_Reg_File.regs[3]
            );
        end

        // sltiu x4, x1, 6：0xFFFF_FFFB 作無號數時大於 6，結果應為 0。
        if (u_CPU_Top.u_Reg_File.regs[4] !== 32'h0000_0000) begin
            $fatal(1,
                "[FAIL] x4 (SLTIU): expected=0x%08h actual=0x%08h",
                32'h0000_0000,
                u_CPU_Top.u_Reg_File.regs[4]
            );
        end

        if (saw_x4_write !== 1'b1) begin
            $fatal(1, "[FAIL] x4 (SLTIU) never reached write-back");
        end

        // andi x5, x2, 2047：1 & 2047，結果應為 1。
        if (u_CPU_Top.u_Reg_File.regs[5] !== 32'h0000_0001) begin
            $fatal(1,
                "[FAIL] x5 (ANDI): expected=0x%08h actual=0x%08h",
                32'h0000_0001,
                u_CPU_Top.u_Reg_File.regs[5]
            );
        end

        // xori x6, x0, -1：0 XOR 0xFFFF_FFFF。
        if (u_CPU_Top.u_Reg_File.regs[6] !== 32'hFFFF_FFFF) begin
            $fatal(1,
                "[FAIL] x6 (XORI): expected=0x%08h actual=0x%08h",
                32'hFFFF_FFFF,
                u_CPU_Top.u_Reg_File.regs[6]
            );
        end

        // ori x7, x0, 0x55：0 OR 0x55。
        if (u_CPU_Top.u_Reg_File.regs[7] !== 32'h0000_0055) begin
            $fatal(1,
                "[FAIL] x7 (ORI): expected=0x%08h actual=0x%08h",
                32'h0000_0055,
                u_CPU_Top.u_Reg_File.regs[7]
            );
        end

        // slli x8, x2, 4：1 << 4。
        if (u_CPU_Top.u_Reg_File.regs[8] !== 32'h0000_0010) begin
            $fatal(1,
                "[FAIL] x8 (SLLI): expected=0x%08h actual=0x%08h",
                32'h0000_0010,
                u_CPU_Top.u_Reg_File.regs[8]
            );
        end

        // srli x9, x6, 4：0xFFFF_FFFF 邏輯右移 4 位。
        if (u_CPU_Top.u_Reg_File.regs[9] !== 32'h0FFF_FFFF) begin
            $fatal(1,
                "[FAIL] x9 (SRLI): expected=0x%08h actual=0x%08h",
                32'h0FFF_FFFF,
                u_CPU_Top.u_Reg_File.regs[9]
            );
        end

        // srai x10, x6, 4：0xFFFF_FFFF 算術右移仍為 -1。
        if (u_CPU_Top.u_Reg_File.regs[10] !== 32'hFFFF_FFFF) begin
            $fatal(1,
                "[FAIL] x10 (SRAI): expected=0x%08h actual=0x%08h",
                32'hFFFF_FFFF,
                u_CPU_Top.u_Reg_File.regs[10]
            );
        end

        if (u_CPU_Top.u_Reg_File.regs[11] !== 32'h0000_0011) begin
            $fatal(1,
                "[FAIL] x11 (ADD): expected=0x%08h actual=0x%08h",
                32'h0000_0011,
                u_CPU_Top.u_Reg_File.regs[11]
            );
        end

        if (u_CPU_Top.u_Reg_File.regs[12] !== 32'hFFFF_FFF1) begin
            $fatal(1,
                "[FAIL] x12 (SUB): expected=0x%08h actual=0x%08h",
                32'hFFFF_FFF1,
                u_CPU_Top.u_Reg_File.regs[12]
            );
        end

        if (u_CPU_Top.u_Reg_File.regs[13] !== 32'h0000_0002) begin
            $fatal(1,
                "[FAIL] x13 (SLL): expected=0x%08h actual=0x%08h",
                32'h0000_0002,
                u_CPU_Top.u_Reg_File.regs[13]
            );
        end

        if (u_CPU_Top.u_Reg_File.regs[14] !== 32'h0000_0001) begin
            $fatal(1,
                "[FAIL] x14 (SLT): expected=0x%08h actual=0x%08h",
                32'h0000_0001,
                u_CPU_Top.u_Reg_File.regs[14]
            );
        end

        // x1 的 bit pattern 以 unsigned 解讀時大於 x2，因此 SLTU 結果為 0。
        if (u_CPU_Top.u_Reg_File.regs[15] !== 32'h0000_0000) begin
            $fatal(1,
                "[FAIL] x15 (SLTU): expected=0x%08h actual=0x%08h",
                32'h0000_0000,
                u_CPU_Top.u_Reg_File.regs[15]
            );
        end

        if (saw_x15_write !== 1'b1) begin
            $fatal(1, "[FAIL] x15 (SLTU) never reached write-back");
        end

        if (u_CPU_Top.u_Reg_File.regs[16] !== 32'hFFFF_FFAA) begin
            $fatal(1,
                "[FAIL] x16 (XOR): expected=0x%08h actual=0x%08h",
                32'hFFFF_FFAA,
                u_CPU_Top.u_Reg_File.regs[16]
            );
        end

        if (u_CPU_Top.u_Reg_File.regs[17] !== 32'h7FFF_FFFF) begin
            $fatal(1,
                "[FAIL] x17 (SRL): expected=0x%08h actual=0x%08h",
                32'h7FFF_FFFF,
                u_CPU_Top.u_Reg_File.regs[17]
            );
        end

        if (u_CPU_Top.u_Reg_File.regs[18] !== 32'hFFFF_FFFF) begin
            $fatal(1,
                "[FAIL] x18 (SRA): expected=0x%08h actual=0x%08h",
                32'hFFFF_FFFF,
                u_CPU_Top.u_Reg_File.regs[18]
            );
        end

        if (u_CPU_Top.u_Reg_File.regs[19] !== 32'h0000_0055) begin
            $fatal(1,
                "[FAIL] x19 (OR): expected=0x%08h actual=0x%08h",
                32'h0000_0055,
                u_CPU_Top.u_Reg_File.regs[19]
            );
        end

        if (u_CPU_Top.u_Reg_File.regs[20] !== 32'h0000_0010) begin
            $fatal(1,
                "[FAIL] x20 (AND): expected=0x%08h actual=0x%08h",
                32'h0000_0010,
                u_CPU_Top.u_Reg_File.regs[20]
            );
        end

        // LUI 必須忽略 rs1 欄位，將 U-immediate 原樣寫回。
        if (u_CPU_Top.u_Reg_File.regs[24] !== 32'h1234_5000) begin
            $fatal(1,
                "[FAIL] x24 (LUI): expected=0x%08h actual=0x%08h",
                32'h1234_5000,
                u_CPU_Top.u_Reg_File.regs[24]
            );
        end

        if (saw_x24_write !== 1'b1)
            $fatal(1, "[FAIL] x24 (LUI) never reached write-back");

        // AUIPC 位於 PC=0x60，因此結果必須是 0x60 + 0x1000。
        if (u_CPU_Top.u_Reg_File.regs[25] !== 32'h0000_1060) begin
            $fatal(1,
                "[FAIL] x25 (AUIPC): expected=0x%08h actual=0x%08h",
                32'h0000_1060,
                u_CPU_Top.u_Reg_File.regs[25]
            );
        end

        if (saw_x25_write !== 1'b1)
            $fatal(1, "[FAIL] x25 (AUIPC) never reached write-back");

        if (u_CPU_Top.u_Reg_File.regs[0] !== 32'h0000_0000) begin
            $fatal(1,
                "[FAIL] x0 must remain zero: actual=0x%08h",
                u_CPU_Top.u_Reg_File.regs[0]
            );
        end

        $display("[PASS] x1 = 0x%08h", u_CPU_Top.u_Reg_File.regs[1]);
        $display("[PASS] x2 = 0x%08h", u_CPU_Top.u_Reg_File.regs[2]);
        $display("[PASS] x3 = 0x%08h (SLTI)", u_CPU_Top.u_Reg_File.regs[3]);
        $display("[PASS] x4 = 0x%08h (SLTIU)", u_CPU_Top.u_Reg_File.regs[4]);
        $display("[PASS] x5 = 0x%08h (ANDI)", u_CPU_Top.u_Reg_File.regs[5]);
        $display("[PASS] x6 = 0x%08h (XORI)", u_CPU_Top.u_Reg_File.regs[6]);
        $display("[PASS] x7 = 0x%08h (ORI)", u_CPU_Top.u_Reg_File.regs[7]);
        $display("[PASS] x8 = 0x%08h (SLLI)", u_CPU_Top.u_Reg_File.regs[8]);
        $display("[PASS] x9 = 0x%08h (SRLI)", u_CPU_Top.u_Reg_File.regs[9]);
        $display("[PASS] x10 = 0x%08h (SRAI)", u_CPU_Top.u_Reg_File.regs[10]);
        $display("[PASS] x11 = 0x%08h (ADD)", u_CPU_Top.u_Reg_File.regs[11]);
        $display("[PASS] x12 = 0x%08h (SUB)", u_CPU_Top.u_Reg_File.regs[12]);
        $display("[PASS] x13 = 0x%08h (SLL)", u_CPU_Top.u_Reg_File.regs[13]);
        $display("[PASS] x14 = 0x%08h (SLT)", u_CPU_Top.u_Reg_File.regs[14]);
        $display("[PASS] x15 = 0x%08h (SLTU, write-back observed)", u_CPU_Top.u_Reg_File.regs[15]);
        $display("[PASS] x16 = 0x%08h (XOR)", u_CPU_Top.u_Reg_File.regs[16]);
        $display("[PASS] x17 = 0x%08h (SRL)", u_CPU_Top.u_Reg_File.regs[17]);
        $display("[PASS] x18 = 0x%08h (SRA)", u_CPU_Top.u_Reg_File.regs[18]);
        $display("[PASS] x19 = 0x%08h (OR)", u_CPU_Top.u_Reg_File.regs[19]);
        $display("[PASS] x20 = 0x%08h (AND)", u_CPU_Top.u_Reg_File.regs[20]);
        $display("[PASS] x24 = 0x%08h (LUI)", u_CPU_Top.u_Reg_File.regs[24]);
        $display("[PASS] x25 = 0x%08h (AUIPC at PC 0x00000060)", u_CPU_Top.u_Reg_File.regs[25]);
        $display("[PASS] x0 remains zero");
        $display("[PASS] tb_CPU_Top completed.");
        $finish;
    end    

endmodule
