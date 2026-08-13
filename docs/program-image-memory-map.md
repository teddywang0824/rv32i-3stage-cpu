# 程式映像與記憶體配置

[文件導覽](README.md) · [專案首頁](../README.md) · [Core 規格契約](rv32i-core-spec.md)

本專案有兩種刻意分開的 simulation memory flow。早期 smoke/directed 測試使用分離式 IMEM/DMEM；ACT4 與 compiled C 使用較大的統一記憶體。兩者都只是 simulation wrapper，不是 `CPU_Core` 的 architectural state，也不是實體 SRAM 規格。

## 如何選擇

| 使用情境 | Memory model | Linker script | Image converter | 執行入口 |
| --- | --- | --- | --- | --- |
| 短 Assembly smoke/directed program | split `Program_ROM` + `Data_Memory` | `programs/link.ld` | `bin_to_word_hex.py` | `run_tests.sh image` / `directed` |
| ACT4 self-checking ELF | unified `Arch_Test_Memory` | `verification/arch-test/link.ld` | `elf_to_sparse_hex.py` | `run_tests.sh arch` |
| Freestanding compiled C | unified `Arch_Test_Memory` | `verification/arch-test/link.ld` | `elf_to_sparse_hex.py` | `run_tests.sh compiled` |

## Split-memory image flow

### ELF packaging map

| 區域 | ELF address | CPU runtime address | 預設容量 |
| --- | --- | --- | ---: |
| Instruction | `0x0000_0000`–`0x0000_00ff` | 相同 | 256 bytes / 64 words |
| Data | `0x1000_0000`–`0x1000_0fff` | `0x0000_0000`–`0x0000_0fff` | 4096 bytes / 1024 words |

Reset vector 與 ELF entry `_start` 都是 `0x0000_0000`。ELF 將 `.data` 放在高位址只是為了避免和 `.text` 重疊；目前 CPU runtime 並沒有位於 `0x1000_0000` 的 Data Memory。

Data image 的換算方式是：

```text
dmem_byte_offset = elf_address - 0x1000_0000
dmem_word_index  = dmem_byte_offset / 4
cpu_data_address = dmem_byte_offset
```

例如 ELF data `0x1000_0008` 會放入 DMEM HEX word 2，程式以 runtime address `0x0000_0008` 存取。Assembly 不可直接拿 ELF data symbol 的高位地址當 runtime pointer。

### Word HEX 格式

- 一行一個 32-bit little-endian CPU word，不加 `0x`。
- 第 `N` 行對應 memory byte offset `N * 4`。
- 未覆蓋的 IMEM word 預填 `00000013`（NOP）。
- 未覆蓋的 DMEM word 預填 `00000000`。
- 詳細範例見 [tests/images/README.md](../tests/images/README.md)。

### RTL 索引規則

`Program_ROM` 與 `Data_Memory` 已容量參數化，並以完整 word address `address[31:2]` 索引。預設 instance 分別配置 64 與 1024 words；測試映像必須落在配置容量內。超出範圍是 simulation-model 使用錯誤，不會產生 architectural access-fault trap，也不會再利用高位截斷形成 alias。

### 建立與驗證

```bash
bash run_tests.sh image
```

流程會測試 binary-to-word-HEX 工具、編譯 `programs/image_smoke.S`、檢查 ELF/sections/symbols/objdump/HEX，再由 `tb_CPU_Image` 核對 ordered retire、Store 結果與 EBREAK trap。生成物位於 `build/programs/image_smoke/`。

## Unified-memory regression flow

ACT4 與 compiled C 使用 `0x0000_0000`–`0x01ff_ffff` 的 32 MiB 邏輯 RAM：

- entry：`0x0000_0000`；
- `.data` / `.bss` / stack / code 都位於同一地址空間；
- pass/fail `tohost`：`0x01ff_fff0`；
- `tools/elf_to_sparse_hex.py` 讀取 ELF `PT_LOAD` segments，包含零填充區，輸出帶 `@word_address` 的稀疏 `$readmemh`；
- `Arch_Test_Memory` 同時服務 instruction fetch 與 data access。

執行入口：

```bash
bash run_tests.sh arch
bash run_tests.sh compiled
```

ACT4 的 UDB、Sail、linker 與 runner 細節見 [ACT4 驗證指南](../verification/arch-test/README.md)。

## 共同限制

- ELF 必須是 32-bit little-endian RISC-V。
- Instruction address 必須 4-byte aligned。
- 映像或 load segment 不得超出所選 memory model。
- v1.0 沒有 access-fault exception、MMU、PMP、cache 或實體 SRAM macro。
- 改變 memory base、容量或 latency 時，必須同步修改 linker、converter、testbench 與 [Core 規格契約](rv32i-core-spec.md)。

---

[上一篇：Core 規格契約](rv32i-core-spec.md) · [文件導覽](README.md) · [下一篇：ACT4 驗證指南](../verification/arch-test/README.md)
