`include "defines.sv"
module Load_Unit (
    input logic [2:0] load_op,
    input logic [31:0] address,
    input logic [31:0] read_data,

    output logic [31:0] load_value,
    output logic load_misaligned
);
    logic [4:0] shift_amount;
    logic [31:0] shift_data;

    assign shift_amount = {address[1:0], 3'b000};
    assign shift_data = read_data >> shift_amount;  

    always_comb begin
        load_misaligned = 0;
        load_value = 32'b0;
        case (load_op)
            `F3_LB, `F3_LBU: begin
                load_misaligned = 0;
                load_value = (load_op[2]) ? {24'b0, shift_data[7:0]} : {{24{shift_data[7]}}, shift_data[7:0]};
            end 
            `F3_LH, `F3_LHU: begin
                if (address[1:0] == 2'd0 || address[1:0] == 2'd2) begin
                    load_misaligned = 0;
                    load_value = (load_op[2]) ? {16'b0, shift_data[15:0]} : {{16{shift_data[15]}}, shift_data[15:0]};
                end else begin
                    load_misaligned = 1;
                end
            end
            `F3_LW: begin
                if (address[1:0] != 2'd0) load_misaligned = 1;
                else begin
                    load_misaligned = 0;
                    load_value = shift_data;
                end
            end
            default: begin
                load_misaligned = 1;
                load_value = 32'b0;
            end
        endcase
    end

endmodule