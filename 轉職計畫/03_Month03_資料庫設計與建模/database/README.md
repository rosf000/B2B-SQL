# database/

本資料夾收錄 Month 03「資料庫設計與建模」的 SQL 實作練習檔。

## 檔案說明

| 檔案 | 用途 |
|------|------|
| `01_b2b_m3_bad_schema.sql` | **毒瘤 Schema**：刻意設計錯誤，違反 1NF / 2NF / 3NF，缺少 PK / FK / CHECK 等約束。用於練習識別正規化違規與資料品質問題。 |
| `02_b2b_m3_refactored_schema.sql` | **標準重構參考解答**：符合 3NF 的企業級 DDL，包含完整約束、索引與自動更新 `updated_at` 的 Trigger。作為對照參考。 |

## 建議使用方式

1. **閱讀** `01_b2b_m3_bad_schema.sql`，找出所有設計問題（提示：超過 15 個）
2. **自己動手**重構，寫出你認為正確的 Schema
3. **執行** `01` 文件，觀察髒資料如何在沒有約束的情況下被順利插入
4. **對照** `02_b2b_m3_refactored_schema.sql`，比較你的版本與參考解答的差異
5. **執行** `02` 文件，確認所有約束能正確攔截非法資料

## 練習重點

- 識別 **1NF 違規**：重複欄位（`phone_1/2/3`）、重複群組（`product_1/2/3_*`）
- 識別 **2NF 違規**：部分相依（客戶資訊、業務員資訊混入訂單表）
- 識別 **3NF 違規**：遞移相依（`salesperson_id → sales_region`）
- 修正**資料型別錯誤**：金額用 `FLOAT`、日期用 `VARCHAR`
- 補充**完整性約束**：PK、FK、UNIQUE、CHECK、NOT NULL
