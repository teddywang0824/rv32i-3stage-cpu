`include "defines.sv"

module Store_Unit (
    input logic [2:0] store_op,
    // Only the byte offset is consumed here; the full effective address is
    // retained at the port so the unit contract remains explicit.
    /* verilator lint_off UNUSED */
    input logic [31:0] address,
    /* verilator lint_on UNUSED */
    input logic [31:0] value,

    output logic [3:0] byte_enable,
    output logic [31:0] aligned_write_data,
    output logic misaligned
);

    logic [1:0] address_offset;
    logic [4:0] shift_amount;

    assign address_offset = address[1:0];
    assign shift_amount   = {address[1:0], 3'b000};

    always_comb begin
        byte_enable        = 4'b0000;
        aligned_write_data = 32'b0;
        misaligned         = 1'b0;
        case (store_op)
            `F3_SB: begin
                byte_enable = 4'b0001 << address_offset;
                aligned_write_data = {24'b0, value[7:0]} << shift_amount;
            end
            `F3_SH: begin
                if (address_offset != 2'd0 && address_offset != 2'd2) begin
                    misaligned = 1;
                end else begin
                    byte_enable = 4'b0011 << address_offset;
                    aligned_write_data = {16'b0, value[15:0]} << shift_amount;
                end
            end
            `F3_SW: begin
                if (address_offset != 2'd0) begin
                    misaligned = 1;
                end else begin
                    byte_enable = 4'b1111;
                    aligned_write_data = value;
                end
            end
            default: begin
                byte_enable        = 4'b0000;
                aligned_write_data = 32'b0;
                misaligned         = 1'b0;
            end 
        endcase
    end
    
endmodule
