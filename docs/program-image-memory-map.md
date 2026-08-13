# Program image memory map

本文件定義 Step 32 程式映像流程使用的固定位址契約。它區分三種容易混淆的位址：ELF virtual address、CPU runtime address，以及 `$readmemh` word index。

## 固定配置

| 區域 | ELF address range | ELF base | CPU runtime range | 容量 | HEX words |
|---|---|---:|---|---:|---:|
| Instruction memory | `0x0000_0000`–`0x0000_00FF` | `0x0000_0000` | `0x0000_0000`–`0x0000_00FF` | 256 bytes | 64 |
| Data memory | `0x1000_0000`–`0x1000_0FFF` | `0x1000_0000` | `0x0000_0000`–`0x0000_0FFF` | 4096 bytes | 1024 |

- Reset vector 固定為 `0x0000_0000`，因此 ELF entry point `_start` 必須位於此處。
- Instruction 必須 4-byte aligned。
- IMEM HEX 未提供的 words 由 `Program_ROM` 預填為 `0x0000_0013`（NOP）。
- DMEM HEX 未提供的 words 由 `Data_Memory` 預填為 `0x0000_0000`。
- 兩種 HEX 都採一行一個 32-bit word；第 `N` 行對應該 memory 的 byte offset `N * 4`。

## ELF 到 HEX 的位址換算

Instruction section 不需 rebase：

```text
imem_byte_offset = elf_address - 0x0000_0000
imem_word_index  = imem_byte_offset / 4
```

Data section 必須 rebase：

```text
dmem_byte_offset = elf_address - 0x1000_0000
dmem_word_index  = dmem_byte_offset / 4
cpu_data_address = dmem_byte_offset
```

例如 ELF 位址 `0x1000_0008` 的 32-bit data 會放入 DMEM HEX 第 2 個 word，CPU 以 runtime address `0x0000_0008` 存取。

ELF 使用不同 base 的目的只是讓 `.text` 與 `.data` 在單一 ELF address space 中不重疊。這不表示目前 CPU 有位於 `0x1000_0000` 的硬體 Data Memory。

## Runtime symbol 規則

目前程式不得直接把 ELF `.data` symbol 的高位址當成 CPU runtime address。Assembly 若要存取一個 ELF data symbol，必須使用其 DMEM offset：

```text
runtime_address = elf_symbol_address - 0x1000_0000
```

後續 linker script／build tool 應提供明確的 offset symbol 或 relocation 流程，避免程式依賴 `Data_Memory` 目前只使用 `address[11:2]` 所造成的高位 alias。高位 alias 不是 architectural contract。

## 轉換工具必須拒絕的映像

- entry point 不是 `0x0000_0000`。
- executable bytes 落在 IMEM range 之外。
- data bytes 落在 DMEM ELF range 之外。
- IMEM 超過 256 bytes，或 DMEM 超過 4096 bytes。
- instruction address 非 4-byte aligned。
- 非 32-bit little-endian RISC-V ELF。
- section 或 load segment 在 rebase 後重疊，或產生負 offset。

尾端不足一個 32-bit word 的 data 可由轉換工具補零；instruction image 不得包含半條指令。

## 與 RTL 的對應

- `Program_ROM`：64 × 32-bit，以 `fetch_addr[7:2]` 索引。
- `Data_Memory`：1024 × 32-bit，以 `address[11:2]` 索引。
- `CPU_Core` 不包含上述 array；此 memory map 屬於 `CPU_Sim_Top` 與 host-side program-image flow。

若未來加入 bus decoder、access-fault、實體 SRAM 或不同 memory base，本文件、linker script、轉換工具與映像測試必須同步更新。

## 建立與驗證

在 WSL 的專案根目錄執行：

```bash
./run_tests.sh image
```

此單一入口會依序執行：

1. `bin_to_word_hex.py` 的 little-endian、padding、空檔案、容量與錯誤輸入測試。
2. 以 `-march=rv32i -mabi=ilp32` 編譯並依 `programs/link.ld` 連結 `programs/image_smoke.S`。
3. 產生 ELF、map、objdump、section/symbol report、IMEM HEX 與 DMEM HEX。
4. 比對 entry point、`_start`、section 位址、objdump instruction、HEX words 與 golden data。
5. 讓 `tb_CPU_Image` 直接載入當次生成的 HEX，核對 ordered retire、signature `12`、Store 結果與 EBREAK trap。

Generated artifacts 位於：

```text
build/programs/image_smoke/
```
