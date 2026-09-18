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

請仔細審查上述的 `b2b_orders_ai_toxic`，拿出一張紙或建立一個 markdown 檔案，列出你發現的**至少 6 個絕對不能進 Production 的致命地雷**，並說明原因。

<details>
<summary>🔍 點擊展開「Code Review 審查報告參考核對」</summary>

1. **違反 1NF（第一正規化）**：
   - 欄位重複（`product_1`, `product_2`, `product_3`）。如果客戶買了第 4 種產品就無法紀錄；查詢「誰買過產品 A」時必須在 WHERE 寫 3 次 OR 條件。
2. **違反 2NF / 3NF（更新與刪除異常）**：
   - `sales_rep_phone` 與 `sales_rep_commission_rate` 直接塞在訂單表中。如果某位業務員換了手機號碼，歷史上所有訂單都必須全部 UPDATE；漏改會造成資料不一致。
3. **無主鍵與外鍵約束 (No PK / FK)**：
   - `order_id` 沒有 Primary Key，可能插入重複訂單；沒有外鍵關聯檢查，客戶名字打錯會直接產生無法對帳的孤兒資料。
4. **型態災難 (Data Type Pitfall)**：
   - `total_amount` 居然用 `VARCHAR`，無法直接進行 `SUM()`、`AVG()` 數值聚合。
   - 單價與金額使用 `FLOAT`（浮點數），在結算千萬帳務時會發生著名的浮點數二進位精度損失（`0.1 + 0.2 != 0.3`），金流必須使用 `NUMERIC(12, 2)`。
5. **資料狀態與範圍無約束 (No CHECK Constraint)**：
   - `order_status` 接受任意字串，可能被寫入 `'Finished'`、`'OK'`、`'Done'`，造成分析混亂；數量與金額可能被寫入負數。
6. **缺乏稽核與時序欄位 (Missing Audit Trail)**：
   - 缺少 `created_at`、`updated_at`，無法進行增量抽取（Incremental ETL）與時序分析。
</details>

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

<details>
<summary>🔑 點擊展開「標準重構 DDL 參考」</summary>

```sql
-- 1. 業務員表
CREATE TABLE sales_reps (
    sales_rep_id    SERIAL PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    phone           VARCHAR(50),
    commission_rate NUMERIC(4, 2) NOT NULL DEFAULT 0.05 CHECK (commission_rate >= 0),
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

-- 2. 客戶表
CREATE TABLE customers (
    customer_id     SERIAL PRIMARY KEY,
    customer_name   VARCHAR(200) NOT NULL,
    tax_id          VARCHAR(20) UNIQUE,
    phone           VARCHAR(50),
    sales_rep_id    INT REFERENCES sales_reps(sales_rep_id) ON DELETE RESTRICT,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

-- 3. 訂單主表
CREATE TABLE orders (
    order_id        SERIAL PRIMARY KEY,
    order_number    VARCHAR(50) UNIQUE NOT NULL,
    customer_id     INT NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    order_date      DATE NOT NULL DEFAULT CURRENT_DATE,
    order_status    VARCHAR(20) NOT NULL DEFAULT 'Pending'
                    CHECK (order_status IN ('Pending', 'Completed', 'Cancelled')),
    total_amount    NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

-- 4. 訂單明細表
CREATE TABLE order_items (
    item_id         SERIAL PRIMARY KEY,
    order_id        INT NOT NULL REFERENCES orders(order_id) ON DELETE RESTRICT,
    product_name    VARCHAR(100) NOT NULL,
    quantity        INT NOT NULL CHECK (quantity > 0),
    unit_price      NUMERIC(12, 2) NOT NULL CHECK (unit_price >= 0),
    subtotal        NUMERIC(12, 2) NOT NULL CHECK (subtotal >= 0)
);
```
</details>

---

## 🧪 任務三：Constraint 破壞性測試 (Testing Mindset)

寫出 3 段測試 SQL，**證明你的資料庫能夠成功拒絕髒資料**：
1. **測試 1（外鍵防護）**：嘗試插入一筆屬於「不存在的 customer_id」的訂單，驗證報錯 `foreign key constraint violation`。
2. **測試 2（業務邏輯防護）**：嘗試在 order_items 插入 `quantity = -5`，驗證報錯 `check constraint violation`。
3. **測試 3（狀態約束防護）**：嘗試在 orders 插入 `order_status = 'InvalidStatus'`，驗證報錯。

<details>
<summary>🔑 點擊展開「破壞性測試 SQL 參考」</summary>

```sql
-- 測試 1：驗證 FK 阻擋孤兒訂單
-- 預期：ERROR: insert or update on table "orders" violates foreign key constraint
INSERT INTO orders (order_number, customer_id, total_amount)
VALUES ('ORD-TEST-999', 999999, 1000.00);

-- 測試 2：驗證 CHECK 阻擋負數數量
-- 預期：ERROR: new row for relation "order_items" violates check constraint "order_items_quantity_check"
INSERT INTO order_items (order_id, product_name, quantity, unit_price, subtotal)
VALUES (1, '測試產品', -5, 100.00, -500.00);

-- 測試 3：驗證 CHECK 阻擋非法狀態
-- 預期：ERROR: new row for relation "orders" violates check constraint "orders_order_status_check"
INSERT INTO orders (order_number, customer_id, order_status, total_amount)
VALUES ('ORD-TEST-888', 1, 'WeirdStatus', 1000.00);
```
</details>

---

## 🗣️ 口試題 (Interview Ready)

1. 「既然 3NF 這麼好，為什麼大型 Data Warehouse（如 Snowflake、BigQuery）常常推崇星狀模型（Star Schema）或反正規化寬表（One Big Table）？兩者的 Trade-off 是什麼？」
2. 「請解釋資料庫 Transaction 的 ACID 特性中，『I (Isolation)』的四個隔離層級分別防範什麼現象（Dirty Read, Non-repeatable Read, Phantom Read）？」

<details>
<summary>🔑 點擊展開「口試答題心法」</summary>

1. **OLTP vs OLAP 的根本 Trade-off**：
   - 3NF 追求的是「**寫入極致正確與防呆**」，消除冗餘與更新異常，適合高並發、頻繁寫入/修改的 OLTP 業務系統。
   - 但 3NF 查詢時需要多表 JOIN，在千萬/億級數據分析下成本極高。
   - 數據倉庫（OLAP）通常為「唯讀（Append-only）」且注重「**讀取與掃描速度**」，因此採用星狀模型或反正規化寬表，犧牲儲存空間與寫入冗餘，換取分析時無 JOIN、極致列式掃描的速度。
2. **隔離層級心智模型**：
   - Read Uncommitted（防 Dirty Write）➔ 允許髒讀。
   - Read Committed（防 Dirty Read）➔ 防止讀到別人的未提交變更。
   - Repeatable Read（防 Non-repeatable Read）➔ 保證同一個交易內讀取的數值不變。
   - Serializable（防 Phantom Read 與所有並發異常）➔ 完全序列化執行，代價是並發效能與衝突重試。
</details>

---

## 📝 結業簽核 (Pass Criteria)

- [ ] 指認出 AI Schema 的 6 大地雷並完成 Code Review 報告
- [ ] 成功在本機執行重構後的 3NF DDL
- [ ] 3 項 Constraint 破壞性測試全數成功阻擋髒資料
- [ ] 能清晰闡述正規化與反正規化的 Trade-off

> 達成上述條件，恭喜你完成 **Month 03 Exit Exam**！
