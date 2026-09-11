# 🎓 M3 Exit Exam：Schema Review 實戰審查挑戰

> **「在 AI 時代，讓 LLM 生出一段 `CREATE TABLE` 只要 3 秒鐘；但能在 30 秒內看出這張表會不會在半年後搞垮整間公司資料庫的，才叫 Data Engineer。」**

歡迎來到 Month 03 的結業驗收！本測驗考察你的「架構審查（Schema Review）」與「Constraint 防禦性測試」能力。

---

## 📋 測驗標準與三層完成度 (Three-Tier Mastery)

- 🟢 **Level 1 — Survival**：能指認出 Schema 中至少 3 個違反正規化（1NF/2NF/3NF）的明顯錯誤。
- 🔵 **Level 2 — Job Ready (80分晉級線)**：
  - 抓出全部 6 大核心設計地雷。
  - 獨立寫出重構後的 3NF 乾淨 DDL（含 PK, FK, CHECK, NUMERIC 型態）。
  - 撰寫破壞性測試（Constraint Test）驗證約束能成功攔截髒資料。
- 🔴 **Level 3 — Bonus (Interview Ready)**：
  - 解釋「什麼時候該刻意反正規化（Denormalization）」的 Trade-off。
  - 解釋 PostgreSQL 複合索引（Composite Index）的 Leftmost Prefix 原則與 B-Tree 代價。

---

## 🚨 審查案例：某 AI 助理產出的「毒瘤」Schema

某初階工程師向 AI 提問：「幫我設計一張 B2B 客戶與訂單的資料表」，AI 給出了以下單表設計：

```sql
CREATE TABLE b2b_orders_ai_toxic (
    order_id INT,
    customer_name VARCHAR(255),
    customer_tax_id VARCHAR(50),
    customer_phone VARCHAR(50),
    sales_rep_name VARCHAR(100),
    sales_rep_phone VARCHAR(50),
    sales_rep_commission_rate FLOAT,
    product_1_name VARCHAR(100),
    product_1_price FLOAT,
    product_1_qty INT,
    product_2_name VARCHAR(100),
    product_2_price FLOAT,
    product_2_qty INT,
    product_3_name VARCHAR(100),
    product_3_price FLOAT,
    product_3_qty INT,
    total_amount VARCHAR(50),
    order_status VARCHAR(20)
);
```

---

## 💻 任務一：抓出 6 大致命設計地雷 (Code Review)

請逐一列出並回答「為什麼這段 DDL 絕對不能進 Production」：

1. **違反 1NF（第一正規化）**：
   - 欄位重複（`product_1`, `product_2`, `product_3`）。如果客戶買了第 4 種產品怎麼辦？查詢「誰買過產品 A」時 SQL 該怎麼寫？
2. **違反 2NF / 3NF（更新與刪除異常）**：
   - `sales_rep_phone` 與 `sales_rep_commission_rate` 直接塞在訂單表中。如果某位業務員換了手機號碼，歷史上所有訂單都必須 UPDATE？如果沒改乾淨會發生什麼事？
3. **無主鍵與外鍵約束 (No PK / FK)**：
   - `order_id` 沒有 Primary Key，可能插入重複訂單；沒有關聯檢查，客戶名字打錯會直接產生孤兒資料。
4. **型態災難 (Data Type Pitfall)**：
   - `total_amount` 居然用 `VARCHAR`？金額怎麼做 `SUM()` 聚合？
   - 金額與單價使用 `FLOAT`（二進位浮點數），在結算千萬帳務時會發生著名的浮點數精度損失（如 `0.1 + 0.2 != 0.3`），應改用 `NUMERIC(12, 2)`。
5. **資料狀態與範圍無約束 (No CHECK Constraint)**：
   - `order_status` 接受任意字串，可能被寫入 `'Finished'`、`'OK'`、`'Done'`，造成分析混亂；數量可能被寫入負數。
6. **缺乏稽核與時序欄位 (Missing Audit Trail)**：
   - 缺少 `created_at`、`updated_at`，無法進行增量抽取（Incremental ETL）與時序分析。

---

## 🛠️ 任務二：重構為符合 3NF 的企業級 DDL

請在你的 PostgreSQL 中執行重構，拆分為至少 4 張標準關聯表：
- `sales_reps` (業務員表)
- `customers` (客戶表，含 FK -> sales_reps)
- `orders` (訂單主表，含 FK -> customers)
- `order_items` (訂單明細表，含 FK -> orders)

### 必須具備的工程約束：
- 所有表均有適當的 Primary Key。
- 外鍵均設置 `ON DELETE RESTRICT`（防誤刪歷史交易）。
- 數量必須 `CHECK (quantity > 0)`。
- 金額一律採用 `NUMERIC(12, 2)`。
- 狀態必須設置 `CHECK (status IN ('Pending', 'Completed', 'Cancelled'))`。

---

## 🧪 任務三：Constraint 破壞性測試 (Testing Mindset)

寫出 3 段測試 SQL，**證明你的資料庫能夠成功拒絕髒資料**：
1. **測試 1（外鍵防護）**：嘗試插入一筆屬於「不存在的 customer_id」的訂單，驗證報錯 `foreign key constraint violation`。
2. **測試 2（業務邏輯防護）**：嘗試在 order_items 插入 `quantity = -5`，驗證報錯 `check constraint violation`。
3. **測試 3（精度驗證）**：插入 `NUMERIC` 計算加總，證明分毫無差。

---

## 🗣️ 口試題 (Interview Ready)

1. 「既然 3NF 這麼好，為什麼大型 Data Warehouse（如 Snowflake、BigQuery）常常推崇星狀模型（Star Schema）或反正規化寬表（One Big Table）？兩者的 Trade-off 是什麼？」
2. 「請解釋資料庫 Transaction 的 ACID 特性中，『I (Isolation)』的四個隔離層級分別防範什麼現象（Dirty Read, Non-repeatable Read, Phantom Read）？」

---

## 📝 結業簽核 (Pass Criteria)

- [ ] 指認出 AI Schema 的 6 大地雷並完成 Code Review 報告
- [ ] 成功在本機執行重構後的 3NF DDL
- [ ] 3 項 Constraint 破壞性測試全數成功阻擋髒資料
- [ ] 能清晰闡述正規化與反正規化的 Trade-off

> 達成上述條件，恭喜你完成 **Month 03 Exit Exam**！
