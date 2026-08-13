# CPU Build 的 ACT4 架構測試設定

本目錄保存 CPU Build 接入 RISC-V Architectural Certification Tests（ACT4）所需的 DUT、UDB、Sail、ELF adapter 與 RTL regression 設定。Step 34 已完成：目前 ACT4 產生的 39 項 RV32I I-extension self-checking tests 全部在 CPU RTL 上通過。

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
- `run_arch_tests.sh`：將 ACT4 ELF 轉成稀疏 memory image，編譯共用 testbench 並批次執行。

RTL adapter 由 `rtl/Arch_Test_Memory.sv`、`tools/elf_to_sparse_hex.py` 與 `tb/tb_ACT4.sv` 組成。一般測試仍使用原本的分離式 IMEM/DMEM；architectural tests 才會啟用 32 MiB 統一邏輯記憶體。

`rvtest_config.h` 與 `rvtest_config.svh` 不應放在本目錄；ACT4 會依 UDB 設定在 work directory 自動產生，手寫副本可能遮蔽生成結果。

## 已完成的驗證

- ACT4 能載入 `test_config.yaml`，且 compiler、objdump、Sail 路徑及版本檢查通過。
- UDB 驗證回報 `Config cpu-build-rv32i is valid`。
- Sail `--validate-config` 驗證通過。
- 以官方 `I-nop-00.S` 跑完整 ACT4 build/reference/signature/self-checking pipeline，結果為 `7 succeeded`。
- 產生的 ELF 為 ELF32 little-endian，入口為 `0x00000000`，`tohost` 位於 `0x01fffff0`；pass/fail Store 分別寫入 `1`/`3`。
- 完整 ELF 反組譯未發現 compressed、CSR、`mret` 或 `wfi` 指令。
- 39 項 RV32I ACT4 ELF 全部通過 RTL simulation，結果為 `passed=39 failed=0 total=39`。
- `run_tests.sh all`（既有 unit/integration/directed tests 加 ACT4 regression）完整通過。

每個 architectural test 的轉換映像與 log 分別保存在 `build/arch-test/rtl/images/` 與 `build/arch-test/rtl/logs/`。

## 產生官方 I-extension tests

在 WSL 的 `external/riscv-arch-test` 執行：

```bash
make tests \
  CONFIG_FILES=/mnt/d/CodeProject/cpu_build/verification/arch-test/test_config.yaml \
  WORKDIR=/mnt/d/CodeProject/cpu_build/build/arch-test/act4 \
  EXTENSIONS=I
```

## 執行 RTL architectural regression

執行全部 39 項測試：

```bash
./run_tests.sh arch
```

只重跑單一 ELF：

```bash
bash verification/arch-test/run_arch_tests.sh I-add-00.elf
```

runner 會監看 `0x01fffff0` 的 pass/fail Store、unexpected trap 與 cycle timeout；失敗 log 不會被後續測試覆蓋。
