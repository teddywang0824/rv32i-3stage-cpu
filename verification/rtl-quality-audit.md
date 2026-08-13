# RV32I Core v1.0 RTL 品質稽核

[文件導覽](../docs/README.md) · [Core 規格契約](../docs/rv32i-core-spec.md) · [v1.0 release manifest](../release/rv32i-core-v1.0.manifest.md)

稽核日期：2026-08-13

本文件回答「v1.0 封版前實際檢查了哪些 RTL 風險」。功能與 ISA 定義以 [Core 規格契約](../docs/rv32i-core-spec.md) 為準；測試環境復刻方式以 [根目錄 README](../README.md#從新環境復刻驗證) 為準。

## 靜態 lint

- Top：`CPU_Core`。
- 工具：Verilator 4.038。
- 命令：`bash tools/run_rtl_lint.sh` 或 `bash run_tests.sh lint`。
- 範圍：只包含 manifest 鎖定的 synthesizable hierarchy；排除 simulation wrapper/memory/testbench。
- 結果：零 diagnostics。

Load/Store alignment 單元只使用 effective address `[1:0]`。完整 32-bit address port 是刻意保留的介面，因此 unused upper bits 使用局部 Verilator waiver；沒有關閉 WIDTH、LATCH、MULTIDRIVEN 等整類檢查。

## Reset、valid 與 side-effect audit

| 稽核項目 | 結果 | RTL／測試證據 |
| --- | --- | --- |
| Reset 清除 architectural、pipeline、trap state | PASS | `PC`、`IDEX`、`EXWB`、`Reg_File`、`Trap_Unit` reset branches 與 unit tests |
| Reset 期間禁止外部 request 與 retire side effect | PASS | `CPU_Core` 以 `!rst` gate IMEM/DMEM request、retire-valid/write flags |
| Invalid/illegal instruction 無副作用 | PASS | safe decode defaults、`tb_Control_Unit`、`tb_CPU_Illegal` |
| x0 永遠為 0 | PASS | write suppression/read mux、`tb_Reg_File`、load-to-x0 case |
| Load-use stall 保持 PC/response 並插入一個 bubble | PASS | `Hazard_Unit`、`bubble_IDEX`、`tb_CPU_Load_Hazard` |
| Redirect kill wrong path | PASS | redirect/kill/bubble arbitration、Branch/JAL/JALR/Store integration tests |
| Trap 抑制 faulting 與 younger side effect | PASS | `effective_ex_*` gating、`tb_CPU_Trap`、`tb_CPU_Alignment` |
| Trap metadata 保持到 ack，之後依 redirect 恢復 | PASS | `Trap_Unit` pending register、`tb_Trap_Unit`、CPU trap integration |
| Store 在固定延遲 contract 下只 commit/retire 一次 | PASS | EX/WB store payload、ordered retire/directed traces |
| Load response 對應正確 instruction | PASS | single-outstanding contract、Load 與 load-hazard tests |
| FENCE 無 architectural side effect 且正常退休 | PASS | FENCE unit/integration/directed tests |
| 完整 regression | PASS | unit/integration、directed 40/40、ACT4 39/39、compiled C deterministic run |

## 已凍結限制

- Reset 是同步 active-high；`rst=1` 時輸出 request/retire side effect 被明確壓低，內部 state 在 rising edge 更新。
- IMEM/DMEM 沒有 ready、backpressure 或 transaction ID；v1.0 只支援一筆 in-order、固定下一週期 response。
- Simulation memory 超出配置容量時不產生 access-fault trap；映像必須由 host tool 保證範圍正確。
- 不支援 CSR、privileged mode、interrupt、RV32M、RVC、cache、MMU、PMP、variable-latency memory 或實體 SRAM macro。

這些是已記錄的 release contract，不是未追蹤的 lint waiver。封存 source list、hash 與工具版本見 [v1.0 release manifest](../release/rv32i-core-v1.0.manifest.md)。

---

[上一篇：ACT4 驗證指南](arch-test/README.md) · [文件導覽](../docs/README.md) · [下一篇：v1.0 release manifest](../release/rv32i-core-v1.0.manifest.md)
