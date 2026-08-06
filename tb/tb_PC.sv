`timescale 1ns / 100ps

module tb_PC;

    logic        clk;
    logic        rst;
    logic        rst_pc_;
    logic        pc_write_en;
    logic [31:0] pc_next_;
    logic [31:0] pc;

    PC u_PC (
        .clk      (clk),
        .rst      (rst),
        .rst_pc_  (rst_pc_),
        .pc_write_en (pc_write_en),
        .pc_next_ (pc_next_),
        .pc       (pc)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic check_pc(
        input logic [31:0] expected,
        input string       test_name
    );
        begin
            // PC 使用 nonblocking assignment；等待 1ns 再檢查更新後的值。
            @(posedge clk);
            #1;
            if (pc !== expected) begin
                $fatal(1,
                    "[FAIL] %s: expected pc=0x%08h, got pc=0x%08h",
                    test_name, expected, pc
                );
            end
            $display("[PASS] %s: pc=0x%08h", test_name, pc);
        end
    endtask

    initial begin
        rst      = 1'b1;
        rst_pc_  = 1'b0;
        pc_write_en = 1'b1;
        pc_next_ = 32'hDEAD_BEEF;

        check_pc(32'h0000_0000, "rst clears PC");

        rst      = 1'b0;
        pc_next_ = 32'h0000_0004;
        check_pc(32'h0000_0004, "PC loads pc_next_");

        pc_next_ = 32'h0000_0008;
        check_pc(32'h0000_0008, "PC updates every cycle");

        rst_pc_  = 1'b1;
        pc_next_ = 32'h1234_5678;
        check_pc(32'h0000_0000, "rst_pc_ clears PC");

        // 即使 pc_next_ 不是 0，外部 rst 仍必須有最高優先權。
        rst      = 1'b1;
        rst_pc_  = 1'b0;
        pc_next_ = 32'hFFFF_FFFF;
        check_pc(32'h0000_0000, "rst has priority over pc_next_");

        rst      = 1'b0;
        pc_next_ = 32'h0000_000C;
        check_pc(32'h0000_000C, "PC resumes after reset");

        // write-enable 關閉時，即使 pc_next_ 改變，PC 仍必須保持舊值。
        @(negedge clk);
        pc_write_en = 1'b0;
        pc_next_    = 32'hAAAA_AAAA;
        check_pc(32'h0000_000C, "PC holds when write-enable is zero");

        // 外部 reset 的優先權高於 write-enable，因此 stall 時仍可清除 PC。
        @(negedge clk);
        rst      = 1'b1;
        pc_next_ = 32'hBBBB_BBBB;
        check_pc(32'h0000_0000, "rst overrides disabled write-enable");

        // 先恢復正常更新並載入非零值，才能有效測試 rst_pc_。
        @(negedge clk);
        rst         = 1'b0;
        pc_write_en = 1'b1;
        pc_next_    = 32'h0000_0020;
        check_pc(32'h0000_0020, "PC updates after stall is released");

        // Controller 的 rst_pc_ 同樣必須優先於 write-enable hold。
        @(negedge clk);
        pc_write_en = 1'b0;
        rst_pc_     = 1'b1;
        pc_next_    = 32'hCCCC_CCCC;
        check_pc(32'h0000_0000, "rst_pc_ overrides disabled write-enable");

        // 解除 rst_pc_ 後仍維持 stall，PC 應繼續保持 0。
        @(negedge clk);
        rst_pc_  = 1'b0;
        pc_next_ = 32'h0000_0024;
        check_pc(32'h0000_0000, "PC remains held after rst_pc_ is released");

        // 最後解除 stall，確認 PC 可再次載入 pc_next_。
        @(negedge clk);
        pc_write_en = 1'b1;
        check_pc(32'h0000_0024, "PC resumes after write-enable is restored");

        $display("[PASS] tb_PC completed.");
        $finish;
    end

endmodule
