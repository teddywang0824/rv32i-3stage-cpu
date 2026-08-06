// 簡易的 FSM，根據投影片 三層 pipeline 會在 INIT 的兩個狀態 S0、S1 發出 flush 和 rst_pc_ 訊號
// 進入 S2 後才開始每個 clock 正常更新 PC、IF/ID、ID/EX
// 註解 : 因為是三級管線，有兩個暫存。所以需要兩個state做初始化
module Controller (
    input logic clk,
    input logic rst,

    output logic flush_IFID_,
    output logic flush_IDEX_,
    output logic rst_pc_
);

    typedef enum logic [1:0] {
        S0,
        S1,
        S2
    } state_t;

    state_t state_r, state_w;

    // current state
    always_ff @(posedge clk) begin
        if (rst) state_r <= S0;
        else state_r <= state_w;
    end

    // next state
    always_comb begin
        unique case (state_r) 
            S0: state_w = S1;
            S1: state_w = S2;
            S2: state_w = S2;
            default: state_w = S0;
        endcase
    end

    always_comb begin
        flush_IFID_ = 1'b0;
        flush_IDEX_ = 1'b0;
        rst_pc_ = 1'b0;

        unique case (state_r) 
            S0: begin
                flush_IFID_ = 1'b1;
                flush_IDEX_ = 1'b1;
                rst_pc_ = 1'b1;
            end
            S1: begin
                flush_IFID_ = 1'b1;
                flush_IDEX_ = 1'b1;
                rst_pc_ = 1'b1;
            end
            S2: begin
                flush_IFID_ = 1'b0;
                flush_IDEX_ = 1'b0;
                rst_pc_ = 1'b0;
            end
            default: begin
                flush_IFID_ = 1'b1;
                flush_IDEX_ = 1'b1;
                rst_pc_ = 1'b1;
            end
        endcase
    end
    
endmodule