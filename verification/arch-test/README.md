# CPU Build 的 ACT4 架構測試設定

本目錄保存 CPU Build 接入 RISC-V Architectural Certification Tests（ACT）所需的 DUT 設定。這些設定描述目前 RTL 真正具備的能力，不把尚未實作的 privileged architecture、CSR 或 interrupt 宣告為已支援。

目前只完成 Step 34.1 與 34.2：DUT 能力定義及 ACT4 設定骨架。記憶體擴充、ELF/HEX 轉換、通用 testbench 與批次執行器會在後續子步驟完成，因此本目錄現在還不能直接跑完整 ACT regression。

## DUT 能力

| 項目 | 目前設定 |
| --- | --- |
| XLEN | 32 |
| Base ISA | RV32I 2.1 |
| ABI | ILP32 |
| 位元組序 | Little-endian |
| Instruction alignment | IALIGN=32（指令位址須為 4-byte 對齊） |
| Reset vector | `0x00000000` |
| Instruction memory | `0x00000000` 起，目前 256 bytes |
| Data memory | `0x10000000` 起，目前 4096 bytes |
| ACT pass/fail status | `0x10000ff0`；`1` 表示通過，`3` 表示失敗 |

## 支援的指令與行為

- RV32I base integer instructions。
- `FENCE`：在目前沒有 cache、write buffer 與 outstanding memory transaction 的設計中視為可退休且無副作用的指令。
- `ECALL` 與 `EBREAK`：辨識完整合法編碼，並由 Core 的外部 precise-trap 介面回報。
- Illegal instruction、instruction-address-misaligned、load-address-misaligned 與 store-address-misaligned precise trap。
- Misaligned halfword/word Load/Store 產生 trap，不由硬體拆成多次對齊存取，也不送出 Data Memory request。

## 不支援的功能

- RVC／compressed instructions。
- RV32M 與其他非 RV32I extensions。
- Zicsr 與任何 CSR instruction。
- Machine/Supervisor/User privileged execution environment。
- Core 內部 trap handler、`mtvec`、`mepc`、`mcause`、`mtval` 等 privileged CSR。
- Interrupt、cache、MMU、PMP 與虛擬記憶體。

`ECALL`、`EBREAK` 及其他同步例外只會透過外部 trap handshake 回報；這不代表 DUT 具備 RISC-V machine-mode trap handling。ACT4 設定因此關閉 privileged tests。

## 本目錄檔案

- `test_config.yaml`：ACT4 的工具與 DUT 路徑設定。
- `cpu-build-rv32i.yaml`：UDB 格式的 RV32I 能力宣告。
- `rvmodel_macros.h`：DUT 專用 pass/fail protocol；以 Store 寫入 status address。
- `link.ld`：ACT 專用 section 與目前的 split IMEM/DMEM memory map。
- `rvtest_config.h`、`rvtest_config.svh`：ACT4 目前仍要求手動提供的能力標記。

## 與一般程式映像 linker script 的差異

`programs/link.ld` 供專案自己的 `_start` 程式使用；本目錄的 `link.ld` 則遵循 ACT4 要求，入口是 `rvtest_entry_point`，並保留 `.text.init`、`.text.rvtest`、`.data` 與 `.text.rvmodel`。兩者不能互換。

## 尚未完成

- 目前 Program ROM 只有 64 words，ACT 程式很可能無法容納；Step 34.3 會將 IMEM/DMEM 容量參數化。
- 尚未完成 ACT ELF 到分離式 IMEM/DMEM HEX 的轉換。
- 尚未建立監看 pass/fail Store、timeout、unexpected trap 與 retire trace 的通用 testbench。
- 尚未安裝或鎖定 ACT4、Sail、GCC/Binutils 與 Icarus Verilog 版本。
- `cpu-build-rv32i.yaml` 是目前無 privileged extension 的最小 UDB 描述；實際執行 ACT4 時仍須用所鎖定版本的 schema 驗證。

## 預計使用方式

完成後，應從 `riscv-arch-test` repository 執行：

```bash
CONFIG_FILES=/absolute/path/to/cpu_build/verification/arch-test/test_config.yaml \
WORKDIR=/absolute/path/to/cpu_build/build/arch-test/act4 \
EXTENSIONS=I \
make --jobs
```

產生的 self-checking ELF 還必須經過本專案後續建立的 adapter 才能在 `CPU_Sim_Top` 上執行。
