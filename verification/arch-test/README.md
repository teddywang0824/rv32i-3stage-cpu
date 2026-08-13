# ACT4 architectural test 指南

[文件導覽](../../docs/README.md) · [專案首頁](../../README.md) · [程式映像與記憶體配置](../../docs/program-image-memory-map.md)

本目錄保存 CPU Build 接入 RISC-V Architectural Certification Tests（ACT4）所需的 UDB、Sail、linker、DUT macros 與 RTL runner。ACT4 先以 Sail 產生 expected result，再建立 self-checking ELF；本專案把 ELF 轉成稀疏 unified-memory HEX，最後在真正的 CPU RTL 上執行。

目前適用的 39 項 RV32I I-extension tests 全部通過。

## 測試資料流

```text
UDB DUT capability + Sail config
                ↓
ACT4 assembly + Sail expected signature
                ↓
self-checking ELF
                ↓ elf_to_sparse_hex.py
sparse 32 MiB unified-memory image
                ↓ tb_ACT4.sv
CPU RTL writes pass/fail to 0x01ff_fff0
```

ACT4 補強手寫 directed tests，但不取代 unit、pipeline、trap 與 retire regression。

## DUT 設定

| 項目 | 設定 |
| --- | --- |
| XLEN / ISA | RV32I 2.1，ILP32 |
| Endianness | Little-endian |
| Instruction alignment | IALIGN=32，不支援 compressed instruction |
| Entry | `0x0000_0000` |
| 邏輯 RAM | `0x0000_0000`–`0x01ff_ffff`，32 MiB |
| Pass/fail `tohost` | `0x01ff_fff0`；`1` pass、`3` fail |
| Privileged tests | 關閉 |

DUT 支援 RV32I、FENCE、ECALL、EBREAK，以及 illegal instruction 和 instruction/load/store address-misaligned precise trap。不支援 RVC、RV32M、CSR、privileged mode、interrupt、cache、MMU 或 PMP。

UDB 的 `Sm 1.12.0` 只是 ACT4 生成 unprivileged test headers 所需的 machine execution environment，不代表 RTL 實作 privileged architecture：`include_priv_tests=false`、`MISA_CSR_IMPLEMENTED=false`，且 `RVMODEL_BOOT_TO_MMODE` 不執行 CSR 初始化。

## 本目錄檔案

| 檔案 | 用途 |
| --- | --- |
| `test_config.yaml` | ACT4 工具路徑與 DUT 設定入口 |
| `cpu-build-rv32i.yaml` | UDB 格式的 DUT capability |
| `sail.json` | 與 DUT trap/misaligned policy 對齊的 Sail config |
| `rvmodel_macros.h` | boot/platform hooks 與 pass/fail protocol |
| `link.ld` | 32 MiB unified logical memory 配置 |
| `run_arch_tests.sh` | ELF 轉換、testbench 編譯與逐項 RTL simulation |
| `tool-versions.txt` | 已驗證工具版本與路徑 |
| `regression-results.txt` | 最近一次摘要 |

共用 adapter 位於 `rtl/Arch_Test_Memory.sv`、`tools/elf_to_sparse_hex.py` 與 `tb/tb_ACT4.sv`。`rvtest_config.h`、`rvtest_config.svh` 由 ACT4 在 work directory 生成，不應在此放置手寫副本。

## 產生 self-checking ELF

完整安裝步驟見 [根目錄 README 的復刻章節](../../README.md#從新環境復刻驗證)。工具完成後，在 WSL 執行：

```bash
cd /mnt/d/CodeProject/cpu_build/external/riscv-arch-test
CONFIG_FILES=/mnt/d/CodeProject/cpu_build/verification/arch-test/test_config.yaml \
WORKDIR=/mnt/d/CodeProject/cpu_build/build/arch-test/act4 \
EXTENSIONS=I \
make --jobs "$(nproc)"
```

這一步同時生成 tests、以 Sail 計算 expected results，並輸出 39 個 self-checking ELF 到：

```text
build/arch-test/act4/cpu-build-rv32i/elfs/rv32i/I/
```

`make tests` 只生成 test suites/covergroups，不會完成 Sail reference 與最終 ELF，因此不能取代上面的 `make`。

## 執行 RTL regression

全部測試：

```bash
cd /mnt/d/CodeProject/cpu_build
bash run_tests.sh arch
```

只重跑一個 ELF：

```bash
bash verification/arch-test/run_arch_tests.sh I-add-00.elf
```

runner 會監看 `tohost` Store、unexpected trap 與 cycle timeout。每項 log 和轉換後映像分別保存在：

```text
build/arch-test/rtl/logs/
build/arch-test/rtl/images/
```

## 已驗證結果

- ACT4 config/tool version checks：PASS。
- UDB：`Config cpu-build-rv32i is valid`。
- Sail `--validate-config`：PASS。
- ELF：ELF32 little-endian，entry `0x0000_0000`，`tohost=0x01ff_fff0`。
- Unsupported instruction audit：沒有 compressed、CSR、`mret` 或 `wfi`。
- CPU RTL：`passed=39 failed=0 total=39`。

最終 release 證據見 [RTL 品質稽核](../rtl-quality-audit.md)與 [v1.0 manifest](../../release/rv32i-core-v1.0.manifest.md)。

---

[上一篇：程式映像與記憶體配置](../../docs/program-image-memory-map.md) · [文件導覽](../../docs/README.md) · [下一篇：RTL 品質稽核](../rtl-quality-audit.md)
