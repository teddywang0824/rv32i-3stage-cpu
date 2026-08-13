`timescale 1ns / 100ps

// Simulation-only unified memory used by the ACT4 adapter.  The image is a
// sparse, word-oriented $readmemh file selected at runtime with +MEM_HEX=...
module Arch_Test_Memory #(
    parameter integer WORDS = 8388608,
    parameter integer REQUIRE_IMAGE = 1
) (
    input  logic        clk,
    input  logic        rst,

    input  logic        fetch_en,
    input  logic        kill_response,
    input  logic [31:0] fetch_addr,
    output logic        imem_response_valid,
    output logic [31:0] imem_response_pc,
    output logic [31:0] imem_response_inst,

    input  logic        dmem_en,
    input  logic        dmem_write,
    input  logic [3:0]  dmem_byte_enable,
    input  logic [31:0] dmem_addr,
    input  logic [31:0] dmem_write_data,
    output logic        dmem_read_valid,
    output logic [31:0] dmem_read_data
);
    logic [31:0] memory [0:WORDS-1];
    string image_file;

    initial begin
        if (REQUIRE_IMAGE) begin
            if (!$value$plusargs("MEM_HEX=%s", image_file))
                $fatal(1, "[ACT4] missing +MEM_HEX=<sparse word hex>");
            $readmemh(image_file, memory);
        end
    end

    always_ff @(posedge clk) begin
        if (rst || kill_response) begin
            imem_response_valid <= 1'b0;
        end else if (fetch_en) begin
            if (fetch_addr[31:2] >= WORDS)
                $fatal(1, "[ACT4] instruction address out of range: %08h", fetch_addr);
            imem_response_pc <= fetch_addr;
            imem_response_inst <= memory[fetch_addr[31:2]];
            imem_response_valid <= 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (dmem_en && dmem_write) begin
            if (dmem_addr[31:2] >= WORDS)
                $fatal(1, "[ACT4] data write address out of range: %08h", dmem_addr);
            if (dmem_byte_enable[3]) memory[dmem_addr[31:2]][31:24] <= dmem_write_data[31:24];
            if (dmem_byte_enable[2]) memory[dmem_addr[31:2]][23:16] <= dmem_write_data[23:16];
            if (dmem_byte_enable[1]) memory[dmem_addr[31:2]][15:8]  <= dmem_write_data[15:8];
            if (dmem_byte_enable[0]) memory[dmem_addr[31:2]][7:0]   <= dmem_write_data[7:0];
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            dmem_read_valid <= 1'b0;
            dmem_read_data <= 32'd0;
        end else if (dmem_en && !dmem_write) begin
            if (dmem_addr[31:2] >= WORDS)
                $fatal(1, "[ACT4] data read address out of range: %08h", dmem_addr);
            dmem_read_data <= memory[dmem_addr[31:2]];
            dmem_read_valid <= 1'b1;
        end else begin
            dmem_read_valid <= 1'b0;
            dmem_read_data <= 32'd0;
        end
    end
endmodule
