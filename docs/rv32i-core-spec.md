# RV32I Core v1.0 規格契約

本文件是此專案的 architectural contract。它描述 v1.0 封版時必須成立的行為，並將目前已實作功能與後續待完成項目分開。若 RTL、testbench 與本文件衝突，在 v1.0 封版前必須明確修正其中一方，不得留下未記錄的 CPU 行為。

## 1. 範圍與固定選擇

| 項目 | v1.0 契約 |
|---|---|
| ISA | RV32I base，共 40 條：現有 37 條，加上 FENCE、ECALL、EBREAK |
| 執行模型 | 四級、single-issue、in-order；每條合法且未發生例外的指令最多退休一次 |
| XLEN | 32-bit；所有整數運算以 32-bit two's-complement wraparound |
| Register file | x0 永遠讀出 0，對 x0 的寫入不產生 architectural effect；x1～x31 為 32-bit |
| IALIGN | 32 bits；所有 instruction address 必須為 4-byte aligned |
| Reset vector | `0x0000_0000` |
| Byte order | little-endian |
| Instruction memory | 固定一週期同步 response；每次接受 request 後，下一個 clock edge 產生與 request PC 配對的 instruction/valid |
| Data memory | 固定一週期同步 transaction；Load request 的下一個 clock edge產生 word data/valid；Store 在接受 request 的 clock edge依 byte-enable commit |
| Trap | precise、同步 exception；`trap_valid/ack/redirect_pc` handshake；faulting instruction 不退休且無 register/memory/control-flow side effect，younger instructions 全部 kill，older instructions 可依序完成 |
| Retire | in-order commit observation；合法、未 trap 的指令（包含無狀態副作用的 Branch、FENCE）各產生一次 retire event |

`rtl/defines.sv` 中的 `RV32_*`、`Opcode_MISC_MEM`、`Opcode_SYSTEM`、固定 SYSTEM encoding 與 `TRAP_*` 是本契約的 RTL 常數來源。

## 2. 明確排除的功能

v1.0 不支援 Zicsr、任何 privileged mode/CSR state、interrupt、RV32M、compressed instruction、atomic、floating point、cache、MMU、memory protection、bus protocol、wait-state/backpressure、outstanding transaction、實體 SRAM macro 或跨 word 的 misaligned data access。

ECALL 使用專案定義的 environment-call cause `11`，但不表示 v1.0 實作 machine mode 或 `mepc`/`mcause` 等 CSR。Trap 只透過 Core 的外部 `trap_valid/ack/redirect_pc` contract 回報與重新取指。

## 3. Reset、pipeline 與控制優先權

- `rst` 為同步 active-high reset。reset 期間 PC 回到 `0x0000_0000`、pipeline valid 清除、register architectural state 清為 0，且不得產生 memory write、retire 或 trap event。
- 現有 `Controller` 在 reset 後以 S0/S1 兩個初始化狀態保持 PC reset 並 flush pipeline，S2 才進入正常 fetch。
- 正常執行時，PC 預設加 4。taken Branch/JAL/JALR 以 EX stage 計算的 target redirect，並 kill stale instruction response 與 younger instruction。
- v1.0 最終仲裁順序固定為：`reset > trap > valid control-flow redirect > load-use stall > sequential advance`。同一條 faulting control-flow instruction 同時符合 redirect 與 alignment trap 時只接受 trap，不接受原 redirect。
- Load-use dependency 精確 stall 一個 cycle：保持 PC 與完整 instruction response，對 ID/EX 插入 bubble。EX/WB forwarding 不得把 Load address 當成 Load result。

## 4. Memory transaction contract

### 4.1 Instruction side

邏輯 transaction 由 request enable/address 與 response valid/PC/instruction 組成。接受 request 後，response 三個欄位必須成組對齊；stall 時保持完整 response；reset 或 kill 只使 response invalid，且 kill 優先於同週期新 fetch。v1.0 只允許 4-byte aligned fetch address。

目前 simulation model `Program_ROM` 容量可參數化、預設為 64 × 32-bit，使用完整 word address `address[31:2]` 索引。程式必須位於已配置容量內；超出範圍不產生 architectural access-fault，而屬於 simulation-model 使用錯誤。容量與階層式載入方式不是 `CPU_Core` 的 architectural state。

### 4.2 Data side

有效 request 必須同時攜帶 enable、read/write、32-bit address、write data、4-bit byte enable 與 access size。Load 在固定一週期 response 的 `valid` 週期取得資料；Store 只在有效、對齊且未被 kill/trap 的 request 上 commit。

目前 split simulation model 容量可參數化、預設為 1024 × 32-bit（4 KiB），使用完整 word address `address[31:2]` 索引。地址超出已配置容量沒有 architectural access-fault 保護，因此程式必須限制在該 window；v1.0 不宣告 access-fault exception。ACT4 與 compiled-program regression 則使用 32 MiB unified simulation memory。

程式映像工具使用獨立的 ELF packaging map：`.text` 位於 `0x0000_0000`–`0x0000_00FF`，`.data` 位於 `0x1000_0000`–`0x1000_0FFF`。轉換成 DMEM HEX 時必須從 data ELF address 減去 `0x1000_0000`；CPU runtime data address 仍為低 4 KiB offset。完整換算、容量檢查與 runtime symbol 限制見 [`program-image-memory-map.md`](program-image-memory-map.md)。ELF 的高位 data base 不是目前硬體的 DMEM base，也不得把現有模型忽略高位 address 的 alias 行為當成 architectural contract。

自然對齊規則：byte 可位於任一 offset；halfword 需要 `address[0]=0`；word 需要 `address[1:0]=00`。misaligned Load/Store 不得送達 Data Memory，也不得寫回 register，並分別回報 cause 4/6、`tval=fault address`。

## 5. Trap 與 retire 語意

| 情況 | cause | fault PC | tval | faulting instruction |
|---|---:|---|---|---|
| taken Branch/JAL/JALR target 非 4-byte aligned | 0 | 指令本身 PC | target（JALR 先清 bit 0） | 不退休、不可 redirect 到 misaligned target |
| 未知或保留 instruction encoding | 2 | 指令本身 PC | 原始 32-bit instruction | 不退休、無任何副作用 |
| EBREAK | 3 | 指令本身 PC | 0 | 不退休、無任何副作用 |
| misaligned Load | 4 | 指令本身 PC | effective address | 不發 request、不寫 rd、不退休 |
| misaligned Store | 6 | 指令本身 PC | effective address | 不發 request、不寫 memory、不退休 |
| ECALL | 11 | 指令本身 PC | 0 | 不退休、無任何副作用 |

Trap event 必須只送出一次，metadata 必須和 faulting instruction 成組保存。`trap_valid=1` 表示有一筆尚未接收的事件；未 `ack` 時 cause/PC/tval 保持穩定。外部在 rising edge 提供 `trap_ack=1` 時接收事件，同一個 edge 採樣 `trap_redirect_pc`；Core 隨後清除 pending event、kill stale response，並由 redirect PC 重新取指。pending 期間的新 trap request 不可覆寫既有 metadata；`ack` 與新 request 同週期時完成舊事件，新 request 不另行保存。

Retire event 的觀察點是 architectural commit：

- `retire_valid`：合法且沒有 trap/flush 的一條指令在本週期 commit。
- `retire_pc`、`retire_inst`：必須屬於同一條 retiring instruction。
- `retire_rd_write` 只在實際寫入非 x0 register 時為 1；`retire_rd_data` 是最終寫回值。
- `retire_mem_write` 只在 Store 實際修改 memory 時為 1，address/data/byte-enable 必須是已提交的值。
- Branch、未 taken Branch、寫 x0 的 ALU/jump 與 FENCE 仍可 `retire_valid=1`，但 side-effect flags 為 0。

## 6. 40 條指令契約與驗證矩陣

狀態：40 條 RV32I base instruction 均已由 directed regression 覆蓋。下表是人類可讀契約；逐條的正向、corner、pipeline/control、trap/illegal 與 evidence 路徑記錄於 `verification/rv32i-directed.csv`，並由 `tools/check_rv32i_matrix.py` 強制檢查。表中的 trap 條件除明列者外，皆包含「encoding 的保留欄位不合法時 cause=2」。所有 `rd` 寫入都遵守 x0 suppression。

| # | 指令／decode | operands 與結果 | architectural side effect | trap 條件 | 對應測試／狀態 |
|---:|---|---|---|---|---|
| 1 | ADDI `OP-IMM/000` | `rd=rs1+sext(imm12)` | rd write | 無額外條件 | `tb_CPU_Top`, `tb_Control_Unit`／已驗證 |
| 2 | SLTI `OP-IMM/010` | signed `rs1 < sext(imm12)` | rd=0/1 | 無額外條件 | `tb_CPU_Top`, `tb_ALU`／已驗證 |
| 3 | SLTIU `OP-IMM/011` | unsigned `rs1 < sext(imm12)` | rd=0/1 | 無額外條件 | `tb_CPU_Top`, `tb_ALU`／已驗證 |
| 4 | XORI `OP-IMM/100` | `rs1 XOR sext(imm12)` | rd write | 無額外條件 | `tb_CPU_Top`, `tb_ALU`／已驗證 |
| 5 | ORI `OP-IMM/110` | `rs1 OR sext(imm12)` | rd write | 無額外條件 | `tb_CPU_Top`, `tb_ALU`／已驗證 |
| 6 | ANDI `OP-IMM/111` | `rs1 AND sext(imm12)` | rd write | 無額外條件 | `tb_CPU_Top`, `tb_ALU`／已驗證 |
| 7 | SLLI `OP-IMM/001`, `funct7=0000000` | `rs1 << shamt[4:0]` | rd write | 其他 funct7 illegal | `tb_CPU_Top`, `tb_Control_Unit`／已驗證 |
| 8 | SRLI `OP-IMM/101`, `funct7=0000000` | logical `rs1 >> shamt[4:0]` | rd write | 其他 funct7 illegal | `tb_CPU_Top`, `tb_Control_Unit`／已驗證 |
| 9 | SRAI `OP-IMM/101`, `funct7=0100000` | arithmetic `rs1 >>> shamt[4:0]` | rd write | 其他 funct7 illegal | `tb_CPU_Top`, `tb_Control_Unit`／已驗證 |
| 10 | ADD `OP/000`, `funct7=0000000` | `rs1+rs2` | rd write | 其他 funct7 illegal | `tb_CPU_Top`, `tb_ALU`／已驗證 |
| 11 | SUB `OP/000`, `funct7=0100000` | `rs1-rs2` | rd write | 其他 funct7 illegal | `tb_CPU_Top`, `tb_ALU`／已驗證 |
| 12 | SLL `OP/001`, `funct7=0000000` | `rs1 << rs2[4:0]` | rd write | 其他 funct7 illegal | `tb_CPU_Top`, `tb_ALU`／已驗證 |
| 13 | SLT `OP/010`, `funct7=0000000` | signed `rs1 < rs2` | rd=0/1 | 其他 funct7 illegal | `tb_CPU_Top`, `tb_ALU`／已驗證 |
| 14 | SLTU `OP/011`, `funct7=0000000` | unsigned `rs1 < rs2` | rd=0/1 | 其他 funct7 illegal | `tb_CPU_Top`, `tb_ALU`／已驗證 |
| 15 | XOR `OP/100`, `funct7=0000000` | `rs1 XOR rs2` | rd write | 其他 funct7 illegal | `tb_CPU_Top`, `tb_ALU`／已驗證 |
| 16 | SRL `OP/101`, `funct7=0000000` | logical `rs1 >> rs2[4:0]` | rd write | 其他 funct7 illegal | `tb_CPU_Top`, `tb_ALU`／已驗證 |
| 17 | SRA `OP/101`, `funct7=0100000` | arithmetic `rs1 >>> rs2[4:0]` | rd write | 其他 funct7 illegal | `tb_CPU_Top`, `tb_ALU`／已驗證 |
| 18 | OR `OP/110`, `funct7=0000000` | `rs1 OR rs2` | rd write | 其他 funct7 illegal | `tb_CPU_Top`, `tb_ALU`／已驗證 |
| 19 | AND `OP/111`, `funct7=0000000` | `rs1 AND rs2` | rd write | 其他 funct7 illegal | `tb_CPU_Top`, `tb_ALU`／已驗證 |
| 20 | LUI `LUI` | `rd=imm[31:12]<<12` | rd write | 無額外條件 | `tb_CPU_Top`, `tb_Inst_Decoder`／已驗證 |
| 21 | AUIPC `AUIPC` | `rd=PC+(imm[31:12]<<12)` | rd write | 無額外條件 | `tb_CPU_Top`, `tb_CPU_Retire`／已驗證 |
| 22 | BEQ `BRANCH/000` | compare `rs1==rs2`; target `PC+sext(B-imm)` | PC redirect iff taken | taken target misaligned cause 0 | `tb_CPU_Branch`, `tb_CPU_Alignment`, `tb_CPU_Directed`／已驗證 |
| 23 | BNE `BRANCH/001` | compare `rs1!=rs2`; target `PC+sext(B-imm)` | PC redirect iff taken | taken target misaligned cause 0 | `tb_CPU_Branch`, `tb_CPU_Alignment`, `tb_CPU_Directed`／已驗證 |
| 24 | BLT `BRANCH/100` | signed `rs1<rs2` | PC redirect iff taken | taken target misaligned cause 0 | `tb_CPU_Branch`, `tb_CPU_Alignment`, `tb_CPU_Directed`／已驗證 |
| 25 | BGE `BRANCH/101` | signed `rs1>=rs2` | PC redirect iff taken | taken target misaligned cause 0 | `tb_CPU_Branch`, `tb_CPU_Alignment`, `tb_CPU_Directed`／已驗證 |
| 26 | BLTU `BRANCH/110` | unsigned `rs1<rs2` | PC redirect iff taken | taken target misaligned cause 0 | `tb_CPU_Branch`, `tb_CPU_Alignment`, `tb_CPU_Directed`／已驗證 |
| 27 | BGEU `BRANCH/111` | unsigned `rs1>=rs2` | PC redirect iff taken | taken target misaligned cause 0 | `tb_CPU_Branch`, `tb_CPU_Alignment`, `tb_CPU_Directed`／已驗證 |
| 28 | JAL `JAL` | target `PC+sext(J-imm)`; link `PC+4` | rd write + redirect | target misaligned cause 0 | `tb_CPU_JAL`, `tb_CPU_Alignment`, `tb_CPU_Directed`／已驗證 |
| 29 | JALR `JALR/000` | target `(rs1+sext(imm12)) & ~1`; link `PC+4` | rd write + redirect | target `[1:0]!=00` cause 0 | `tb_CPU_JALR`, `tb_CPU_Alignment`, `tb_CPU_Directed`／已驗證 |
| 30 | LB `LOAD/000` | byte at `rs1+sext(imm12)`, sign extend | memory read + rd write | 無 alignment trap | `tb_CPU_Load`, `tb_Load_Unit`／已驗證 |
| 31 | LH `LOAD/001` | halfword, sign extend | memory read + rd write | address[0] cause 4 | `tb_CPU_Load`, `tb_CPU_Alignment`, `tb_CPU_Directed`／已驗證 |
| 32 | LW `LOAD/010` | 32-bit word | memory read + rd write | address[1:0] cause 4 | `tb_CPU_Load`, `tb_CPU_Load_Hazard`, `tb_CPU_Alignment`, `tb_CPU_Directed`／已驗證 |
| 33 | LBU `LOAD/100` | byte, zero extend | memory read + rd write | 無 alignment trap | `tb_CPU_Load`, `tb_Load_Unit`／已驗證 |
| 34 | LHU `LOAD/101` | halfword, zero extend | memory read + rd write | address[0] cause 4 | `tb_CPU_Load`, `tb_CPU_Alignment`, `tb_CPU_Directed`／已驗證 |
| 35 | SB `STORE/000` | low byte of rs2 to effective address | one byte lane write | 無 alignment trap | `tb_CPU_Store`, `tb_Store_Unit`／已驗證 |
| 36 | SH `STORE/001` | low halfword of rs2 | two byte lanes write | address[0] cause 6 | `tb_CPU_Store`, `tb_CPU_Alignment`, `tb_CPU_Directed`／已驗證 |
| 37 | SW `STORE/010` | all 32 bits of rs2 | four byte lanes write | address[1:0] cause 6 | `tb_CPU_Store`, `tb_CPU_Alignment`, `tb_CPU_Directed`／已驗證 |
| 38 | FENCE `MISC-MEM/000` | pred/succ/fm are ordering metadata；rd/rs1 欄位不讀取、不形成 dependency | no register/memory write; ordering point retires | 其他 funct3 illegal | `tb_CPU_FENCE`, `tb_CPU_Directed`／已驗證 |
| 39 | ECALL exact `0x00000073` | no operands/result | trap only | cause 11, tval=0 | `tb_CPU_SYSTEM`／已驗證 |
| 40 | EBREAK exact `0x00100073` | no operands/result | trap only | cause 3, tval=0 | `tb_CPU_SYSTEM`, `tb_CPU_Image`, `tb_CPU_Directed`／已驗證 |

## 7. FENCE ordering contract

目前 Core 是 single-issue、in-order，沒有 cache、write buffer 或 outstanding memory transaction，因此合法 FENCE 在 v1.0 的現有 memory contract 下是無 register/memory side effect 的 ordering point：它必須合法 decode、不得宣告 rs1/rs2 dependency、不得寫 rd 或發 memory request，並產生一次 retire event。

若未來 memory interface 支援 outstanding request、buffer、cache 或可變延遲，FENCE 必須等待所有先前指定方向的 memory operation 完成後，才允許後續指定方向的 operation 可見；屆時不得沿用「純硬體 no-op」假設。

## 8. 驗收與變更規則

- 40 條指令的 directed regression 入口是 `./run_tests.sh directed`；完整入口是 `./run_tests.sh all`，失敗皆回傳非零 exit code。
- machine-readable matrix 必須維持 40 筆唯一指令，且每筆均有正向、corner、pipeline/control、trap/illegal 與存在的 evidence file。
- 任何 ISA、pipeline latency、reset vector、memory timing、trap/retire ports 或 alignment policy 變更，都屬於契約變更，必須同步更新 README、測試與 release manifest。
- v1.0 封版條件是 40 條矩陣全部有正向與必要 corner-case 測試、所有 trap 行為符合本文件、完整 regression 通過。

## 9. v1.0 synthesis 與 simulation 分界

- 正式 synthesis top 是 `CPU_Core`；其 source file list 鎖定於 `release/rv32i-core-v1.0.manifest.md`。
- `CPU_Sim_Top`、`CPU_Top`、`Program_ROM`、`Data_Memory` 與 `Arch_Test_Memory` 是 simulation/compatibility wrapper，不納入 v1.0 synthesizable hierarchy。
- `IFID.sv` 是可綜合的教學/備選模組，但目前未被 `CPU_Core` 實例化，因此不納入 v1.0 synthesis file list。
- memory request 沒有 ready/backpressure 或 transaction ID；每側至多一筆、固定一週期、in-order response。任何 wait-state 或多筆 outstanding 支援都屬於後續版本的介面變更。
