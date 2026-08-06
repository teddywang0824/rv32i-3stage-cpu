// cpu 用來記住目前要賭取哪一條指令的暫存器，本身不負責運算 pc + 4
module PC (
    input logic clk,
    input logic rst, //整個 cpu 的 reset，來自於外部
    input logic rst_pc_, // controller fsm 發出的 pc reset 訊號
    input logic [31:0] pc_next_,
    input logic pc_write_en,

    output logic [31:0] pc
);

    always_ff @(posedge clk) begin
        if (rst || rst_pc_)
            pc <= 32'h0000_0000;
        else if (pc_write_en)
            pc <= pc_next_;
    end

endmodule
