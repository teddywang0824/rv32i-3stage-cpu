# 文件導覽

[專案首頁](../README.md) · [學習進度頁](../index.html) · [v1.0 release](../release/rv32i-core-v1.0.manifest.md)

這裡是 RV32I Core v1.0 的文件入口。文件依用途分成「理解設計」、「重現驗證」與「確認 release」三條路線；不需要照資料夾名稱猜閱讀順序。

## 第一次閱讀

1. [專案首頁](../README.md)：快速開始、pipeline 概觀、支援指令與驗證總覽。
2. [RV32I Core v1.0 規格契約](rv32i-core-spec.md)：正式 ISA、reset、memory、trap 與 retire 行為。
3. [程式映像與記憶體配置](program-image-memory-map.md)：區分 split-memory smoke flow 與 unified-memory regression flow。
4. [RTL 品質稽核](../verification/rtl-quality-audit.md)：lint、reset/valid 與 side-effect 檢查證據。
5. [v1.0 release manifest](../release/rv32i-core-v1.0.manifest.md)：封存來源、工具版本、測試結果與限制。

## 要重現測試

- 一般 unit/integration、ELF image、directed、ACT4 與 compiled C 的完整環境步驟：見 [README「從新環境復刻驗證」](../README.md#從新環境復刻驗證)。
- ACT4/UDB/Sail 的設定與單項重跑：見 [ACT4 驗證指南](../verification/arch-test/README.md)。
- 傳統 split IMEM/DMEM 的 HEX 格式：見 [memory image 格式](../tests/images/README.md)。
- 最終 lint 與 side-effect 稽核：見 [RTL 品質稽核](../verification/rtl-quality-audit.md)。

## 文件權威順序

若描述互相衝突，依下列順序判斷並修正文檔：

1. release tag 對應的 RTL 與自動化測試；
2. [v1.0 規格契約](rv32i-core-spec.md)；
3. [release manifest](../release/rv32i-core-v1.0.manifest.md)；
4. 專題指南與根目錄 README。

`index.html` 是學習步驟與進度介面，不取代正式的 architectural contract。

---

[回到專案首頁](../README.md) · [下一篇：RV32I Core v1.0 規格契約](rv32i-core-spec.md)
