`timescale 1ns / 100ps
`include "defines.sv"

module tb_CPU_Retire;

    logic clk;
    logic rst;

    logic        retire_valid;
    logic [31:0] retire_pc;
    logic [31:0] retire_inst;
    logic        retire_rd_write;
    logic [4:0]  retire_rd;
    logic [31:0] retire_rd_data;
    logic        retire_mem_write;
    logic [31:0] retire_mem_addr;
    logic [31:0] retire_mem_data;
    logic [3:0]  retire_mem_byte_enable;

    integer retire_count;
    logic trace_done;
    logic illegal_seen_in_id;
    logic trap_valid;
    logic [3:0] trap_cause;
    logic [31:0] trap_pc;
    logic [31:0] trap_tval;
    integer trap_count;

    wire trap_ack = trap_valid;
    wire [31:0] trap_redirect_pc = trap_pc + 32'd4;

    CPU_Sim_Top u_CPU_Top (
        .clk                    (clk),
        .rst                    (rst),
        .trap_valid             (trap_valid),
        .trap_cause             (trap_cause),
        .trap_pc                (trap_pc),
        .trap_tval              (trap_tval),
        .trap_ack               (trap_ack),
        .trap_redirect_pc       (trap_redirect_pc),
        .retire_valid           (retire_valid),
        .retire_pc              (retire_pc),
        .retire_inst            (retire_inst),
        .retire_rd_write        (retire_rd_write),
        .retire_rd              (retire_rd),
        .retire_rd_data         (retire_rd_data),
        .retire_mem_write       (retire_mem_write),
        .retire_mem_addr        (retire_mem_addr),
        .retire_mem_data        (retire_mem_data),
        .retire_mem_byte_enable (retire_mem_byte_enable)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("build/cpu_retire.vcd");
        $dumpvars(0, tb_CPU_Retire);
    end

    function automatic logic [31:0] encode_addi(
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic signed [31:0] immediate
    );
        encode_addi = {immediate[11:0], rs1, `F_ADDI, rd, `Opcode_I};
    endfunction

    function automatic logic [31:0] encode_add(
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic [4:0] rs2
    );
        encode_add = {7'b0000000, rs2, rs1, `F_ADD_SUB, rd, `Opcode_R_M};
    endfunction

    function automatic logic [31:0] encode_lw(
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic signed [31:0] immediate
    );
        encode_lw = {immediate[11:0], rs1, `F3_LW, rd, `Opcode_LOAD};
    endfunction

    function automatic logic [31:0] encode_sw(
        input logic [4:0] rs1,
        input logic [4:0] rs2,
        input logic signed [31:0] immediate
    );
        logic [11:0] imm;
        begin
            imm = immediate[11:0];
            encode_sw = {imm[11:5], rs2, rs1, `F3_SW,
                         imm[4:0], `Opcode_STORE};
        end
    endfunction

    function automatic logic [31:0] encode_beq(
        input logic [4:0] rs1,
        input logic [4:0] rs2,
        input logic signed [31:0] offset
    );
        logic [12:0] imm;
        begin
            imm = offset[12:0];
            encode_beq = {imm[12], imm[10:5], rs2, rs1, `F3_BEQ,
                          imm[4:1], imm[11], `Opcode_BRANCH};
        end
    endfunction

    function automatic logic [31:0] encode_jal(
        input logic [4:0] rd,
        input logic signed [31:0] offset
    );
        logic [20:0] imm;
        begin
            imm = offset[20:0];
            encode_jal = {imm[20], imm[10:1], imm[11], imm[19:12],
                          rd, `Opcode_JAL};
        end
    endfunction

    function automatic logic [31:0] encode_jalr(
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic signed [31:0] immediate
    );
        encode_jalr = {immediate[11:0], rs1, `F3_JALR, rd, `Opcode_JALR};
    endfunction

    function automatic logic [31:0] encode_lui(
        input logic [4:0] rd,
        input logic [19:0] immediate
    );
        encode_lui = {immediate, rd, `Opcode_LUI};
    endfunction

    function automatic logic [31:0] encode_auipc(
        input logic [4:0] rd,
        input logic [19:0] immediate
    );
        encode_auipc = {immediate, rd, `Opcode_AUIPC};
    endfunction

    task automatic check_retire_event(input integer event_index);
        logic [31:0] expected_pc;
        logic [31:0] expected_inst;
        logic        expected_rd_write;
        logic [4:0]  expected_rd;
        logic [31:0] expected_rd_data;
        logic        expected_mem_write;
        logic [31:0] expected_mem_addr;
        logic [31:0] expected_mem_data;
        logic [3:0]  expected_mem_byte_enable;
        begin
            expected_pc = 32'd0;
            expected_inst = `I_NOP;
            expected_rd_write = 1'b0;
            expected_rd = 5'd0;
            expected_rd_data = 32'd0;
            expected_mem_write = 1'b0;
            expected_mem_addr = 32'd0;
            expected_mem_data = 32'd0;
            expected_mem_byte_enable = 4'd0;

            case (event_index)
                0: begin
                    expected_pc = 32'd0;
                    expected_inst = encode_addi(5'd1, 5'd0, 32'sd5);
                    expected_rd_write = 1'b1;
                    expected_rd = 5'd1;
                    expected_rd_data = 32'd5;
                end
                1: begin
                    expected_pc = 32'd4;
                    expected_inst = encode_addi(5'd2, 5'd0, 32'sd8);
                    expected_rd_write = 1'b1;
                    expected_rd = 5'd2;
                    expected_rd_data = 32'd8;
                end
                2: begin
                    expected_pc = 32'd8;
                    expected_inst = encode_add(5'd3, 5'd1, 5'd2);
                    expected_rd_write = 1'b1;
                    expected_rd = 5'd3;
                    expected_rd_data = 32'd13;
                end
                3: begin
                    expected_pc = 32'd12;
                    expected_inst = encode_sw(5'd0, 5'd3, 32'sd0);
                    expected_mem_write = 1'b1;
                    expected_mem_addr = 32'd0;
                    expected_mem_data = 32'd13;
                    expected_mem_byte_enable = 4'b1111;
                end
                4: begin
                    expected_pc = 32'd16;
                    expected_inst = encode_lw(5'd4, 5'd0, 32'sd0);
                    expected_rd_write = 1'b1;
                    expected_rd = 5'd4;
                    expected_rd_data = 32'd13;
                end
                5: begin
                    expected_pc = 32'd20;
                    expected_inst = encode_beq(5'd4, 5'd3, 32'sd8);
                end
                6: begin
                    expected_pc = 32'd28;
                    expected_inst = encode_jal(5'd6, 32'sd8);
                    expected_rd_write = 1'b1;
                    expected_rd = 5'd6;
                    expected_rd_data = 32'd32;
                end
                7: begin
                    expected_pc = 32'd36;
                    expected_inst = encode_addi(5'd8, 5'd0, 32'sd49);
                    expected_rd_write = 1'b1;
                    expected_rd = 5'd8;
                    expected_rd_data = 32'd49;
                end
                8: begin
                    expected_pc = 32'd40;
                    expected_inst = encode_jalr(5'd9, 5'd8, -32'sd1);
                    expected_rd_write = 1'b1;
                    expected_rd = 5'd9;
                    expected_rd_data = 32'd44;
                end
                9: begin
                    expected_pc = 32'd60;
                    expected_inst = encode_lui(5'd11, 20'h12345);
                    expected_rd_write = 1'b1;
                    expected_rd = 5'd11;
                    expected_rd_data = 32'h1234_5000;
                end
                10: begin
                    expected_pc = 32'd64;
                    expected_inst = encode_auipc(5'd12, 20'h00001);
                    expected_rd_write = 1'b1;
                    expected_rd = 5'd12;
                    expected_rd_data = 32'h0000_1040;
                end
                11: begin
                    expected_pc = 32'd68;
                    expected_inst = encode_jal(5'd0, 32'sd0);
                end
                default:
                    $fatal(1, "[FAIL] unexpected extra retire event %0d at PC=0x%08h",
                           event_index, retire_pc);
            endcase

            if (retire_pc !== expected_pc || retire_inst !== expected_inst)
                $fatal(1,
                    "[FAIL] retire[%0d] identity expected PC/inst=%08h/%08h actual=%08h/%08h",
                    event_index, expected_pc, expected_inst,
                    retire_pc, retire_inst
                );

            if (retire_rd_write !== expected_rd_write)
                $fatal(1,
                    "[FAIL] retire[%0d] rd_write expected=%b actual=%b",
                    event_index, expected_rd_write, retire_rd_write
                );

            if (expected_rd_write &&
                (retire_rd !== expected_rd || retire_rd_data !== expected_rd_data))
                $fatal(1,
                    "[FAIL] retire[%0d] rd expected x%0d=0x%08h actual x%0d=0x%08h",
                    event_index, expected_rd, expected_rd_data,
                    retire_rd, retire_rd_data
                );

            if (retire_mem_write !== expected_mem_write)
                $fatal(1,
                    "[FAIL] retire[%0d] mem_write expected=%b actual=%b",
                    event_index, expected_mem_write, retire_mem_write
                );

            if (expected_mem_write &&
                (retire_mem_addr !== expected_mem_addr ||
                 retire_mem_data !== expected_mem_data ||
                 retire_mem_byte_enable !== expected_mem_byte_enable))
                $fatal(1,
                    "[FAIL] retire[%0d] Store expected addr/data/be=%08h/%08h/%04b actual=%08h/%08h/%04b",
                    event_index,
                    expected_mem_addr, expected_mem_data, expected_mem_byte_enable,
                    retire_mem_addr, retire_mem_data, retire_mem_byte_enable
                );

            if (retire_rd_write && retire_mem_write)
                $fatal(1, "[FAIL] retire[%0d] reports register and memory writes together",
                       event_index);

            $display("[PASS] retire[%0d] PC=0x%08h inst=0x%08h",
                     event_index, retire_pc, retire_inst);
        end
    endtask

    always @(posedge clk) begin
        if (rst) begin
            retire_count = 0;
            trace_done = 1'b0;
            illegal_seen_in_id = 1'b0;
            trap_count = 0;
        end else begin
            if (u_CPU_Top.fetch_response_valid &&
                u_CPU_Top.fetch_response_pc == 32'd48 &&
                !u_CPU_Top.valid_inst_)
                illegal_seen_in_id = 1'b1;

            if (retire_valid) begin
                check_retire_event(retire_count);
                retire_count = retire_count + 1;
                if (retire_count == 12)
                    trace_done = 1'b1;
            end
            if (trap_valid)
                trap_count = trap_count + 1;
        end
    end

    initial begin
        integer i;

        rst = 1'b1;
        retire_count = 0;
        trace_done = 1'b0;
        illegal_seen_in_id = 1'b0;
        trap_count = 0;

        for (i = 0; i < 64; i = i + 1)
            u_CPU_Top.u_Program_Rom.memory[i] = `I_NOP;
        for (i = 0; i < 1024; i = i + 1)
            u_CPU_Top.u_Data_Memory.memory[i] = 32'd0;

        // Known words guard the encoders used to construct the independent
        // expected trace.
        if (encode_addi(5'd1, 5'd0, 32'sd5) !== 32'h0050_0093 ||
            encode_add(5'd3, 5'd1, 5'd2) !== 32'h0020_81B3 ||
            encode_sw(5'd0, 5'd3, 32'sd0) !== 32'h0030_2023 ||
            encode_beq(5'd4, 5'd3, 32'sd8) !== 32'h0032_0463 ||
            encode_jal(5'd6, 32'sd8) !== 32'h0080_036F ||
            encode_jalr(5'd9, 5'd8, -32'sd1) !== 32'hFFF4_04E7)
            $fatal(1, "[FAIL] retire testbench instruction encoder");

        // Taken control flow deliberately places a side-effecting instruction
        // on each wrong path.  Any failed flush changes the expected PC trace.
        u_CPU_Top.u_Program_Rom.memory[0]  = encode_addi(5'd1, 5'd0, 32'sd5);
        u_CPU_Top.u_Program_Rom.memory[1]  = encode_addi(5'd2, 5'd0, 32'sd8);
        u_CPU_Top.u_Program_Rom.memory[2]  = encode_add(5'd3, 5'd1, 5'd2);
        u_CPU_Top.u_Program_Rom.memory[3]  = encode_sw(5'd0, 5'd3, 32'sd0);
        u_CPU_Top.u_Program_Rom.memory[4]  = encode_lw(5'd4, 5'd0, 32'sd0);
        u_CPU_Top.u_Program_Rom.memory[5]  = encode_beq(5'd4, 5'd3, 32'sd8);
        u_CPU_Top.u_Program_Rom.memory[6]  = encode_addi(5'd5, 5'd0, 32'sd99);
        u_CPU_Top.u_Program_Rom.memory[7]  = encode_jal(5'd6, 32'sd8);
        u_CPU_Top.u_Program_Rom.memory[8]  = encode_addi(5'd7, 5'd0, 32'sd77);
        u_CPU_Top.u_Program_Rom.memory[9]  = encode_addi(5'd8, 5'd0, 32'sd49);
        u_CPU_Top.u_Program_Rom.memory[10] = encode_jalr(5'd9, 5'd8, -32'sd1);
        u_CPU_Top.u_Program_Rom.memory[11] = encode_addi(5'd10, 5'd0, 32'sd10);
        u_CPU_Top.u_Program_Rom.memory[12] = 32'hFFFF_FFFF;
        u_CPU_Top.u_Program_Rom.memory[13] = encode_sw(5'd0, 5'd3, 32'sd2);
        u_CPU_Top.u_Program_Rom.memory[14] = encode_lw(5'd13, 5'd0, 32'sd2);
        u_CPU_Top.u_Program_Rom.memory[15] = encode_lui(5'd11, 20'h12345);
        u_CPU_Top.u_Program_Rom.memory[16] = encode_auipc(5'd12, 20'h00001);
        u_CPU_Top.u_Program_Rom.memory[17] = encode_jal(5'd0, 32'sd0);

        repeat (3) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        wait (trace_done);
        #1;

        if (!illegal_seen_in_id)
            $fatal(1, "[FAIL] illegal instruction never reached ID");
        if (trap_count !== 3)
            $fatal(1, "[FAIL] expected illegal/Store/Load traps, got %0d events",
                   trap_count);
        if (u_CPU_Top.u_Data_Memory.memory[0] !== 32'd13)
            $fatal(1, "[FAIL] reference memory expected 13 actual=0x%08h",
                   u_CPU_Top.u_Data_Memory.memory[0]);
        if (u_CPU_Top.read_reg(1) !== 32'd5 ||
            u_CPU_Top.read_reg(2) !== 32'd8 ||
            u_CPU_Top.read_reg(3) !== 32'd13 ||
            u_CPU_Top.read_reg(4) !== 32'd13 ||
            u_CPU_Top.read_reg(5) !== 32'd0 ||
            u_CPU_Top.read_reg(6) !== 32'd32 ||
            u_CPU_Top.read_reg(7) !== 32'd0 ||
            u_CPU_Top.read_reg(8) !== 32'd49 ||
            u_CPU_Top.read_reg(9) !== 32'd44 ||
            u_CPU_Top.read_reg(10) !== 32'd0 ||
            u_CPU_Top.read_reg(11) !== 32'h1234_5000 ||
            u_CPU_Top.read_reg(12) !== 32'h0000_1040 ||
            u_CPU_Top.read_reg(13) !== 32'd0)
            $fatal(1, "[FAIL] final architectural register state mismatch");

        $display("[PASS] tb_CPU_Retire compared 12 ordered retire events.");
        $display("[PASS] wrong-path, illegal, and misaligned instructions produced no retire event.");
        $display("[PASS] three precise traps were acknowledged and skipped by the test handler.");
        $finish;
    end

    initial begin
        #5000;
        $fatal(1, "[FAIL] tb_CPU_Retire timeout after %0d events", retire_count);
    end

endmodule
