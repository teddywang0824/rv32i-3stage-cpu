# Memory image 格式

Instruction image 與 data image 都使用 `$readmemh` 的 word-per-line
純文字格式。

- 第 N 行對應 byte address `N * 4`。
- 每行必須是 8 個十六進位數字，不加 `0x`。
- 每行是 CPU 直接看到的 32-bit word，不做 byte swap。
- 未由 instruction image 覆蓋的 IMEM word 初始化為 `00000013`（NOP）。
- 未由 data image 覆蓋的 DMEM word 初始化為 `00000000`。
- Instruction image 最多 64 words（256 bytes）。
- Data image 最多 1024 words（4096 bytes）。
- 映像路徑以執行模擬時的專案根目錄為基準。

Smoke images 對應的程式為：

```asm
lw     x1, 0(x0)
lw     x2, 4(x0)
add    x3, x1, x2
sw     x3, 8(x0)
ebreak
```
