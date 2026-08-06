`timescale 1ns / 100ps

module tb_IFID;

logic clk;
logic rst;
logic flush;
logic write_en;
logic [31:0] inst;
logic [31:0] inst_r;
logic [31:0] pc_;
logic [31:0] pc_r;

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

IFID u_IFID (
    .clk(clk),
    .rst(rst),
    .flush_IFID_(flush),
    .write_en_(write_en),
    .inst_(inst),
    .pc_(pc_),
    .inst_r(inst_r),
    .pc_r(pc_r)
);

initial begin
    rst = 1;
    flush = 0;
    write_en = 1;
    inst = 32'h5555_5555;
    pc_ = 32'h0000_0100;

    @(posedge clk);
    #1;
    rst = 0;
    if(inst_r !== 32'h0000_0013) $fatal(1, "[FAIL] rst fail");
    if(pc_r !== 32'h0000_0000) $fatal(1, "[FAIL] reset did not clear PC");
    $display("[PASS] reset inserts NOP");

    // keep inst
    @(posedge clk);
    #1;
    if (inst_r !== 32'h5555_5555) $fatal(1, "[FAIL] did not keep inst");
    if (pc_r !== 32'h0000_0100) $fatal(1, "[FAIL] did not capture PC");
    $display("[PASS] IF/ID captures instruction and PC");

    // inst_ 在兩個上升緣之間改變，inst_r 必須維持舊值。
    @(negedge clk);
    inst = 32'hAAAA_AAAA;
    pc_  = 32'h0000_0104;
    #1;
    if (inst_r !== 32'h5555_5555)
        $fatal(1, "[FAIL] inst_r changed before rising edge");
    if (pc_r !== 32'h0000_0100)
        $fatal(1, "[FAIL] pc_r changed before rising edge");
    $display("[PASS] IF/ID holds instruction and PC between rising edges");

    // 下一個上升緣才保存新的 inst_。
    @(posedge clk);
    #1;
    if (inst_r !== 32'hAAAA_AAAA)
        $fatal(1, "[FAIL] inst_r did not update on rising edge");
    if (pc_r !== 32'h0000_0104)
        $fatal(1, "[FAIL] pc_r did not update on rising edge");
    $display("[PASS] IF/ID updates instruction and PC on next rising edge");

    // write-enable=0 模擬 stall；輸入改變後，pipeline register 必須保持舊值。
    @(negedge clk);
    write_en = 1'b0;
    inst     = 32'hBBBB_BBBB;
    pc_      = 32'h0000_0108;

    @(posedge clk);
    #1;
    if (inst_r !== 32'hAAAA_AAAA)
        $fatal(1, "[FAIL] IF/ID did not hold while write-enable was zero");
    if (pc_r !== 32'h0000_0104)
        $fatal(1, "[FAIL] IF/ID PC did not hold while write-enable was zero");
    $display("[PASS] IF/ID holds instruction and PC while stalled");

    // 即使 write-enable=0，flush 仍必須優先插入 NOP。
    @(negedge clk);
    flush = 1'b1;
    inst  = 32'h1234_5678;
    pc_   = 32'h0000_010C;

    @(posedge clk);
    #1;
    if (inst_r !== 32'h0000_0013)
        $fatal(1, "[FAIL] flush did not insert NOP");
    if (pc_r !== 32'h0000_0000)
        $fatal(1, "[FAIL] flush did not clear PC");
    $display("[PASS] flush overrides hold, inserts NOP and clears PC");

    // 解除 flush 後恢復正常保存。
    @(negedge clk);
    flush = 1'b0;
    write_en = 1'b1;
    inst  = 32'hCAFE_BABE;
    pc_   = 32'h0000_0200;

    @(posedge clk);
    #1;
    if (inst_r !== 32'hCAFE_BABE)
        $fatal(1, "[FAIL] IF/ID did not resume after flush");
    if (pc_r !== 32'h0000_0200)
        $fatal(1, "[FAIL] IF/ID PC did not resume after flush");
    $display("[PASS] IF/ID resumes instruction and PC capture after flush");

    // 再次 reset 時即使 write-enable=0，仍應輸出 NOP。
    @(negedge clk);
    rst      = 1'b1;
    write_en = 1'b0;
    inst     = 32'hDEAD_BEEF;
    pc_      = 32'h0000_0204;

    @(posedge clk);
    #1;
    if (inst_r !== 32'h0000_0013)
        $fatal(1, "[FAIL] second reset did not insert NOP");
    if (pc_r !== 32'h0000_0000)
        $fatal(1, "[FAIL] second reset did not clear PC");
    $display("[PASS] reset overrides hold, inserts NOP and clears PC");

    // 解除 reset 與 stall，確認 IF/ID 可再次更新。
    @(negedge clk);
    rst      = 1'b0;
    write_en = 1'b1;
    inst     = 32'h0BAD_F00D;
    pc_      = 32'h0000_0300;

    @(posedge clk);
    #1;
    if (inst_r !== 32'h0BAD_F00D)
        $fatal(1, "[FAIL] IF/ID did not resume after stall was released");
    if (pc_r !== 32'h0000_0300)
        $fatal(1, "[FAIL] IF/ID PC did not resume after stall was released");
    $display("[PASS] IF/ID instruction and PC resume after stall is released");

    $display("[PASS] tb_IFID completed.");
    $finish;

end

endmodule
