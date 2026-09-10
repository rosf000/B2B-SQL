# 03 PostgreSQL DDL、DML 與資料庫管理實務

> **寫在前面：從「查資料」到「管理資料庫」**
> 前兩個月你學的 SELECT、JOIN、Window Function 都屬於 **DML（資料操作語言）**。
> 本篇補齊另一個重要的技能層次：**DDL（資料定義語言）**——建立、修改、刪除資料表的能力。
>
> 在實際工作中，以下場景都需要 DDL：
> - 新功能上線，需要新增一張表或增加一個欄位
> - 系統重構，需要安全地遷移資料
> - 建立 View 讓 BI 工具直接使用，不暴露底層資料表結構
>
> 📌 本篇所有指令都可以在 DBeaver 的 SQL 編輯器中直接執行。

---

## 🗺️ 本篇學習地圖

```
DDL（資料定義語言）
  ├── CREATE TABLE（建立資料表）
  ├── ALTER TABLE（修改資料表結構）
  ├── DROP / TRUNCATE（刪除資料）
  └── 資料型別選擇指南

約束（Constraint）
  ├── PRIMARY KEY
  ├── FOREIGN KEY（含 ON DELETE 行為）
  ├── UNIQUE
  ├── CHECK
  └── NOT NULL / DEFAULT

View 與 Materialized View
  ├── 一般 View（即時）
  └── Materialized View（快照，可刷新）

Trigger 與 Stored Procedure 入門
  ├── Trigger：自動化動作
  └── Function：封裝複雜邏輯
```

---

## 一、DDL：CREATE TABLE 完整語法

### 1.1 標準建表語法

```sql
CREATE TABLE IF NOT EXISTS table_name (
    -- 欄位定義
    column_name  data_type  [constraint],
    ...
    -- 表格級約束
    [CONSTRAINT constraint_name constraint_definition],
    ...
);
```

**B2B 資料庫完整建表腳本**：

```sql
-- 先建父表，再建子表（避免 FK 找不到參考對象）

-- 1. salespeople（無外鍵，最先建）
CREATE TABLE IF NOT EXISTS salespeople (
    salesperson_id  SERIAL          PRIMARY KEY,
    name            VARCHAR(100)    NOT NULL,
    email           VARCHAR(200)    NOT NULL UNIQUE,
    region          VARCHAR(20)     NOT NULL
                    CHECK (region IN ('North', 'Central', 'South')),
    hire_date       DATE            NOT NULL DEFAULT CURRENT_DATE,
    monthly_target  NUMERIC(12, 2)  NOT NULL DEFAULT 0
                    CHECK (monthly_target >= 0),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP       NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP       NOT NULL DEFAULT NOW()
);

-- 2. customers（FK 指向 salespeople）
CREATE TABLE IF NOT EXISTS customers (
    customer_id     SERIAL          PRIMARY KEY,
    company_name    VARCHAR(200)    NOT NULL,
    tax_id          VARCHAR(10),
    industry        VARCHAR(50)     NOT NULL
                    CHECK (industry IN (
                        'Semiconductor', 'Software', 'Hardware',
                        'Finance', 'Manufacturing', 'Retail', 'Others'
                    )),
    city            VARCHAR(50),
    credit_limit    NUMERIC(14, 2)  NOT NULL DEFAULT 0
                    CHECK (credit_limit >= 0),
    salesperson_id  INT             REFERENCES salespeople(salesperson_id)
                    ON UPDATE CASCADE
                    ON DELETE SET NULL,
    status          VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE'
                    CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED')),
    created_at      TIMESTAMP       NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP       NOT NULL DEFAULT NOW(),

    -- 表格級約束：統一編號唯一（允許 NULL）
    CONSTRAINT uq_customers_tax_id UNIQUE (tax_id)
);

-- 3. products（無外鍵）
CREATE TABLE IF NOT EXISTS products (
    product_id      SERIAL          PRIMARY KEY,
    product_code    VARCHAR(20)     NOT NULL UNIQUE,
    product_name    VARCHAR(200)    NOT NULL,
    category        VARCHAR(50)     NOT NULL
                    CHECK (category IN ('Hardware', 'Software', 'Security', 'Service')),
    unit_price      NUMERIC(12, 2)  NOT NULL CHECK (unit_price > 0),
    cost_price      NUMERIC(12, 2)  NOT NULL CHECK (cost_price > 0),
    stock_quantity  INT             NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP       NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP       NOT NULL DEFAULT NOW(),

    -- 業務規則：售價必須高於成本（否則虧本出售）
    CONSTRAINT chk_price_gt_cost CHECK (unit_price > cost_price)
);

-- 4. orders（FK 指向 customers, salespeople）
CREATE TABLE IF NOT EXISTS orders (
    order_id        SERIAL          PRIMARY KEY,
    order_number    VARCHAR(20)     NOT NULL UNIQUE,
    order_date      DATE            NOT NULL DEFAULT CURRENT_DATE,
    status          VARCHAR(20)     NOT NULL DEFAULT 'PENDING'
                    CHECK (status IN ('PENDING', 'COMPLETED', 'CANCELLED')),
    total_amount    NUMERIC(14, 2)  DEFAULT 0,
    customer_id     INT             NOT NULL
                    REFERENCES customers(customer_id)
                    ON UPDATE CASCADE
                    ON DELETE RESTRICT,  -- 有訂單的客戶不能被刪除
    salesperson_id  INT             REFERENCES salespeople(salesperson_id)
                    ON UPDATE CASCADE
                    ON DELETE SET NULL,
    created_at      TIMESTAMP       NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP       NOT NULL DEFAULT NOW()
);

-- 5. order_items（FK 指向 orders, products；複合主鍵）
CREATE TABLE IF NOT EXISTS order_items (
    order_id        INT             NOT NULL
                    REFERENCES orders(order_id)
                    ON DELETE CASCADE,   -- 訂單刪除，明細跟著刪
    product_id      INT             NOT NULL
                    REFERENCES products(product_id)
                    ON DELETE RESTRICT,  -- 有明細的產品不能被刪除
    quantity        INT             NOT NULL CHECK (quantity > 0),
    unit_price      NUMERIC(12, 2)  NOT NULL CHECK (unit_price > 0),  -- 成交時的價格快照

    PRIMARY KEY (order_id, product_id)
);
```

---

## 二、資料型別選擇指南

這是初學者最常問的問題之一。以下是實務上的選擇原則：

### 2.1 文字型別

| 型別 | 說明 | 適用場景 | 注意事項 |
|------|------|---------|---------|
| `CHAR(n)` | 固定長度，不足補空白 | 國家代碼（'TW'）、性別代碼 | 幾乎已過時，少用 |
| `VARCHAR(n)` | 可變長度，有上限 | 大部分文字欄位 | 指定合理的上限 |
| `TEXT` | 可變長度，無上限 | 備註、說明、長文字 | 不適合頻繁 WHERE/JOIN |

```sql
-- 實務選擇準則
name        VARCHAR(100)   -- 姓名，100 字元夠用
email       VARCHAR(200)   -- Email
tax_id      VARCHAR(10)    -- 統一編號固定 8 碼，留 10 是為了國際化
status      VARCHAR(20)    -- 狀態碼，搭配 CHECK 約束
notes       TEXT           -- 備註欄位，無需限制長度
```

> ⚠️ 在 PostgreSQL 中，`VARCHAR(n)` 和 `TEXT` 的儲存效能**幾乎相同**，但 VARCHAR 提供了長度約束的保護。

### 2.2 數值型別

| 型別 | 精度 | 適用場景 | 注意事項 |
|------|------|---------|---------|
| `SMALLINT` | -32768 ~ 32767 | 庫存數量（小規模） | |
| `INT / INTEGER` | ±21億 | 一般 ID、數量 | 最常用 |
| `BIGINT` | ±922兆 | 大量 ID（如日誌、IoT） | |
| `SERIAL` | 等同 INT + 自動遞增 | 代理主鍵（Surrogate PK） | |
| `BIGSERIAL` | 等同 BIGINT + 自動遞增 | 超大表的代理主鍵 | |
| `NUMERIC(p, s)` | 精確小數 | **金額、財務數字** | |
| `DECIMAL(p, s)` | 同 NUMERIC | 金額（NUMERIC 的別名） | |
| `REAL` | 4 bytes 浮點 | 科學計算（允許誤差） | 勿用於金額！ |
| `DOUBLE PRECISION` | 8 bytes 浮點 | 科學計算 | 勿用於金額！ |

```sql
-- 金額欄位的正確設計
price       NUMERIC(12, 2)   -- 最多 12 位整數 + 2 位小數 = 可表示 999億
total       NUMERIC(14, 2)   -- 更大的總額欄位

-- ❌ 千萬不要用浮點數存金額！
price       FLOAT            -- 0.1 + 0.2 在浮點數中不等於 0.3！
```

### 2.3 日期時間型別

| 型別 | 說明 | 適用場景 |
|------|------|---------|
| `DATE` | 僅日期（YYYY-MM-DD） | 出生日期、訂單日期 |
| `TIME` | 僅時間（HH:MM:SS） | 營業時間 |
| `TIMESTAMP` | 日期+時間，無時區 | 一般紀錄時間（`created_at`） |
| `TIMESTAMPTZ` | 日期+時間，含時區 | 跨時區系統 |
| `INTERVAL` | 時間間隔 | `'30 days'`, `'1 month'` |

```sql
-- 最佳實踐：created_at 和 updated_at 幾乎每張表都應該有
created_at  TIMESTAMP   NOT NULL DEFAULT NOW(),
updated_at  TIMESTAMP   NOT NULL DEFAULT NOW()

-- 若系統有跨時區需求（如台灣 + 美國），使用 TIMESTAMPTZ
created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
```

---

## 三、ALTER TABLE 修改表格結構

在生產環境中，**絕對不能輕易刪除資料表重建**，必須用 ALTER TABLE 安全地修改結構。

```sql
-- 1. 新增欄位
ALTER TABLE customers
    ADD COLUMN phone VARCHAR(30),
    ADD COLUMN website VARCHAR(200),
    ADD COLUMN annual_revenue NUMERIC(16, 2);

-- 2. 修改欄位型別（注意：需確認資料兼容性）
ALTER TABLE customers
    ALTER COLUMN phone TYPE VARCHAR(50);

-- 3. 修改欄位的預設值
ALTER TABLE orders
    ALTER COLUMN status SET DEFAULT 'PENDING';

-- 4. 新增 NOT NULL 約束（需先確認現有資料沒有 NULL）
-- 步驟 1：先填補現有的 NULL 值
UPDATE customers SET phone = 'UNKNOWN' WHERE phone IS NULL;
-- 步驟 2：再設定 NOT NULL
ALTER TABLE customers
    ALTER COLUMN phone SET NOT NULL;

-- 5. 刪除欄位（⚠️ 不可逆！）
ALTER TABLE customers
    DROP COLUMN IF EXISTS legacy_field;

-- 6. 重新命名欄位
ALTER TABLE customers
    RENAME COLUMN company_name TO legal_name;

-- 7. 新增 CHECK 約束
ALTER TABLE products
    ADD CONSTRAINT chk_stock_non_negative
    CHECK (stock_quantity >= 0);

-- 8. 刪除約束
ALTER TABLE products
    DROP CONSTRAINT IF EXISTS chk_stock_non_negative;

-- 9. 新增索引
CREATE INDEX IF NOT EXISTS idx_customers_industry
ON customers(industry);

-- 10. 重新命名表格
ALTER TABLE customers RENAME TO clients;  -- 先確認沒有 View/Function 依賴此名稱
```

---

## 四、DROP 與 TRUNCATE 的差異

```sql
-- DROP TABLE：刪除表格結構和所有資料（不可逆）
DROP TABLE IF EXISTS temp_staging_data;

-- TRUNCATE：刪除所有資料，但保留表格結構（速度極快）
TRUNCATE TABLE temp_staging_data;

-- TRUNCATE vs DELETE 的差異
-- DELETE：逐列刪除，會記錄到 WAL（可復原），觸發 Trigger
-- TRUNCATE：直接清空，不記錄每列，不觸發 Trigger，速度快很多
DELETE FROM temp_data;      -- 慢（但可以加 WHERE 條件）
TRUNCATE TABLE temp_data;   -- 快（但不能加 WHERE）

-- ⚠️ TRUNCATE 注意事項：
-- 若表格有被其他表格的 FK 引用，需加 CASCADE
TRUNCATE TABLE orders CASCADE;   -- 同時清空 order_items（FK 關聯）
```

---

## 五、View（視圖）

View 是一個存儲的 SELECT 查詢，對使用者呈現為虛擬表格。

### 5.1 為什麼要用 View？

- **安全性**：BI 工具只能看到 View，不暴露底層表格結構和敏感欄位
- **簡化複雜查詢**：把 5 個表的 JOIN 封裝成一個 View，讓同事直接查詢
- **維護方便**：商業邏輯集中在 View 定義中，修改一處影響所有查詢

### 5.2 建立 View

```sql
-- 建立業務績效 View（供 BI 工具使用）
CREATE OR REPLACE VIEW v_sales_performance AS
SELECT
    s.salesperson_id,
    s.name                                      AS salesperson_name,
    s.region,
    s.monthly_target,
    DATE_TRUNC('month', o.order_date)::date     AS month,
    COUNT(DISTINCT o.order_id)                  AS order_count,
    COALESCE(SUM(o.total_amount), 0)            AS monthly_revenue,
    ROUND(
        COALESCE(SUM(o.total_amount), 0)
        / NULLIF(s.monthly_target, 0) * 100, 1
    )                                           AS target_achievement_pct
FROM salespeople s
LEFT JOIN orders o
    ON s.salesperson_id = o.salesperson_id
    AND o.status = 'COMPLETED'
WHERE s.is_active = TRUE
GROUP BY
    s.salesperson_id, s.name, s.region, s.monthly_target,
    DATE_TRUNC('month', o.order_date);

-- 使用 View（就像普通查詢一樣）
SELECT * FROM v_sales_performance
WHERE month = '2024-09-01'
ORDER BY monthly_revenue DESC;
```

```sql
-- 建立客戶 360 度視圖（整合所有客戶相關資訊）
CREATE OR REPLACE VIEW v_customer_360 AS
SELECT
    c.customer_id,
    c.company_name,
    c.industry,
    c.city,
    c.credit_limit,
    c.status,
    s.name                                      AS account_manager,
    s.region                                    AS sales_region,
    -- 彙總統計
    COUNT(DISTINCT o.order_id)                  AS total_orders,
    COALESCE(SUM(o.total_amount), 0)            AS lifetime_value,
    MAX(o.order_date)                           AS last_order_date,
    CURRENT_DATE - MAX(o.order_date)            AS days_since_last_order,
    -- 客戶健康度
    CASE
        WHEN MAX(o.order_date) IS NULL THEN 'Never Ordered'
        WHEN CURRENT_DATE - MAX(o.order_date) <= 90 THEN 'Active'
        WHEN CURRENT_DATE - MAX(o.order_date) <= 180 THEN 'At Risk'
        ELSE 'Churned'
    END                                         AS customer_health
FROM customers c
LEFT JOIN salespeople s ON c.salesperson_id = s.salesperson_id
LEFT JOIN orders o
    ON c.customer_id = o.customer_id
    AND o.status = 'COMPLETED'
GROUP BY
    c.customer_id, c.company_name, c.industry, c.city,
    c.credit_limit, c.status, s.name, s.region;

-- 刪除 View
DROP VIEW IF EXISTS v_customer_360;
```

---

## 六、Materialized View（物化視圖）

一般 View 每次查詢都要重新執行 SQL，Materialized View 則是把結果**存儲起來**，適合耗時的大型彙總查詢。

```sql
-- 建立物化視圖：月度業績彙總（查詢可能需要 3-5 秒的大型 JOIN）
CREATE MATERIALIZED VIEW mv_monthly_performance AS
SELECT
    DATE_TRUNC('month', o.order_date)::date         AS month,
    s.salesperson_id,
    s.name                                          AS salesperson_name,
    s.region,
    p.category                                      AS product_category,
    COUNT(DISTINCT o.order_id)                      AS order_count,
    SUM(oi.quantity)                                AS units_sold,
    SUM(oi.quantity * oi.unit_price)                AS revenue,
    SUM(oi.quantity * (oi.unit_price - p.cost_price)) AS gross_profit
FROM orders o
JOIN salespeople s      ON o.salesperson_id = s.salesperson_id
JOIN order_items oi     ON o.order_id = oi.order_id
JOIN products p         ON oi.product_id = p.product_id
WHERE o.status = 'COMPLETED'
GROUP BY
    DATE_TRUNC('month', o.order_date),
    s.salesperson_id, s.name, s.region,
    p.category
WITH DATA;  -- 建立時立即填充資料（去掉則建立空的）

-- 建立索引加速查詢
CREATE INDEX ON mv_monthly_performance(month);
CREATE INDEX ON mv_monthly_performance(salesperson_id, month);
CREATE INDEX ON mv_monthly_performance(product_category);

-- 刷新物化視圖（可放入排程）
REFRESH MATERIALIZED VIEW mv_monthly_performance;

-- 不鎖定的刷新（PostgreSQL 9.4+，刷新期間仍可查詢舊資料）
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_performance;

-- 查詢（毫秒級回應，因為資料已預計算）
SELECT
    month,
    salesperson_name,
    SUM(revenue) AS total_revenue
FROM mv_monthly_performance
WHERE month >= '2024-01-01'
GROUP BY month, salesperson_name
ORDER BY month, total_revenue DESC;
```

---

## 七、Trigger（觸發器）

Trigger 讓你在特定資料庫事件（INSERT / UPDATE / DELETE）發生時，自動執行某段 SQL。

### 7.1 自動更新 `updated_at` 欄位

```sql
-- 第一步：建立 Trigger Function
CREATE OR REPLACE FUNCTION fn_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();  -- 自動設定 updated_at 為當前時間
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 第二步：為每張需要的表建立 Trigger
CREATE TRIGGER trg_customers_updated_at
    BEFORE UPDATE ON customers         -- 在 UPDATE 之前觸發
    FOR EACH ROW                       -- 每一列都觸發
    EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION fn_update_timestamp();

-- 測試效果
UPDATE customers SET city = '高雄市' WHERE customer_id = 1;
SELECT customer_id, city, updated_at FROM customers WHERE customer_id = 1;
-- 可以看到 updated_at 已自動更新為當前時間
```

### 7.2 訂單金額自動彙總 Trigger

```sql
-- 需求：每次 order_items 有異動時，自動重新計算 orders.total_amount
CREATE OR REPLACE FUNCTION fn_recalculate_order_total()
RETURNS TRIGGER AS $$
BEGIN
    -- 無論是哪一列被 INSERT/UPDATE/DELETE，都重新計算對應訂單的總金額
    UPDATE orders
    SET total_amount = (
        SELECT COALESCE(SUM(quantity * unit_price), 0)
        FROM order_items
        WHERE order_id = COALESCE(NEW.order_id, OLD.order_id)
    )
    WHERE order_id = COALESCE(NEW.order_id, OLD.order_id);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 在 INSERT / UPDATE / DELETE 後都觸發
CREATE TRIGGER trg_order_items_update_total
    AFTER INSERT OR UPDATE OR DELETE ON order_items
    FOR EACH ROW
    EXECUTE FUNCTION fn_recalculate_order_total();
```

### 7.3 庫存自動扣減 Trigger

```sql
-- 需求：訂單狀態變為 COMPLETED 時，自動扣減對應產品的庫存
CREATE OR REPLACE FUNCTION fn_deduct_stock_on_complete()
RETURNS TRIGGER AS $$
BEGIN
    -- 只在狀態從非 COMPLETED 變為 COMPLETED 時觸發
    IF NEW.status = 'COMPLETED' AND (OLD.status IS NULL OR OLD.status != 'COMPLETED') THEN
        UPDATE products p
        SET stock_quantity = stock_quantity - oi.quantity
        FROM order_items oi
        WHERE oi.order_id = NEW.order_id
          AND p.product_id = oi.product_id;

        -- 檢查是否有庫存變為負數
        IF EXISTS (
            SELECT 1 FROM products
            WHERE product_id IN (SELECT product_id FROM order_items WHERE order_id = NEW.order_id)
              AND stock_quantity < 0
        ) THEN
            RAISE EXCEPTION '庫存不足，無法完成訂單 %', NEW.order_number;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_deduct_stock
    AFTER UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION fn_deduct_stock_on_complete();
```

---

## 八、Stored Function（預存函數）

把複雜的商業邏輯封裝成函數，讓應用程式只需要呼叫，不需要知道細節。

```sql
-- 函數：根據客戶 ID 取得完整的客戶摘要
CREATE OR REPLACE FUNCTION fn_get_customer_summary(p_customer_id INT)
RETURNS TABLE (
    company_name    VARCHAR,
    account_manager VARCHAR,
    total_orders    BIGINT,
    lifetime_value  NUMERIC,
    last_order_date DATE,
    customer_tier   TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.company_name,
        s.name,
        COUNT(DISTINCT o.order_id),
        COALESCE(SUM(o.total_amount), 0),
        MAX(o.order_date),
        CASE
            WHEN COALESCE(SUM(o.total_amount), 0) > 5000000 THEN '🏆 黃金客戶'
            WHEN COALESCE(SUM(o.total_amount), 0) > 1000000 THEN '💎 白銀客戶'
            ELSE '📋 一般客戶'
        END
    FROM customers c
    LEFT JOIN salespeople s ON c.salesperson_id = s.salesperson_id
    LEFT JOIN orders o ON c.customer_id = o.customer_id AND o.status = 'COMPLETED'
    WHERE c.customer_id = p_customer_id
    GROUP BY c.company_name, s.name;
END;
$$ LANGUAGE plpgsql;

-- 呼叫函數
SELECT * FROM fn_get_customer_summary(5);
```

---

## 九、DML 深度補充：INSERT / UPDATE / DELETE 進階用法

### 9.1 INSERT 進階用法

```sql
-- 基本 INSERT
INSERT INTO customers (company_name, industry, city, salesperson_id)
VALUES ('新創科技股份有限公司', 'Software', '台北市', 3);

-- 批次 INSERT（一次多筆）
INSERT INTO products (product_code, product_name, category, unit_price, cost_price)
VALUES
    ('AI-001', 'AI 加速卡', 'Hardware', 450000, 300000),
    ('AI-002', 'AI 訓練服務', 'Service',  200000, 100000),
    ('AI-003', 'MLOps 平台授權', 'Software', 180000, 80000);

-- UPSERT：INSERT，若已存在則 UPDATE（ON CONFLICT）
INSERT INTO products (product_code, product_name, unit_price, cost_price, category)
VALUES ('SRV-001', '企業伺服器 V2', 320000, 200000, 'Hardware')
ON CONFLICT (product_code) DO UPDATE
    SET
        product_name = EXCLUDED.product_name,
        unit_price   = EXCLUDED.unit_price,
        updated_at   = NOW();

-- INSERT ... SELECT：從查詢結果插入
INSERT INTO archived_orders (order_id, order_number, customer_id, total_amount, archived_at)
SELECT order_id, order_number, customer_id, total_amount, NOW()
FROM orders
WHERE order_date < '2023-01-01'
  AND status = 'COMPLETED';
```

### 9.2 UPDATE 進階用法

```sql
-- 基本 UPDATE
UPDATE customers
SET status = 'SUSPENDED', updated_at = NOW()
WHERE credit_limit = 0 AND status = 'ACTIVE';

-- UPDATE 搭配 FROM（用另一張表的資料更新）
-- 情境：根據 orders 表的最新業績，更新 salespeople 的上月業績欄位
UPDATE salespeople sp
SET last_month_revenue = monthly_sales.revenue
FROM (
    SELECT
        salesperson_id,
        SUM(total_amount) AS revenue
    FROM orders
    WHERE status = 'COMPLETED'
      AND DATE_TRUNC('month', order_date) = DATE_TRUNC('month', NOW()) - INTERVAL '1 month'
    GROUP BY salesperson_id
) AS monthly_sales
WHERE sp.salesperson_id = monthly_sales.salesperson_id;

-- RETURNING：UPDATE 後立即取回修改的資料
UPDATE orders
SET status = 'COMPLETED', updated_at = NOW()
WHERE order_id = 42
RETURNING order_id, order_number, status, total_amount;
```

### 9.3 DELETE 進階用法

```sql
-- DELETE 搭配 USING（類似 UPDATE...FROM）
-- 情境：刪除已超過 2 年的 CANCELLED 訂單（含其明細）
DELETE FROM orders
WHERE status = 'CANCELLED'
  AND order_date < CURRENT_DATE - INTERVAL '2 years';
-- 注意：order_items 的 FK 設了 ON DELETE CASCADE，會自動一起刪除

-- RETURNING：DELETE 後取回被刪除的資料
DELETE FROM customers
WHERE status = 'INACTIVE'
  AND NOT EXISTS (SELECT 1 FROM orders WHERE orders.customer_id = customers.customer_id)
RETURNING customer_id, company_name, '已刪除' AS action;
```

---

## 十、資料庫管理常用指令

```sql
-- 查看所有資料表
SELECT table_name, table_type
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_type, table_name;

-- 查看表格的欄位定義
SELECT column_name, data_type, character_maximum_length, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'orders'
ORDER BY ordinal_position;

-- 查看表格大小
SELECT
    relname                             AS table_name,
    pg_size_pretty(pg_total_relation_size(relid))  AS total_size,
    pg_size_pretty(pg_relation_size(relid))         AS table_size,
    pg_size_pretty(pg_total_relation_size(relid)
                   - pg_relation_size(relid))        AS index_size
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC;

-- 查看表格的所有 Index
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'orders';

-- 查看所有 View
SELECT viewname, definition
FROM pg_views
WHERE schemaname = 'public';

-- 查看所有 Trigger
SELECT
    trigger_name,
    event_manipulation,
    event_object_table,
    action_timing
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- 統計表格的列數（快速估算）
SELECT relname, reltuples::bigint AS estimated_rows
FROM pg_class
WHERE relkind = 'r' AND relname NOT LIKE 'pg_%'
ORDER BY reltuples DESC;
```

---

## 十一、本章重點彙整

```
DDL 指令
  CREATE TABLE ... (col type constraint, ...)
  ALTER TABLE ... ADD/ALTER/DROP COLUMN
  ALTER TABLE ... ADD/DROP CONSTRAINT
  DROP TABLE IF EXISTS
  TRUNCATE TABLE（清資料，保留結構）

資料型別選擇
  文字：VARCHAR(n) 有長度限制欄位，TEXT 無限制長文字
  金額：NUMERIC(p, s)，千萬不要用 FLOAT
  主鍵：SERIAL（INT 自動遞增），大表用 BIGSERIAL
  時間：TIMESTAMP（無時區），TIMESTAMPTZ（跨時區）

約束（Constraint）
  PRIMARY KEY / UNIQUE / NOT NULL / DEFAULT
  CHECK (condition)：值域驗證
  FOREIGN KEY ... ON DELETE CASCADE/SET NULL/RESTRICT

View vs Materialized View
  View：即時執行 SQL，資料永遠最新，但每次查詢都有計算成本
  Materialized View：預先計算存儲，查詢極快，需要定期 REFRESH

Trigger
  BEFORE/AFTER INSERT/UPDATE/DELETE FOR EACH ROW
  常見用途：自動更新 updated_at、彙總計算、庫存扣減

DML 進階
  UPSERT：INSERT ... ON CONFLICT DO UPDATE
  UPDATE ... FROM：用另一張表更新
  DELETE + RETURNING：刪除並回傳被刪的資料
```

---

*下一篇：[Month04 — Python 基礎與實用工具](../04_Month04_Python基礎與實用工具/01_Python環境_語法_資料結構全攻略.md)*
