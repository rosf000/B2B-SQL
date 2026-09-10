# 02 Index 索引原理與 ACID 交易安全機制

> **寫在前面：效能與可靠性的兩大支柱**
> 一個生產環境的資料庫必須同時具備兩個關鍵能力：
> 1. **快**：面對百萬筆資料，查詢仍要在毫秒內回應 → 靠 **Index（索引）**
> 2. **安全**：同時有 100 個人下訂單，帳不能算錯 → 靠 **Transaction + ACID**
>
> 本篇把這兩個主題從「知道有這個東西」提升到「能在面試中清楚說明、能在工作中正確使用」的程度。

---

## 🗺️ 本篇學習地圖

```
Index（索引）
  ├── B-Tree 索引結構圖解
  ├── 索引型態：B-Tree / Unique / Composite / Partial / GIN
  ├── 最左前綴原則（複合索引的關鍵）
  ├── 索引失效的常見陷阱
  └── 實務設計範例

ACID 交易特性
  ├── Atomicity（原子性）
  ├── Consistency（一致性）
  ├── Isolation（隔離性）
  │   └── 四個隔離等級 vs 三個異常現象
  └── Durability（持久性）

Transaction 實務
  ├── BEGIN / COMMIT / ROLLBACK
  ├── SAVEPOINT（部分回滾）
  ├── FOR UPDATE（悲觀鎖）
  └── 實際業務場景
```

---

## 一、Index 索引原理

### 1.1 沒有索引時發生什麼？

```sql
-- 在一張有 100 萬筆的 orders 表查詢特定客戶的訂單
SELECT * FROM orders WHERE customer_id = 42;
```

**沒有索引**：資料庫從第 1 筆掃到第 1,000,000 筆，一一比對（**Sequential Scan / Full Table Scan**），耗時可能超過 3 秒。

**有索引**：資料庫透過 B-Tree 結構，O(log N) 時間定位到目標，幾毫秒完成。

---

### 1.2 B-Tree 索引結構圖解

```
B-Tree（平衡樹）結構示意：以 customer_id 索引為例

                    [Root Node]
                   /    |     \
              [50]     [200]   [800]
             /   \     /   \    /  \
           [25] [75] [100][150][500][900]
           ...  ...   ...  ...  ...  ...

每個葉節點（Leaf Node）儲存：
  ┌─────────────┬──────────────────────────────┐
  │ customer_id │  指向實際資料列的指標（CTID）  │
  ├─────────────┼──────────────────────────────┤
  │      5      │  → Page 3, Row 12            │
  │     12      │  → Page 1, Row 7             │
  │     42      │  → Page 15, Row 3   ←── 找到！│
  │     58      │  → Page 8, Row 21            │
  └─────────────┴──────────────────────────────┘
```

**搜尋過程**：
1. 從 Root 開始，42 < 50，走左子樹
2. 42 < 25？不是，走右子樹
3. 到達葉節點，找到 customer_id = 42，得到指標 → Page 15, Row 3
4. 直接跳到 Page 15 讀取資料

**複雜度**：O(log N)，100 萬筆資料只需約 20 步比較。

---

### 1.3 索引型態

#### 1. B-Tree 索引（預設，最常用）

```sql
-- 適用於：=, <, >, <=, >=, BETWEEN, IN, ORDER BY, IS NULL
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_date ON orders(order_date);

-- 查看索引是否被使用（EXPLAIN 確認）
EXPLAIN SELECT * FROM orders WHERE customer_id = 42;
-- 理想結果：顯示 "Index Scan using idx_orders_customer_id"
-- 不理想結果：顯示 "Seq Scan"（索引未被使用）
```

#### 2. Unique 索引

```sql
-- 建立 Unique 索引（同時強制唯一性約束）
CREATE UNIQUE INDEX idx_customers_tax_id ON customers(tax_id)
WHERE tax_id IS NOT NULL;  -- 部分唯一索引：允許多個 NULL，但非 NULL 值必須唯一

-- 效果等同於 UNIQUE 約束，但更靈活
-- 注意：PRIMARY KEY 自動建立 Unique B-Tree Index
```

#### 3. Composite 複合索引（多欄位）

```sql
-- 情境：常常同時以 status + order_date 查詢
CREATE INDEX idx_orders_status_date ON orders(status, order_date);

-- 這個索引對以下查詢有效：
SELECT * FROM orders WHERE status = 'COMPLETED';                          -- ✅ 用到
SELECT * FROM orders WHERE status = 'COMPLETED' AND order_date > '2024-01-01'; -- ✅ 用到
SELECT * FROM orders WHERE status = 'COMPLETED' ORDER BY order_date DESC;      -- ✅ 用到

-- 對以下查詢無效（違反最左前綴原則）：
SELECT * FROM orders WHERE order_date > '2024-01-01';  -- ❌ 只用到 date，沒有 status
```

#### 4. Partial 部分索引

```sql
-- 情境：99% 的查詢只查 ACTIVE 客戶，沒必要對 INACTIVE 建索引
CREATE INDEX idx_customers_active ON customers(company_name)
WHERE status = 'ACTIVE';

-- 這個索引比全表索引小得多（只儲存 ACTIVE 的列）
-- 對以下查詢有效：
SELECT * FROM customers WHERE status = 'ACTIVE' AND company_name LIKE '台灣%';

-- 對以下查詢無效：
SELECT * FROM customers WHERE company_name LIKE '台灣%';  -- 沒有 status 條件
```

#### 5. GIN 索引（全文搜尋 / Array / JSONB）

```sql
-- 情境：對 JSONB 欄位或全文搜尋建立索引
-- 假設 products 有 tags JSONB 欄位
CREATE INDEX idx_products_tags ON products USING GIN(tags);

-- 全文搜尋索引
CREATE INDEX idx_products_fulltext
ON products USING GIN(to_tsvector('chinese', product_name || ' ' || COALESCE(description, '')));
```

---

### 1.4 最左前綴原則（Leftmost Prefix Rule）

這是面試最常考的索引知識點：

```
複合索引：CREATE INDEX idx ON orders(status, customer_id, order_date)
索引欄位順序：status(1) → customer_id(2) → order_date(3)

✅ 可用索引的查詢：
  WHERE status = 'X'                              → 使用欄位 (1)
  WHERE status = 'X' AND customer_id = 42         → 使用欄位 (1)(2)
  WHERE status = 'X' AND customer_id = 42 AND ... → 使用欄位 (1)(2)(3)

❌ 不可用索引的查詢：
  WHERE customer_id = 42                          → 跳過 (1)，索引失效
  WHERE order_date > '2024-01-01'                 → 跳過 (1)(2)，索引失效
  WHERE customer_id = 42 AND order_date > '...'   → 跳過 (1)，索引失效

⚠️ 範圍條件後的欄位失效：
  WHERE status = 'X' AND order_date > '2024-01-01' AND customer_id = 42
  → 使用 (1) status，範圍條件後的 (3) customer_id 無法使用索引
```

**設計複合索引的原則**：
1. **等值條件欄位放前面**（高選擇性的等值篩選）
2. **排序欄位次之**
3. **範圍條件欄位放最後**

---

### 1.5 索引失效的常見陷阱

```sql
-- ❌ 陷阱 1：對索引欄位做函數計算
WHERE EXTRACT(YEAR FROM order_date) = 2024        -- 索引失效
-- ✅ 正確：改為範圍條件
WHERE order_date BETWEEN '2024-01-01' AND '2024-12-31'

-- ❌ 陷阱 2：隱式型別轉換
WHERE customer_id = '42'   -- customer_id 是 INT，'42' 是 VARCHAR → 轉換後失效
-- ✅ 正確：型別一致
WHERE customer_id = 42

-- ❌ 陷阱 3：LIKE 以通配符開頭
WHERE company_name LIKE '%科技%'    -- 索引失效（無法從中間開始查樹）
-- ✅ 較優：以固定前綴開頭
WHERE company_name LIKE '台灣%'     -- 索引有效

-- ❌ 陷阱 4：NOT IN / <> 操作
WHERE status != 'CANCELLED'         -- 通常無法有效利用索引（會掃描大部分表）
-- ✅ 考慮用部分索引替代：
CREATE INDEX idx_non_cancelled ON orders(order_date) WHERE status != 'CANCELLED';

-- ❌ 陷阱 5：OR 條件（兩側必須都有索引才有效）
WHERE customer_id = 42 OR salesperson_id = 5
-- ✅ 改為 UNION ALL
SELECT * FROM orders WHERE customer_id = 42
UNION ALL
SELECT * FROM orders WHERE salesperson_id = 5;
```

---

### 1.6 B2B 資料庫的完整索引設計

```sql
-- orders 表（最常查詢的核心表）
CREATE INDEX idx_orders_customer     ON orders(customer_id);
CREATE INDEX idx_orders_salesperson  ON orders(salesperson_id);
CREATE INDEX idx_orders_status_date  ON orders(status, order_date);  -- 複合
CREATE INDEX idx_orders_date         ON orders(order_date);
-- 部分索引：只對 COMPLETED 訂單（分析查詢幾乎只看這個）
CREATE INDEX idx_orders_completed    ON orders(order_date, customer_id)
WHERE status = 'COMPLETED';

-- customers 表
CREATE INDEX idx_customers_salesperson ON customers(salesperson_id);
CREATE INDEX idx_customers_industry    ON customers(industry);
CREATE INDEX idx_customers_status      ON customers(status);
-- 活躍客戶的複合查詢
CREATE INDEX idx_customers_active_city ON customers(city)
WHERE status = 'ACTIVE';

-- order_items 表
-- (order_id, product_id) 已是 PRIMARY KEY = 已有索引
CREATE INDEX idx_items_product ON order_items(product_id);  -- 查詢某產品銷售紀錄

-- products 表
CREATE INDEX idx_products_category ON products(category);
-- 商品搜尋
CREATE INDEX idx_products_active_cat ON products(category, unit_price)
WHERE is_active = TRUE;

-- 查看所有索引的使用統計（找出從未被使用的索引）
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan          AS 使用次數,
    idx_tup_read      AS 讀取列數,
    pg_size_pretty(pg_relation_size(indexrelid)) AS 索引大小
FROM pg_stat_user_indexes
ORDER BY idx_scan ASC;   -- 使用次數少的索引可能是多餘的
```

---

## 二、ACID 交易特性

### 2.1 四大特性詳解

```
┌─────────────────────────────┬──────────────────────────────────────────────────────────────────┐
│ 特性                         │ 保護機制與實際意義                                              │
├─────────────────────────────┼──────────────────────────────────────────────────────────────────┤
│ A - Atomicity（原子性）      │ 交易是一個不可分割的最小單位。                                  │
│                              │ 場景：轉帳——從 A 帳戶扣款 + 向 B 帳戶入款。                    │
│                              │ 若入款失敗，扣款必須自動復原（ROLLBACK）。                      │
│                              │ 機制：WAL（Write-Ahead Log）記錄所有操作，失敗時 undo。        │
├─────────────────────────────┼──────────────────────────────────────────────────────────────────┤
│ C - Consistency（一致性）    │ 交易前後，資料庫必須滿足所有完整性約束。                        │
│                              │ 場景：訂單明細的外鍵（FK）必須存在；庫存不能變為負數。          │
│                              │ 機制：CHECK 約束、FK 約束、Trigger 共同維護。                   │
├─────────────────────────────┼──────────────────────────────────────────────────────────────────┤
│ I - Isolation（隔離性）      │ 多個並發交易彼此隔離，不互相干擾。                              │
│                              │ 場景：兩個業務同時查詢同一個客戶的信用額度，各自扣款。          │
│                              │ 機制：鎖（Lock）、MVCC（多版本並發控制）。                      │
├─────────────────────────────┼──────────────────────────────────────────────────────────────────┤
│ D - Durability（持久性）     │ 已 COMMIT 的交易，即使伺服器斷電也不會遺失。                    │
│                              │ 機制：WAL 先寫到磁碟，確保資料永久保存。                        │
└─────────────────────────────┴──────────────────────────────────────────────────────────────────┘
```

---

### 2.2 隔離性的四個等級 vs 三個異常現象

隔離性不是「全有全無」，PostgreSQL 提供四個隔離等級，保護不同的異常情況：

**三個異常現象**：

| 異常 | 說明 | 情境舉例 |
|------|------|---------|
| **Dirty Read（髒讀）** | 讀到另一個交易**尚未提交**的資料 | A 改了庫存但還沒 COMMIT，B 就讀到了錯誤數字 |
| **Non-Repeatable Read（不可重複讀）** | 同一交易中兩次讀取同一筆資料，結果不同 | A 第一次讀到庫存=10，B COMMIT 改成5，A 第二次讀到5 |
| **Phantom Read（幻讀）** | 同一交易中兩次查詢，第二次多出了新列 | A 查詢庫存>0的產品得到5筆，B 新增了一筆，A 再查得到6筆 |

**四個隔離等級**：

| 隔離等級 | Dirty Read | Non-Repeatable Read | Phantom Read | 效能 |
|---------|-----------|---------------------|-------------|------|
| `READ UNCOMMITTED` | 可能 | 可能 | 可能 | 最快 |
| `READ COMMITTED`（PG預設）| 防止 | 可能 | 可能 | 快 |
| `REPEATABLE READ` | 防止 | 防止 | 可能* | 中 |
| `SERIALIZABLE` | 防止 | 防止 | 防止 | 最慢 |

> *PostgreSQL 的 REPEATABLE READ 實際上也防止了幻讀（MVCC 的特性）

```sql
-- 設定交易的隔離等級
BEGIN ISOLATION LEVEL READ COMMITTED;    -- 預設值
BEGIN ISOLATION LEVEL REPEATABLE READ;  -- 報表、統計分析時使用
BEGIN ISOLATION LEVEL SERIALIZABLE;     -- 金融交易、轉帳時使用
```

---

### 2.3 PostgreSQL 的 MVCC（多版本並發控制）

PostgreSQL 不是用「讀鎖」來隔離讀取，而是用 **MVCC（Multi-Version Concurrency Control）**：

```
MVCC 工作原理：

時間軸：
T1: BEGIN → UPDATE customer set city='高雄市' WHERE id=5 → COMMIT
T2: BEGIN → SELECT city FROM customer WHERE id=5         → ...

不使用 MVCC（悲觀鎖）：T2 必須等待 T1 COMMIT 才能讀取
使用 MVCC（PostgreSQL）：T2 讀到 T1 COMMIT 前的「快照版本」，不需要等待

效果：
  ✅ 讀取不阻塞寫入
  ✅ 寫入不阻塞讀取
  ✅ 大幅提升並發效能
  ⚠️ 代價：過時的「死列（dead tuples）」需要 VACUUM 清理
```

---

## 三、Transaction 交易實務

### 3.1 基本語法

```sql
BEGIN;              -- 開始交易（等同於 START TRANSACTION;）
  -- SQL 語句 1
  -- SQL 語句 2
  -- ...
COMMIT;             -- 提交：確認所有修改永久生效
-- 或
ROLLBACK;           -- 回滾：放棄所有修改，恢復到 BEGIN 前的狀態
```

---

### 3.2 完整業務場景：訂單成立（含庫存扣減與錯誤處理）

```sql
-- 模擬下單流程的完整交易
BEGIN;

-- 步驟 1：鎖定庫存列（FOR UPDATE = 悲觀鎖，防止超賣）
-- 若另一個交易也在執行，它會等待這個交易釋放鎖
SELECT
    product_id,
    product_name,
    stock_quantity
FROM products
WHERE product_id = 101
FOR UPDATE;      -- 鎖定這一列，其他交易無法同時 UPDATE 這列

-- 步驟 2：確認庫存充足（在應用程式層面做判斷）
-- 若 stock_quantity < 需求數量 → 在應用程式中執行 ROLLBACK

-- 步驟 3：扣減庫存
UPDATE products
SET
    stock_quantity = stock_quantity - 2,
    updated_at     = NOW()
WHERE product_id = 101
  AND stock_quantity >= 2;   -- 雙重保險：確保不會扣成負數

-- 檢查是否真的有更新（若 stock_quantity < 2，這個 UPDATE 影響 0 列）
-- 若 GET DIAGNOSTICS rows_affected = ROW_COUNT; rows_affected = 0 則 ROLLBACK

-- 步驟 4：建立訂單主檔
INSERT INTO orders (
    order_number,
    order_date,
    status,
    customer_id,
    salesperson_id,
    total_amount
) VALUES (
    'ORD-2024-999',
    CURRENT_DATE,
    'PENDING',
    5,
    3,
    598000   -- 2 × 299,000
)
RETURNING order_id;  -- 取得剛建立的 order_id

-- 步驟 5：建立訂單明細（使用上面 RETURNING 的 order_id）
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES (currval('orders_order_id_seq'), 101, 2, 299000);

-- 步驟 6：更新訂單狀態為 COMPLETED
UPDATE orders
SET status = 'COMPLETED', updated_at = NOW()
WHERE order_id = currval('orders_order_id_seq');

-- 一切正常：提交交易
COMMIT;

-- 若任何步驟失敗（在 PL/pgSQL 或應用程式中捕捉例外）：
-- ROLLBACK;
```

---

### 3.3 SAVEPOINT — 部分回滾

```sql
-- 情境：處理一批訂單，某筆訂單失敗時只回滾該筆，繼續處理下一筆
BEGIN;

-- 處理訂單 1
SAVEPOINT sp_order_1;
INSERT INTO orders (...) VALUES (...);
-- 若失敗：
ROLLBACK TO SAVEPOINT sp_order_1;  -- 只回滾到這個 SAVEPOINT，之前的仍保留

-- 繼續處理訂單 2
SAVEPOINT sp_order_2;
INSERT INTO orders (...) VALUES (...);
-- 成功

-- 處理訂單 3
SAVEPOINT sp_order_3;
UPDATE products SET stock_quantity = stock_quantity - 100
WHERE product_id = 5;  -- 若失敗（庫存不足）
ROLLBACK TO SAVEPOINT sp_order_3;

-- 釋放不再需要的 SAVEPOINT（可選，節省記憶體）
RELEASE SAVEPOINT sp_order_1;
RELEASE SAVEPOINT sp_order_2;

COMMIT;  -- 提交成功的部分（訂單 1 和 2）
```

---

### 3.4 FOR UPDATE 與鎖的類型

```sql
-- 1. FOR UPDATE — 排他鎖（最常用）
-- 其他交易的 SELECT FOR UPDATE 和 UPDATE 都必須等待
SELECT * FROM products WHERE product_id = 101 FOR UPDATE;

-- 2. FOR SHARE — 共享鎖
-- 允許其他交易同時 SELECT FOR SHARE，但阻止 UPDATE/DELETE
SELECT * FROM products WHERE product_id = 101 FOR SHARE;

-- 3. NOWAIT — 若無法立即取得鎖則立即報錯（不等待）
SELECT * FROM products WHERE product_id = 101 FOR UPDATE NOWAIT;
-- 若另一個交易持有此列的鎖，立即拋出 ERROR 而不是等待

-- 4. SKIP LOCKED — 跳過已鎖定的列（適合任務隊列）
-- 情境：多個 Worker 同時從任務表中取工作，各自取不同的任務
SELECT task_id, task_data
FROM job_queue
WHERE status = 'PENDING'
ORDER BY created_at
LIMIT 1
FOR UPDATE SKIP LOCKED;  -- 取第一個沒被其他 Worker 鎖定的任務
```

---

### 3.5 實戰：月結帳處理（需要 SERIALIZABLE 隔離等級）

```sql
-- 情境：月結帳時，計算所有業務的獎金並更新，需要保證計算的一致性
BEGIN ISOLATION LEVEL SERIALIZABLE;

-- 建立這個月份的業績快照（在 SERIALIZABLE 下，讀到的資料是一致的）
CREATE TEMP TABLE month_end_snapshot AS
SELECT
    s.salesperson_id,
    s.name,
    s.monthly_target,
    COALESCE(SUM(o.total_amount), 0)    AS actual_revenue,
    CASE
        WHEN COALESCE(SUM(o.total_amount), 0) >= s.monthly_target * 1.2
        THEN COALESCE(SUM(o.total_amount), 0) * 0.05   -- 超標 20%，5% 獎金
        WHEN COALESCE(SUM(o.total_amount), 0) >= s.monthly_target
        THEN COALESCE(SUM(o.total_amount), 0) * 0.03   -- 達標，3% 獎金
        ELSE 0                                          -- 未達標，無獎金
    END                                 AS bonus
FROM salespeople s
LEFT JOIN orders o
    ON s.salesperson_id = o.salesperson_id
    AND o.status = 'COMPLETED'
    AND DATE_TRUNC('month', o.order_date) = DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')
GROUP BY s.salesperson_id, s.name, s.monthly_target;

-- 將獎金寫入獎金記錄表（假設有此表）
INSERT INTO bonus_records (salesperson_id, period, revenue, bonus_amount, recorded_at)
SELECT
    salesperson_id,
    DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')::date,
    actual_revenue,
    bonus,
    NOW()
FROM month_end_snapshot
WHERE bonus > 0
ON CONFLICT (salesperson_id, period) DO NOTHING;  -- 避免重複寫入

COMMIT;
```

---

## 四、面試常見問題整理

### Q1：解釋 ACID 各代表什麼？

> **A**tomicity（原子性）：交易是最小單位，全成功或全失敗。
> **C**onsistency（一致性）：交易前後資料庫的完整性約束必須成立。
> **I**solation（隔離性）：多個並發交易互不干擾，透過隔離等級控制。
> **D**urability（持久性）：COMMIT 後的資料永久保存，靠 WAL 機制保證。

### Q2：什麼情況下索引會失效？

> 1. 對索引欄位使用函數（`YEAR(date)`）
> 2. 隱式型別轉換（`INT = '42'`）
> 3. LIKE 以通配符開頭（`LIKE '%keyword'`）
> 4. 違反複合索引的最左前綴原則
> 5. NOT IN / != 操作（通常仍需全表掃描）

### Q3：TRUNCATE 和 DELETE 的差異？

> | | DELETE | TRUNCATE |
> |---|---|---|
> | 可加 WHERE | ✅ | ❌ |
> | 觸發 Trigger | ✅ | ❌ |
> | 可 ROLLBACK | ✅ | ✅（在交易中） |
> | 速度 | 慢（逐列） | 快（直接清空） |
> | 重置 SERIAL | ❌ | ✅ |

### Q4：READ COMMITTED 和 REPEATABLE READ 的差異？

> **READ COMMITTED**（PostgreSQL 預設）：每個 SQL 語句都讀取最新的 COMMIT 版本。同一交易中兩次查詢可能看到不同的結果。
>
> **REPEATABLE READ**：整個交易期間看到的資料快照固定在 BEGIN 時的狀態。適合需要一致性讀取的報表生成場景。

---

## 五、本章重點彙整

```
Index 索引
  B-Tree：預設型態，支援 =/</>  /BETWEEN/IN/ORDER BY
  Unique：強制唯一性，允許部分唯一（WHERE）
  Composite：多欄位，遵守最左前綴原則（等值→排序→範圍）
  Partial：只對符合條件的列建索引，更小更快

  失效陷阱：
    ❌ 函數計算（YEAR(date)）
    ❌ 隱式型別轉換
    ❌ LIKE '%前綴'
    ❌ 違反最左前綴

ACID
  Atomicity → WAL，BEGIN/COMMIT/ROLLBACK
  Consistency → CHECK/FK/Trigger
  Isolation → MVCC + 隔離等級
    READ COMMITTED → 防止 Dirty Read（預設）
    REPEATABLE READ → 另加防止 Non-Repeatable Read
    SERIALIZABLE → 完整隔離，最安全
  Durability → WAL 先寫磁碟

Transaction 實務
  FOR UPDATE → 悲觀鎖，防止超賣
  SAVEPOINT → 部分回滾
  SKIP LOCKED → 任務隊列場景
  NOWAIT → 無法取鎖時立即報錯
```

---

*下一篇：[03 PostgreSQL DDL、DML 與資料庫管理實務](./03_PostgreSQL_DDL_DML與管理實務.md)*
