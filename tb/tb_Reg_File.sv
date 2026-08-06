`timescale 1ns / 100ps

module tb_Reg_File;

logic        clk;
logic        rst;
logic        write_regf_en_r;
logic [4:0]  addr_rd_r;
logic [31:0] rd_value_;
logic [4:0]  addr_rs1_;
logic [4:0]  addr_rs2_;
logic [31:0] rs1_value_;
logic [31:0] rs2_value_;

initial begin
	clk = 1'b0;
	forever #5 clk = ~clk;
end

Reg_File Reg_File(
	.clk(clk),
	.rst(rst),
	.write_regf_en_r(write_regf_en_r), //寫入enable
	.addr_rd_r(addr_rd_r), // 要寫入的暫存器
	.rd_value_(rd_value_), // 寫入目標位置的資料
	.addr_rs1_(addr_rs1_), // 讀取的第一個暫存器
	.addr_rs2_(addr_rs2_), // 讀取的第二個暫存器
	.rs1_value_(rs1_value_), // 讀取的第一個暫存器輸出
	.rs2_value_(rs2_value_)  // 讀取的第二個暫存器輸出
);

initial begin
	rst  = 1;
	write_regf_en_r = 0;
	addr_rd_r = 0;
	rd_value_ = 0;
	addr_rs1_ = 1;
	addr_rs2_ = 2;

	@(posedge clk);
	#1;

	if (rs1_value_ !== 32'd0) $fatal(1, "[FAIL] reset did not clear rs1");
	if (rs2_value_ !== 32'd0) $fatal(1, "[FAIL] reset did not clear rs2");

	// 嘗試寫入 x0，應該要為0
	@(negedge clk)
	rst = 1'b0;
	write_regf_en_r = 1;
	addr_rd_r = 5'd0;
	rd_value_ = 32'h5555_5555;

	@(posedge clk)
	#1;
	write_regf_en_r = 0;
	addr_rs1_ = 5'd0;
	#1;
	if (rs1_value_ !== 0) $fatal(1, "[FAIL] x0 has been modified!");

	// 測試 rs1
	@(negedge clk);
	write_regf_en_r = 1'b1;
	addr_rd_r       = 5'd1;
	rd_value_       = 32'h1234_5678;

	@(posedge clk);
	#1;
	write_regf_en_r = 1'b0;
	addr_rs1_ = 5'd1; // x1，也就是剛寫進去的位置
	#1;
	if (rs1_value_ !== 32'h1234_5678) $fatal(1, "[FAIL] x1 write test ERROR");


	// 測試rs2、並測試rs1
	@(negedge clk);
	write_regf_en_r = 1'b1;
	addr_rd_r = 5'd2;
	rd_value_ = 32'h9876_5432;

	@(posedge clk);
	#1
	write_regf_en_r = 0;
	addr_rs2_ = 5'd2;
	#1;
	if (rs2_value_ !== 32'h9876_5432) $fatal(1, "[FAIL] x2 write test ERROR");
	if (rs1_value_ !== 32'h1234_5678) $fatal(1, "[FAIL] x1 read test ERROR");


	// write_regf_en_r = 0 時嘗試改寫 x2
	@(negedge clk)
	addr_rd_r = 5'd2;
	rd_value_ = 32'h6666_6666;
	
	@(posedge clk)
	#1;
	addr_rs2_ = 5'd2;
	#1;
	if (rs2_value_ !== 32'h9876_5432) $fatal(1, "[FAIL] enable is not working");

	// 第二次 reset 確認
	@(negedge clk)
	rst = 1;

	@(posedge clk)
	#1;
	rst = 0;
	if (rs1_value_ !== 32'd0) $fatal(1, "[FAIL] reset did not clear rs1");
	if (rs2_value_ !== 32'd0) $fatal(1, "[FAIL] reset did not clear rs2");

	

	$display("----------------[PASS] tb_Reg_File completed.----------------------");
	$finish;
end

endmodule
