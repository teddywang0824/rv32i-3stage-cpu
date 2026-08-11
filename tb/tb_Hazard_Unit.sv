`timescale 1ns / 100ps

module tb_Hazard_Unit;

    logic       ex_valid;
    logic       ex_mem_en;
    logic       ex_mem_write;
    logic       ex_reg_write;
    logic [4:0] ex_rd;
    logic       id_valid;
    logic       id_uses_rs1;
    logic       id_uses_rs2;
    logic [4:0] id_rs1;
    logic [4:0] id_rs2;
    logic       load_use_stall;

    Hazard_Unit dut (.*);

    task automatic check_hazard(
        input logic       test_ex_valid,
        input logic       test_ex_mem_en,
        input logic       test_ex_mem_write,
        input logic       test_ex_reg_write,
        input logic [4:0] test_ex_rd,
        input logic       test_id_valid,
        input logic       test_uses_rs1,
        input logic       test_uses_rs2,
        input logic [4:0] test_id_rs1,
        input logic [4:0] test_id_rs2,
        input logic       expected_stall,
        input string      test_name
    );
        begin
            ex_valid = test_ex_valid;
            ex_mem_en = test_ex_mem_en;
            ex_mem_write = test_ex_mem_write;
            ex_reg_write = test_ex_reg_write;
            ex_rd = test_ex_rd;
            id_valid = test_id_valid;
            id_uses_rs1 = test_uses_rs1;
            id_uses_rs2 = test_uses_rs2;
            id_rs1 = test_id_rs1;
            id_rs2 = test_id_rs2;
            #1;

            if (load_use_stall !== expected_stall)
                $fatal(1,
                    "[FAIL] %s: expected stall=%b actual=%b",
                    test_name, expected_stall, load_use_stall
                );

            $display("[PASS] %s", test_name);
        end
    endtask

    initial begin
        check_hazard(1'b1, 1'b1, 1'b0, 1'b1, 5'd7,
                     1'b1, 1'b1, 1'b0, 5'd7, 5'd0, 1'b1,
                     "Load rd matching used rs1 stalls");

        check_hazard(1'b1, 1'b1, 1'b0, 1'b1, 5'd7,
                     1'b1, 1'b0, 1'b1, 5'd0, 5'd7, 1'b1,
                     "Load rd matching used rs2 stalls");

        check_hazard(1'b1, 1'b1, 1'b0, 1'b1, 5'd7,
                     1'b1, 1'b1, 1'b1, 5'd7, 5'd7, 1'b1,
                     "Load rd matching both used sources produces one stall");

        check_hazard(1'b1, 1'b1, 1'b0, 1'b1, 5'd7,
                     1'b1, 1'b1, 1'b1, 5'd8, 5'd9, 1'b0,
                     "Different source registers do not stall");

        check_hazard(1'b1, 1'b1, 1'b0, 1'b1, 5'd7,
                     1'b1, 1'b0, 1'b0, 5'd7, 5'd7, 1'b0,
                     "Matching unused fields do not cause false stall");

        check_hazard(1'b1, 1'b1, 1'b0, 1'b1, 5'd7,
                     1'b1, 1'b1, 1'b0, 5'd8, 5'd7, 1'b0,
                     "I-type immediate bits resembling rs2 do not stall");

        check_hazard(1'b0, 1'b1, 1'b0, 1'b1, 5'd7,
                     1'b1, 1'b1, 1'b0, 5'd7, 5'd0, 1'b0,
                     "Invalid EX instruction does not stall");

        check_hazard(1'b1, 1'b0, 1'b0, 1'b1, 5'd7,
                     1'b1, 1'b1, 1'b0, 5'd7, 5'd0, 1'b0,
                     "EX instruction without memory request does not stall");

        check_hazard(1'b1, 1'b1, 1'b1, 1'b0, 5'd7,
                     1'b1, 1'b1, 1'b0, 5'd7, 5'd0, 1'b0,
                     "Store in EX does not stall as a Load");

        check_hazard(1'b1, 1'b1, 1'b0, 1'b0, 5'd7,
                     1'b1, 1'b1, 1'b0, 5'd7, 5'd0, 1'b0,
                     "Memory read without register write does not stall");

        check_hazard(1'b1, 1'b1, 1'b0, 1'b1, 5'd0,
                     1'b1, 1'b1, 1'b1, 5'd0, 5'd0, 1'b0,
                     "Load targeting x0 never stalls");

        check_hazard(1'b1, 1'b1, 1'b0, 1'b1, 5'd7,
                     1'b0, 1'b1, 1'b1, 5'd7, 5'd7, 1'b0,
                     "Invalid ID instruction does not stall");

        // Transition back to a hazard after several non-hazard cases catches
        // stale state or accidental latch behaviour in combinational logic.
        check_hazard(1'b1, 1'b1, 1'b0, 1'b1, 5'd12,
                     1'b1, 1'b1, 1'b0, 5'd12, 5'd3, 1'b1,
                     "Hazard output updates combinationally after transitions");

        $display("[PASS] tb_Hazard_Unit completed: 13 scenarios.");
        $finish;
    end

endmodule
