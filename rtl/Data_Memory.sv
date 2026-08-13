module Data_Memory #(
    parameter INIT_FILE = "",
    parameter integer WORDS = 1024
) (
    input logic clk,
    input logic mem_en,
    input logic mem_write,
    input logic [3:0] byte_enable,
    input logic [31:0] address, // [31:12] 預留，[11:2] 位置判斷，[1:0] byte offset
    input logic [31:0] write_data,

    output logic [31:0] read_data,
    output logic read_valid
);
    logic [31:0] memory [0:WORDS-1];
    integer i;

    initial begin
        for (i = 0; i < WORDS; i = i + 1)
            memory[i] = 32'd0;

        if (INIT_FILE != "")
            $readmemh(INIT_FILE, memory);
    end

    always_ff @(posedge clk) begin 
        if (mem_en && mem_write) begin
            if (byte_enable[3]) memory[address[31:2]][31:24] <= write_data[31:24];
            if (byte_enable[2]) memory[address[31:2]][23:16] <= write_data[23:16];
            if (byte_enable[1]) memory[address[31:2]][15:8] <= write_data[15:8];
            if (byte_enable[0]) memory[address[31:2]][7:0] <= write_data[7:0];
        end
    end

    always_ff @(posedge clk) begin
        if (mem_en && !mem_write) begin
            read_data <= memory[address[31:2]];
            read_valid <= 1;
        end else begin
            read_valid <= 0;
            read_data <= 0;
        end
    end

endmodule
