# RV32I Core v1.0 Release Manifest

[文件導覽](../docs/README.md) · [Core 規格契約](../docs/rv32i-core-spec.md) · [RTL 品質稽核](../verification/rtl-quality-audit.md)

| 欄位 | 值 |
| --- | --- |
| Release 日期 | 2026-08-13 |
| Git tag | `rv32i-core-v1.0`（annotated tag） |
| Release commit 查詢 | `git rev-parse rv32i-core-v1.0^{commit}` |
| Pre-release baseline | `8e0e6e3cd7af399566159b3c5e613652eea643f4` |
| Synthesis top | `CPU_Core` |
| Architectural contract | [docs/rv32i-core-spec.md](../docs/rv32i-core-spec.md) |

## Release 範圍

- 四級、single-issue、in-order RV32I core。
- 支援 40 條 RV32I base instructions，包含 FENCE、ECALL、EBREAK。
- Precise synchronous trap handshake。
- In-order retire trace，包含 register write 與 committed Store metadata。

## 凍結的 synthesis source

```text
rtl/defines.sv
rtl/CPU_Core.sv
rtl/Controller.sv
rtl/PC.sv
rtl/Inst_Decoder.sv
rtl/Reg_File.sv
rtl/Control_Unit.sv
rtl/IDEX.sv
rtl/EXWB.sv
rtl/ALU.sv
rtl/Forwarding_Unit.sv
rtl/Hazard_Unit.sv
rtl/Branch_Unit.sv
rtl/Store_Unit.sv
rtl/Load_Unit.sv
rtl/Trap_Detect.sv
rtl/Trap_Unit.sv
```

各檔 SHA-256 記錄於 [rv32i-core-v1.0.rtl.sha256](rv32i-core-v1.0.rtl.sha256)。

不納入 synthesis hierarchy：

- `CPU_Sim_Top`、`CPU_Top`、`Program_ROM`、`Data_Memory`、`Arch_Test_Memory`：simulation/compatibility wrapper。
- `IFID.sv`：可綜合的教學/備選模組，但 v1.0 `CPU_Core` 未實例化。

## 凍結的介面契約

- `rst`：同步 active-high；asserted 期間禁止 request 與 retire side effect。
- IMEM：request/address；固定下一週期回傳 valid/PC/instruction；沒有 ready/backpressure。
- DMEM：request/write/byte-enable/address/data；Load 固定下一週期 response，Store 在 request edge commit。
- Memory 每側至多一筆 in-order transaction；沒有 transaction ID 或 variable latency。
- Trap：`trap_valid` 期間 metadata 穩定；rising edge 的 `trap_ack` 接收事件並採樣 `trap_redirect_pc`。
- Retire：每條合法、未 fault 的 instruction 產生一次 in-order observation，並回報實際 rd/Store side effect。

完整訊號與例外語意見 [Core 規格契約](../docs/rv32i-core-spec.md)。

## 品質與 regression 證據

| 檢查 | 命令／工具 | 結果 |
| --- | --- | --- |
| Synthesizable hierarchy lint | Verilator 4.038；`bash tools/run_rtl_lint.sh` | 零 diagnostics |
| 完整 regression | `bash run_tests.sh all` | PASS |
| Directed ISA matrix | `bash run_tests.sh directed` | 40/40 |
| ACT4 architectural tests | `bash run_tests.sh arch` | 39 passed、0 failed |
| Freestanding C workload | `bash run_tests.sh compiled` | 連續兩次相同：1304 cycles / 902 retired |

Final regression log：`build/rv32i-v1.0-regression.log`

該 log 的 SHA-256：

```text
00d1a109c8db50425aa91ad907705003d8c10929bca2b84e2ef33054568b1d68
```

`build/` 不納入 Git。只有在使用鎖定工具版本時，重建 log 才應得到相同 hash。復刻流程見 [根目錄 README](../README.md#從新環境復刻驗證)，詳細 audit 見 [RTL 品質稽核](../verification/rtl-quality-audit.md)。

## 已驗證工具版本

- Icarus Verilog 11.0
- Verilator 4.038
- Python 3.10.12
- ACT4/riscv-arch-test commit `b664a56b7b24a0ba7512f8df064f9e799e33c892`
- ACT4 compiler GCC 15.2.0 / Binutils 2.45
- Sail RISC-V 0.13.1
- mise 2026.8.5

完整工具路徑見 [verification/arch-test/tool-versions.txt](../verification/arch-test/tool-versions.txt)。

## 已知限制

- 無 CSR、privileged mode、interrupt、RV32M、RVC、atomic 或 floating-point extension。
- 無 cache、MMU、PMP、bus protocol、wait-state/backpressure 或 multiple outstanding transaction。
- 無實體 SRAM macro；repository 內 memory 都是 simulation model。
- Misaligned instruction/Load/Store 產生 trap，不以硬體拆分跨 word access。
- Simulation image 超出配置容量時不產生 access-fault exception。

---

[上一篇：RTL 品質稽核](../verification/rtl-quality-audit.md) · [文件導覽](../docs/README.md) · [回到專案首頁](../README.md)
