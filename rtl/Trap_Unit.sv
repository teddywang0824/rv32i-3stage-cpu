module Trap_Unit (
    input  logic        clk,
    input  logic        rst,

    //CPU 內部送入 Trap Unit
    input  logic        trap_req_valid, // 發現錯誤 flag
    input  logic [3:0]  trap_req_cause, // trap 發生的例外種類
    input  logic [31:0] trap_req_pc, // 發生例外的那條指令地址
    input  logic [31:0] trap_req_tval, // 例外的補充資料

    //外部對 Trap Unit 的回應
    input  logic        trap_ack, //外部環境已經接收這筆 trap
    input  logic [31:0] trap_redirect_pc, //外部希望 CPU 接著從哪個地址重新取指

    output logic        trap_valid, // 是否有未完成握手的trap
    output logic [3:0]  trap_cause, 
    output logic [31:0] trap_pc,
    output logic [31:0] trap_tval,

    output logic        trap_pending, // 決定讓cpu是否因為 trap暫停
    output logic        trap_redirect, // 讓 cpu 重新 redirect
    output logic [31:0] trap_target // 重導向位置
);

    logic state;
    logic [3:0]  cause_r;
    logic [31:0] pc_r;
    logic [31:0] tval_r;

    assign trap_valid = state;
    assign trap_cause = cause_r;
    assign trap_pc = pc_r;
    assign trap_tval = tval_r;

    assign trap_pending = state;
    assign trap_redirect = (state && trap_ack);
    assign trap_target = trap_redirect_pc;

    always_ff @( posedge clk ) begin
        if ( rst ) begin
            state <= 0;
            cause_r   <= 4'd0;
            pc_r      <= 32'd0;
            tval_r    <= 32'd0;
        end else if (!state && trap_req_valid) begin
            state <= 1;
            cause_r   <= trap_req_cause;
            pc_r      <= trap_req_pc;
            tval_r    <= trap_req_tval;
        end else if (state && trap_ack) begin
            state <= 0;
            cause_r   <= 4'd0;
            pc_r      <= 32'd0;
            tval_r    <= 32'd0;
        end
    end

endmodule