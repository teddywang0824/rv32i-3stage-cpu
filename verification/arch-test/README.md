# CPU Build 的 ACT4 架構測試設定

本目錄保存 CPU Build 接入 RISC-V Architectural Certification Tests（ACT4）所需的 DUT、UDB、Sail 與連結設定。目前「設定與最小 ELF 產生」已驗證通過；RTL 記憶體 adapter、通用 testbench 與完整 RV32I regression 仍屬 Step 34 後續子步驟。

## DUT 能力與測試範圍

| 項目 | 設定 |
| --- | --- |
| XLEN / Base ISA | RV32I 2.1，ILP32 |
| 位元組序 | Little-endian |
| Instruction alignment | IALIGN=32，不支援 compressed instruction |
| Reset / test entry | `0x00000000` |
| ACT 邏輯 RAM | `0x00000000`–`0x01ffffff`，32 MiB |
| Pass/fail status | `0x01fffff0`；`1` 表示通過，`3` 表示失敗 |
| Privileged tests | 關閉 |

DUT 支援 RV32I、`FENCE`、`ECALL`、`EBREAK`，以及 illegal instruction、instruction/load/store address misaligned precise trap。不支援 RVC、RV32M、CSR、privileged mode、interrupt、cache、MMU 或 PMP。

UDB 設定中的 `Sm 1.12.0` 只是 ACT4 產生 unprivileged 測試標頭所需的 machine execution environment。它不代表 RTL 已實作 privileged architecture：`include_priv_tests` 為 `false`、`MISA_CSR_IMPLEMENTED` 為 `false`，且 `RVMODEL_BOOT_TO_MMODE` 不執行 CSR 初始化。

## 檔案用途

- `test_config.yaml`：ACT4 工具路徑與 DUT 設定入口。
- `cpu-build-rv32i.yaml`：可由 UDB 驗證的 RV32I 能力宣告。
- `sail.json`：與 DUT trap/misaligned 行為相符的 Sail reference-model 設定。
- `rvmodel_macros.h`：boot、平台 hook，以及以 Store 回報 pass/fail 的 protocol。
- `link.ld`：ACT self-checking ELF 使用的 32 MiB 統一邏輯記憶體配置。
- `tool-versions.txt`：已驗證工具與來源版本。

`rvtest_config.h` 與 `rvtest_config.svh` 不應放在本目錄；ACT4 會依 UDB 設定在 work directory 自動產生，手寫副本可能遮蔽生成結果。

## 已完成的驗證

- ACT4 能載入 `test_config.yaml`，且 compiler、objdump、Sail 路徑及版本檢查通過。
- UDB 驗證回報 `Config cpu-build-rv32i is valid`。
- Sail `--validate-config` 驗證通過。
- 以官方 `I-nop-00.S` 跑完整 ACT4 build/reference/signature/self-checking pipeline，結果為 `7 succeeded`。
- 產生的 ELF 為 ELF32 little-endian，入口為 `0x00000000`，`tohost` 位於 `0x01fffff0`；pass/fail Store 分別寫入 `1`/`3`。
- 完整 ELF 反組譯未發現 compressed、CSR、`mret` 或 `wfi` 指令。

最小驗證產物位於 `build/arch-test/minimal/cpu-build-rv32i/elfs/rv32i/I/I-nop-00.elf`。

## 產生官方 I-extension tests

在 WSL 的 `external/riscv-arch-test` 執行：

```bash
make tests \
  CONFIG_FILES=/mnt/d/CodeProject/cpu_build/verification/arch-test/test_config.yaml \
  WORKDIR=/mnt/d/CodeProject/cpu_build/build/arch-test/act4 \
  EXTENSIONS=I
```

## Step 34 尚待完成

目前 RTL 仍使用容量有限且分離的 IMEM/DMEM，而 ACT ELF 採 32 MiB 統一邏輯位址。因此還需要：

1. 將 simulation memory 容量參數化並提供統一的邏輯位址視圖。
2. 建立 ELF/section 到 RTL memory image 的轉換與載入 adapter。
3. 建立監看 pass/fail Store、timeout、unexpected trap 與 retire 狀態的通用 testbench/runner。
4. 執行完整 RV32I ACT regression，全部通過後才可完成 Step 34 驗收並更新 `index.html`。
