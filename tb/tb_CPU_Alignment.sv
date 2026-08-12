`timescale 1ns / 100ps
`include "defines.sv"

module tb_CPU_Alignment;
    logic clk;
    logic rst;
    logic trap_ack;
    logic [31:0] trap_redirect_pc;
    logic trap_valid;
    logic [3:0] trap_cause;
    logic [31:0] trap_pc;
    logic [31:0] trap_tval;
    logic retire_valid;
    logic [31:0] retire_pc;

    integer total_cycles;
    integer trap_event_count;
    integer dmem_request_count;
    integer completed_fault_cases;
    logic trap_valid_d;
    logic fault_case_active;

    CPU_Sim_Top dut (
        .clk(clk),
        .rst(rst),
        .trap_valid(trap_valid),
        .trap_cause(trap_cause),
        .trap_pc(trap_pc),
        .trap_tval(trap_tval),
        .trap_ack(trap_ack),
        .trap_redirect_pc(trap_redirect_pc),
        .retire_valid(retire_valid),
        .retire_pc(retire_pc)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    function automatic [31:0] encode_addi(
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic signed [31:0] immediate
    );
        encode_addi = {immediate[11:0], rs1, `F_ADDI, rd, `Opcode_I};
    endfunction

    function automatic [31:0] encode_branch(
        input logic [2:0] funct3,
        input logic [4:0] rs1,
        input logic [4:0] rs2,
        input logic signed [31:0] offset
    );
        logic [12:0] imm;
        begin
            imm = offset[12:0];
            encode_branch = {imm[12], imm[10:5], rs2, rs1, funct3,
                             imm[4:1], imm[11], `Opcode_BRANCH};
        end
    endfunction

    function automatic [31:0] encode_jal(
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

    function automatic [31:0] encode_jalr(
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic signed [31:0] immediate
    );
        encode_jalr = {immediate[11:0], rs1, `F3_JALR, rd, `Opcode_JALR};
    endfunction

    function automatic [31:0] encode_load(
        input logic [2:0] funct3,
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic signed [31:0] immediate
    );
        encode_load = {immediate[11:0], rs1, funct3, rd, `Opcode_LOAD};
    endfunction

    function automatic [31:0] encode_store(
        input logic [2:0] funct3,
        input logic [4:0] rs1,
        input logic [4:0] rs2,
        input logic signed [31:0] immediate
    );
        logic [11:0] imm;
        begin
            imm = immediate[11:0];
            encode_store = {imm[11:5], rs2, rs1, funct3,
                            imm[4:0], `Opcode_STORE};
        end
    endfunction

    task automatic clear_memories;
        integer i;
        begin
            for (i = 0; i < 64; i = i + 1)
                dut.u_Program_Rom.memory[i] = `I_NOP;
            for (i = 0; i < 1024; i = i + 1)
                dut.u_Data_Memory.memory[i] = 32'd0;
        end
    endtask

    task automatic begin_fault_case(input logic [31:0] fault_inst);
        begin
            @(negedge clk);
            rst = 1'b1;
            trap_ack = 1'b0;
            trap_redirect_pc = 32'd0;
            fault_case_active = 1'b0;
            clear_memories();
            dut.u_Program_Rom.memory[0] = fault_inst;
            dut.u_Program_Rom.memory[1] = encode_addi(5'd30, 5'd0, 30);
            dut.u_Program_Rom.memory[8] = encode_addi(5'd31, 5'd0, 31);
            repeat (3) @(posedge clk);
            @(negedge clk);
            rst = 1'b0;
            fault_case_active = 1'b1;
        end
    endtask

    task automatic expect_fault(
        input logic [3:0] expected_cause,
        input logic [31:0] expected_tval,
        input string name
    );
        integer timeout;
        begin
            timeout = 0;
            while (!trap_valid && timeout < 30) begin
                @(posedge clk);
                #1;
                timeout = timeout + 1;
            end
            if (!trap_valid)
                $fatal(1, "[FAIL] %s: timeout waiting for trap", name);
            if (trap_cause !== expected_cause || trap_pc !== 32'd0 ||
                trap_tval !== expected_tval)
                $fatal(1,
                    "[FAIL] %s metadata cause=%0d pc=%08h tval=%08h",
                    name, trap_cause, trap_pc, trap_tval);
            @(posedge clk);
            #1;
            if (!trap_valid || trap_cause !== expected_cause ||
                trap_pc !== 32'd0 || trap_tval !== expected_tval)
                $fatal(1, "[FAIL] %s pending metadata changed", name);
            if (trap_event_count !== 1)
                $fatal(1, "[FAIL] %s produced %0d trap events",
                       name, trap_event_count);
            if (dut.read_reg(30) !== 32'd0)
                $fatal(1, "[FAIL] %s younger instruction was not killed", name);
            if (dmem_request_count !== 0)
                $fatal(1, "[FAIL] %s fault issued a Data Memory request", name);

            @(negedge clk);
            trap_redirect_pc = 32'h0000_0020;
            trap_ack = 1'b1;
            @(posedge clk);
            #1;
            trap_ack = 1'b0;
            fault_case_active = 1'b0;
            if (trap_valid)
                $fatal(1, "[FAIL] %s did not clear after ack", name);

            timeout = 0;
            while (dut.read_reg(31) !== 32'd31 && timeout < 20) begin
                @(posedge clk);
                #1;
                timeout = timeout + 1;
            end
            if (dut.read_reg(31) !== 32'd31)
                $fatal(1, "[FAIL] %s did not resume at redirect PC", name);
            if (trap_event_count !== 1)
                $fatal(1, "[FAIL] %s trap reasserted after ack", name);

            completed_fault_cases = completed_fault_cases + 1;
            $display("[PASS] %s", name);
        end
    endtask

    task automatic run_control_faults;
        begin
            begin_fault_case(encode_branch(`F3_BEQ, 5'd1, 5'd2, 2));
            dut.write_reg(1, 32'd7);
            dut.write_reg(2, 32'd7);
            expect_fault(`TRAP_INST_ADDR_MISALIGNED, 32'd2,
                         "taken Branch rejects target PC+2");

            begin_fault_case(encode_jal(5'd5, 2));
            dut.write_reg(5, 32'h5555_5555);
            expect_fault(`TRAP_INST_ADDR_MISALIGNED, 32'd2,
                         "JAL rejects target PC+2 and suppresses link write");
            if (dut.read_reg(5) !== 32'h5555_5555)
                $fatal(1, "[FAIL] misaligned JAL modified rd");

            begin_fault_case(encode_jalr(5'd6, 5'd1, 0));
            dut.write_reg(1, 32'd3);
            dut.write_reg(6, 32'h6666_6666);
            expect_fault(`TRAP_INST_ADDR_MISALIGNED, 32'd2,
                         "JALR clears bit 0 then rejects target 2");
            if (dut.read_reg(6) !== 32'h6666_6666)
                $fatal(1, "[FAIL] misaligned JALR modified rd");
        end
    endtask

    task automatic run_not_taken_branch_boundary;
        integer timeout;
        begin
            @(negedge clk);
            rst = 1'b1;
            trap_ack = 1'b0;
            fault_case_active = 1'b0;
            clear_memories();
            dut.u_Program_Rom.memory[0] =
                encode_branch(`F3_BEQ, 5'd1, 5'd2, 2);
            dut.u_Program_Rom.memory[1] = encode_addi(5'd30, 5'd0, 30);
            repeat (3) @(posedge clk);
            @(negedge clk);
            rst = 1'b0;
            dut.write_reg(1, 32'd1);
            dut.write_reg(2, 32'd2);

            timeout = 0;
            while (dut.read_reg(30) !== 32'd30 && timeout < 20) begin
                @(posedge clk);
                #1;
                timeout = timeout + 1;
                if (trap_valid)
                    $fatal(1, "[FAIL] not-taken Branch reported misaligned target");
            end
            if (dut.read_reg(30) !== 32'd30)
                $fatal(1, "[FAIL] not-taken Branch did not continue sequentially");
            $display("[PASS] not-taken Branch ignores misaligned candidate target");
        end
    endtask

    task automatic run_load_fault(
        input logic [2:0] funct3,
        input integer offset,
        input string name
    );
        begin
            begin_fault_case(encode_load(funct3, 5'd5, 5'd1, offset));
            dut.write_reg(1, 32'd0);
            dut.write_reg(5, 32'hA5A5_A5A5);
            dut.u_Data_Memory.memory[0] = 32'h1122_3344;
            expect_fault(`TRAP_LOAD_ADDR_MISALIGNED, offset, name);
            if (dut.read_reg(5) !== 32'hA5A5_A5A5)
                $fatal(1, "[FAIL] %s modified destination register", name);
        end
    endtask

    task automatic run_store_fault(
        input logic [2:0] funct3,
        input integer offset,
        input string name
    );
        begin
            begin_fault_case(encode_store(funct3, 5'd1, 5'd2, offset));
            dut.write_reg(1, 32'd0);
            dut.write_reg(2, 32'hAABB_CCDD);
            dut.u_Data_Memory.memory[0] = 32'hCAFE_BABE;
            expect_fault(`TRAP_STORE_ADDR_MISALIGNED, offset, name);
            if (dut.u_Data_Memory.memory[0] !== 32'hCAFE_BABE)
                $fatal(1, "[FAIL] %s modified memory", name);
        end
    endtask

    always @(posedge clk) begin
        total_cycles = total_cycles + 1;
        if (total_cycles > 900)
            $fatal(1, "[FAIL] alignment integration global timeout");

        if (rst) begin
            trap_valid_d <= 1'b0;
            trap_event_count = 0;
            dmem_request_count = 0;
        end else begin
            if (trap_valid && !trap_valid_d)
                trap_event_count = trap_event_count + 1;
            trap_valid_d <= trap_valid;
            if (dut.dmem_req_valid)
                dmem_request_count = dmem_request_count + 1;
            if (fault_case_active && retire_valid && retire_pc == 32'd0)
                $fatal(1, "[FAIL] faulting alignment instruction retired");
        end
    end

    initial begin
        rst = 1'b1;
        trap_ack = 1'b0;
        trap_redirect_pc = 32'd0;
        total_cycles = 0;
        trap_event_count = 0;
        dmem_request_count = 0;
        completed_fault_cases = 0;
        trap_valid_d = 1'b0;
        fault_case_active = 1'b0;
        clear_memories();

        run_control_faults();
        run_not_taken_branch_boundary();

        run_load_fault(`F3_LH,  1, "LH rejects odd address");
        run_load_fault(`F3_LHU, 1, "LHU rejects odd address");
        run_load_fault(`F3_LW,  1, "LW rejects byte offset 1");
        run_load_fault(`F3_LW,  2, "LW rejects byte offset 2");
        run_load_fault(`F3_LW,  3, "LW rejects byte offset 3");

        run_store_fault(`F3_SH, 1, "SH rejects byte offset 1");
        run_store_fault(`F3_SH, 3, "SH rejects byte offset 3");
        run_store_fault(`F3_SW, 1, "SW rejects byte offset 1");
        run_store_fault(`F3_SW, 2, "SW rejects byte offset 2");
        run_store_fault(`F3_SW, 3, "SW rejects byte offset 3");

        if (completed_fault_cases !== 13)
            $fatal(1, "[FAIL] expected 13 alignment fault cases, got %0d",
                   completed_fault_cases);

        $display("[PASS] tb_CPU_Alignment completed: 13 precise fault cases plus not-taken boundary.");
        $finish;
    end
endmodule
