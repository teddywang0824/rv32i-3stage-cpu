`timescale 1ns / 100ps

module tb_Forwarding_Unit;

    logic        ex_reg_write;
    logic [4:0]  ex_rd;
    logic [31:0] rd_value_;
    logic        wb_reg_write;
    logic [4:0]  wb_rd;
    logic [31:0] wb_value;
    logic [4:0]  id_rs1;
    logic [4:0]  id_rs2;
    logic [31:0] rs1_value_;
    logic [31:0] rs2_value_;

    logic [31:0] forwarded_rs1_value;
    logic [31:0] forwarded_rs2_value;

    Forwarding_Unit u_Forwarding_Unit (
        .ex_reg_write       (ex_reg_write),
        .ex_rd              (ex_rd),
        .rd_value_          (rd_value_),
        .wb_reg_write       (wb_reg_write),
        .wb_rd              (wb_rd),
        .wb_value           (wb_value),
        .id_rs1             (id_rs1),
        .id_rs2             (id_rs2),
        .rs1_value_         (rs1_value_),
        .rs2_value_         (rs2_value_),
        .forwarded_rs1_value(forwarded_rs1_value),
        .forwarded_rs2_value(forwarded_rs2_value)
    );

    task automatic check_forwarding(
        input logic        test_reg_write,
        input logic [4:0]  test_ex_rd,
        input logic [4:0]  test_id_rs1,
        input logic [4:0]  test_id_rs2,
        input logic [31:0] test_rd_value,
        input logic [31:0] test_rs1_value,
        input logic [31:0] test_rs2_value,
        input logic [31:0] expected_rs1,
        input logic [31:0] expected_rs2,
        input string       test_name
    );
        begin
            ex_reg_write = test_reg_write;
            ex_rd         = test_ex_rd;
            id_rs1        = test_id_rs1;
            id_rs2        = test_id_rs2;
            rd_value_     = test_rd_value;
            rs1_value_    = test_rs1_value;
            rs2_value_    = test_rs2_value;
            #1;

            if (forwarded_rs1_value !== expected_rs1) begin
                $fatal(1,
                    "[FAIL] %s rs1: expected=0x%08h actual=0x%08h",
                    test_name, expected_rs1, forwarded_rs1_value
                );
            end

            if (forwarded_rs2_value !== expected_rs2) begin
                $fatal(1,
                    "[FAIL] %s rs2: expected=0x%08h actual=0x%08h",
                    test_name, expected_rs2, forwarded_rs2_value
                );
            end

            $display("[PASS] %s", test_name);
        end
    endtask

    initial begin
        wb_reg_write = 1'b0;
        wb_rd = 5'd0;
        wb_value = 32'd0;
        // 即使 rd 與兩個 source 都相同，RegWrite=0 時也不能 forwarding。
        check_forwarding(
            1'b0, 5'd5, 5'd5, 5'd5,
            32'hDEAD_BEEF, 32'h1111_1111, 32'h2222_2222,
            32'h1111_1111, 32'h2222_2222,
            "RegWrite=0 disables forwarding"
        );

        // x0 不可成為 forwarding 來源。
        check_forwarding(
            1'b1, 5'd0, 5'd0, 5'd0,
            32'hDEAD_BEEF, 32'h3333_3333, 32'h4444_4444,
            32'h3333_3333, 32'h4444_4444,
            "ex_rd=x0 disables forwarding"
        );

        // EX.rd 與 ID sources 都不同，保留 Register File 原值。
        check_forwarding(
            1'b1, 5'd5, 5'd1, 5'd2,
            32'hDEAD_BEEF, 32'h5555_5555, 32'h6666_6666,
            32'h5555_5555, 32'h6666_6666,
            "no source register matches"
        );

        // 只有 rs1 match。
        check_forwarding(
            1'b1, 5'd5, 5'd5, 5'd2,
            32'hABCD_1234, 32'h7777_7777, 32'h8888_8888,
            32'hABCD_1234, 32'h8888_8888,
            "only rs1 forwards EX result"
        );

        // 只有 rs2 match。
        check_forwarding(
            1'b1, 5'd5, 5'd1, 5'd5,
            32'hCAFE_BABE, 32'h9999_9999, 32'hAAAA_AAAA,
            32'h9999_9999, 32'hCAFE_BABE,
            "only rs2 forwards EX result"
        );

        // rs1、rs2 同時 match，兩路都應使用同一個 EX 結果。
        check_forwarding(
            1'b1, 5'd5, 5'd5, 5'd5,
            32'h1357_2468, 32'hBBBB_BBBB, 32'hCCCC_CCCC,
            32'h1357_2468, 32'h1357_2468,
            "rs1 and rs2 both forward EX result"
        );

        ex_reg_write = 1'b0;
        wb_reg_write = 1'b1;
        wb_rd = 5'd6;
        wb_value = 32'h2468_ACED;
        id_rs1 = 5'd6;
        id_rs2 = 5'd2;
        rs1_value_ = 32'h1111_1111;
        rs2_value_ = 32'h2222_2222;
        #1;
        if (forwarded_rs1_value !== 32'h2468_ACED ||
            forwarded_rs2_value !== 32'h2222_2222)
            $fatal(1, "[FAIL] WB forwarding");
        $display("[PASS] WB result forwards to rs1");

        ex_reg_write = 1'b1;
        ex_rd = 5'd6;
        rd_value_ = 32'hAAAA_5555;
        #1;
        if (forwarded_rs1_value !== 32'hAAAA_5555)
            $fatal(1, "[FAIL] EX must have priority over WB");
        $display("[PASS] EX forwarding has priority over WB");

        $display("[PASS] tb_Forwarding_Unit completed.");
        $finish;
    end

endmodule
