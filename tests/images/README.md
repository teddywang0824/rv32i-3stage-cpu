# Split-memory HEX 範例

[文件導覽](../../docs/README.md) · [程式映像與記憶體配置](../../docs/program-image-memory-map.md) · [專案首頁](../../README.md)

本目錄只有早期 split IMEM/DMEM smoke test 的靜態範例，不是 ACT4 或 compiled C 使用的 unified-memory image。正式 `run_tests.sh image` 會重新由 Assembly/ELF 生成映像到 `build/programs/image_smoke/`。

## 格式

- `$readmemh` word-per-line 純文字。
- 第 `N` 行對應該 memory 的 byte offset `N * 4`。
- 每行是 8 個十六進位數字，不加 `0x`，內容是 CPU 直接看到的 32-bit word。
- 預設 split IMEM 最多 64 words，未提供位置填入 `00000013`（NOP）。
- 預設 split DMEM 最多 1024 words，未提供位置填入 `00000000`。
- 路徑以執行模擬時的專案根目錄為基準。

## 範例程式

`image_smoke.hex` 和 `image_smoke_data.hex` 對應：

```asm
lw     x1, 0(x0)
lw     x2, 4(x0)
add    x3, x1, x2
sw     x3, 8(x0)
ebreak
```

要驗證 converter、ELF metadata、生成 HEX 與 RTL 執行結果是否一致，請在專案根目錄執行：

```bash
bash run_tests.sh image
```

---

[回到程式映像文件](../../docs/program-image-memory-map.md) · [前往 ACT4 unified-memory flow](../../verification/arch-test/README.md)
