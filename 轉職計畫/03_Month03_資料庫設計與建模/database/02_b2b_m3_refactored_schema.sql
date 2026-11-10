-- ============================================================
--  02_b2b_m3_refactored_schema.sql
--  【標準重構參考解答】
--
--  ✅  這是正確的企業級 B2B Schema 設計。
--
--  ⚠️  建議先自己嘗試重構 01_b2b_m3_bad_schema.sql，
--      完成後再閱讀此文件對照差異。
--
--  改善重點：
--    - 分拆成 6 張符合 3NF 的表
--    - 修正所有違反 1NF/2NF/3NF 的問題
--    - 加入完整的 PK / FK / UNIQUE / CHECK 約束
--    - 使用正確的資料型別（NUMERIC、DATE、BOOLEAN）
--    - 加入 created_at / updated_at 稽核欄位
--    - 建立索引提升查詢效能
--    - 自動維護 updated_at 的 Trigger
-- ============================================================


-- ============================================================
--  清理舊資料（依照 FK 依賴順序由子表到父表）
-- ============================================================

DROP TABLE IF EXISTS m3_order_items  CASCADE;
DROP TABLE IF EXISTS m3_orders       CASCADE;
DROP TABLE IF EXISTS m3_products     CASCADE;
DROP TABLE IF EXISTS m3_customer_phones CASCADE;
DROP TABLE IF EXISTS m3_customers    CASCADE;
DROP TABLE IF EXISTS m3_salespeople  CASCADE;


-- ============================================================
--  TABLE 1：m3_salespeople — 業務員主表
--  解決的問題：
--    - 業務員資訊不再重複存於每筆訂單
--    - sales_region 直接屬於 salesperson（消除 3NF 遞移相依）
-- ============================================================

CREATE TABLE m3_salespeople (
    salesperson_id  SERIAL          PRIMARY KEY,
    name            VARCHAR(100)    NOT NULL,
    email           VARCHAR(200)    NOT NULL UNIQUE,
    region          VARCHAR(20)     NOT NULL
                        CHECK (region IN ('North', 'Central', 'South', 'East')),
    hire_date       DATE            NOT NULL DEFAULT CURRENT_DATE,
    monthly_target  NUMERIC(12, 2)  NOT NULL DEFAULT 0
                        CHECK (monthly_target >= 0),    -- ✅ NUMERIC 避免浮點誤差
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE  m3_salespeople                IS '業務員主表';
COMMENT ON COLUMN m3_salespeople.region         IS '負責區域；限 North/Central/South/East';
COMMENT ON COLUMN m3_salespeople.monthly_target IS '月度業績目標（TWD），使用 NUMERIC 確保精度';


-- ============================================================
--  TABLE 2：m3_customers — 客戶主表
--  解決的問題：
--    - 客戶資訊獨立成表，不再重複於每筆訂單（2NF）
--    - tax_id 加 UNIQUE 防止重複建檔
--    - credit_limit 使用 NUMERIC 並加 CHECK >= 0
-- ============================================================

CREATE TABLE m3_customers (
    customer_id     SERIAL          PRIMARY KEY,
    company_name    VARCHAR(200)    NOT NULL,
    tax_id          VARCHAR(20)     NOT NULL UNIQUE,     -- ✅ 統編唯一
    industry        VARCHAR(100),
    city            VARCHAR(100),
    credit_limit    NUMERIC(14, 2)  NOT NULL DEFAULT 0
                        CHECK (credit_limit >= 0),      -- ✅ 不可為負
    salesperson_id  INTEGER
                        REFERENCES m3_salespeople(salesperson_id)
                        ON DELETE SET NULL,             -- ✅ 業務離職時不刪客戶資料
    status          VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE'
                        CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED')),
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE  m3_customers                 IS '客戶（公司）主表';
COMMENT ON COLUMN m3_customers.tax_id          IS '統一編號，全系統唯一';
COMMENT ON COLUMN m3_customers.credit_limit    IS '授信額度（TWD）';
COMMENT ON COLUMN m3_customers.salesperson_id  IS '負責業務員；業務員離職後設為 NULL';


-- ============================================================
--  TABLE 3：m3_customer_phones — 客戶電話表
--  解決的問題：
--    - 拆除 phone_1/phone_2/phone_3 重複欄位（1NF）
--    - 一個客戶可有任意數量的電話，每筆獨立一列
-- ============================================================

CREATE TABLE m3_customer_phones (
    phone_id        SERIAL          PRIMARY KEY,
    customer_id     INTEGER         NOT NULL
                        REFERENCES m3_customers(customer_id)
                        ON DELETE CASCADE,              -- ✅ 客戶刪除時一併清除電話
    phone_type      VARCHAR(20)     NOT NULL
                        CHECK (phone_type IN ('office', 'mobile', 'fax')),
    phone_number    VARCHAR(50)     NOT NULL
);

COMMENT ON TABLE  m3_customer_phones            IS '客戶電話子表（1NF：一列一支電話）';
COMMENT ON COLUMN m3_customer_phones.phone_type IS '電話類型：office/mobile/fax';


-- ============================================================
--  TABLE 4：m3_products — 產品主表
--  解決的問題：
--    - 產品不再以 product_1/2/3 重複欄位存在訂單中（1NF）
--    - unit_price > cost_price 以表格級約束確保
--    - 所有金額使用 NUMERIC（非 FLOAT）
-- ============================================================

CREATE TABLE m3_products (
    product_id      SERIAL          PRIMARY KEY,
    product_code    VARCHAR(50)     NOT NULL UNIQUE,    -- ✅ 料號唯一
    product_name    VARCHAR(200)    NOT NULL,
    category        VARCHAR(50)     NOT NULL
                        CHECK (category IN ('Hardware', 'Software', 'Security', 'Service', 'Network')),
    unit_price      NUMERIC(12, 2)  NOT NULL
                        CHECK (unit_price > 0),
    cost_price      NUMERIC(12, 2)  NOT NULL
                        CHECK (cost_price > 0),
    stock_quantity  INTEGER         NOT NULL DEFAULT 0
                        CHECK (stock_quantity >= 0),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- ✅ 表格級約束：售價必須高於成本（無法在欄位級別交叉比較）
    CONSTRAINT chk_price_gt_cost CHECK (unit_price > cost_price)
);

COMMENT ON TABLE  m3_products                   IS '產品主表';
COMMENT ON COLUMN m3_products.product_code      IS '內部料號，全系統唯一';
COMMENT ON COLUMN m3_products.unit_price        IS '售價（TWD），必須大於成本';
COMMENT ON COLUMN m3_products.cost_price        IS '成本價（TWD）';
COMMENT ON COLUMN m3_products.stock_quantity    IS '現有庫存量，不可為負';


-- ============================================================
--  TABLE 5：m3_orders — 訂單主表
--  解決的問題：
--    - 訂單獨立成表，每筆只存一次
--    - order_number 加 UNIQUE 防重複
--    - status 有 CHECK 確保只有合法狀態
--    - total_amount 使用 NUMERIC（以 Trigger 或應用層由明細計算）
--    - order_date 使用 DATE 型別
-- ============================================================

CREATE TABLE m3_orders (
    order_id        SERIAL          PRIMARY KEY,
    order_number    VARCHAR(50)     NOT NULL UNIQUE,    -- ✅ 訂單編號唯一
    order_date      DATE            NOT NULL DEFAULT CURRENT_DATE,
    status          VARCHAR(20)     NOT NULL DEFAULT 'PENDING'
                        CHECK (status IN ('PENDING', 'CONFIRMED', 'COMPLETED', 'CANCELLED')),
    total_amount    NUMERIC(14, 2)  NOT NULL DEFAULT 0, -- ✅ 由明細彙總；非 VARCHAR
    customer_id     INTEGER         NOT NULL
                        REFERENCES m3_customers(customer_id)
                        ON DELETE RESTRICT,             -- ✅ 有訂單時不允許刪除客戶
    salesperson_id  INTEGER
                        REFERENCES m3_salespeople(salesperson_id)
                        ON DELETE SET NULL,
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE  m3_orders                 IS '訂單主表';
COMMENT ON COLUMN m3_orders.order_number    IS '對外訂單編號（如 ORD-2024-001），必須唯一';
COMMENT ON COLUMN m3_orders.total_amount    IS '訂單總金額（TWD），由 order_items 彙總';
COMMENT ON COLUMN m3_orders.status          IS '訂單狀態：PENDING/CONFIRMED/COMPLETED/CANCELLED';


-- ============================================================
--  TABLE 6：m3_order_items — 訂單明細表
--  解決的問題：
--    - 拆除 product_1/2/3 重複群組（1NF）
--    - 一筆訂單可包含任意數量的產品，每筆獨立一列
--    - unit_price 為成交時快照（不隨商品漲價而變動）
--    - 複合 PK (order_id, product_id) 防止同訂單同產品重複
-- ============================================================

CREATE TABLE m3_order_items (
    order_id        INTEGER         NOT NULL
                        REFERENCES m3_orders(order_id)
                        ON DELETE CASCADE,              -- ✅ 訂單刪除時明細一併清除
    product_id      INTEGER         NOT NULL
                        REFERENCES m3_products(product_id)
                        ON DELETE RESTRICT,             -- ✅ 有歷史訂單的商品不可刪除
    quantity        INTEGER         NOT NULL
                        CHECK (quantity > 0),
    unit_price      NUMERIC(12, 2)  NOT NULL            -- ✅ 成交時的價格快照
                        CHECK (unit_price > 0),

    PRIMARY KEY (order_id, product_id)                  -- ✅ 複合 PK：同訂單同產品只能一列
);

COMMENT ON TABLE  m3_order_items            IS '訂單明細表（解決 1NF 重複群組）';
COMMENT ON COLUMN m3_order_items.unit_price IS '成交時的售價快照，不隨商品定價異動';


-- ============================================================
--  索引建立
--  依照常見查詢模式建立，提升效能
-- ============================================================

-- 客戶 → 負責業務員（JOIN 或篩選業務員的客戶清單）
CREATE INDEX idx_m3_customers_salesperson   ON m3_customers(salesperson_id);

-- 客戶狀態篩選（例如只看 ACTIVE 客戶）
CREATE INDEX idx_m3_customers_status        ON m3_customers(status);

-- 訂單 → 客戶（JOIN 客戶詳情）
CREATE INDEX idx_m3_orders_customer         ON m3_orders(customer_id);

-- 訂單狀態 + 日期複合索引（例如查某月的 PENDING 訂單）
CREATE INDEX idx_m3_orders_status_date      ON m3_orders(status, order_date);

-- 訂單明細 → 商品（JOIN 商品詳情、或查某商品的歷史銷售）
CREATE INDEX idx_m3_items_product           ON m3_order_items(product_id);


-- ============================================================
--  Trigger：自動更新 updated_at
--  凡是有 updated_at 欄位的表，異動時自動更新為當前時間
-- ============================================================

-- Step 1：建立共用的 Trigger Function
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_set_updated_at() IS '自動將 updated_at 更新為當前時間的共用 Trigger Function';

-- Step 2：為各表掛載 Trigger（BEFORE UPDATE 觸發）

CREATE TRIGGER trg_customers_updated_at
    BEFORE UPDATE ON m3_customers
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_products_updated_at
    BEFORE UPDATE ON m3_products
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_orders_updated_at
    BEFORE UPDATE ON m3_orders
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();


-- ============================================================
--  種子測試資料（乾淨、符合所有約束）
-- ============================================================

-- 1. 業務員
INSERT INTO m3_salespeople (name, email, region, hire_date, monthly_target) VALUES
    ('王大明', 'wang.daming@company.com',  'North',   '2020-03-01', 2000000.00),
    ('陳小花', 'chen.xiaohua@company.com', 'South',   '2021-07-15', 1500000.00),
    ('林志遠', 'lin.zhiyuan@company.com',  'East',    '2022-01-10', 1200000.00),
    ('吳美麗', 'wu.meili@company.com',     'Central', '2023-05-20', 1800000.00);

-- 2. 客戶
INSERT INTO m3_customers (company_name, tax_id, industry, city, credit_limit, salesperson_id, status) VALUES
    ('台灣科技股份有限公司', '12345678', 'IT',   '台北', 5000000.00, 1, 'ACTIVE'),
    ('南方貿易有限公司',     '87654321', '製造業', '高雄', 2000000.00, 2, 'ACTIVE'),
    ('東部建設開發',         '11223344', '建設', '花蓮',  800000.00, 3, 'ACTIVE'),
    ('中部精密工業',         '55667788', '製造業', '台中', 3000000.00, 4, 'INACTIVE');

-- 3. 客戶電話（每位客戶可有多筆，符合 1NF）
INSERT INTO m3_customer_phones (customer_id, phone_type, phone_number) VALUES
    (1, 'office', '02-2345-6789'),
    (1, 'mobile', '0912-345-678'),
    (2, 'office', '07-333-4444'),
    (3, 'office', '03-856-7890'),
    (3, 'mobile', '0933-111-222'),
    (3, 'fax',    '03-856-7891'),
    (4, 'office', '04-2222-3333');

-- 4. 產品
INSERT INTO m3_products (product_code, product_name, category, unit_price, cost_price, stock_quantity) VALUES
    ('NAS-001',  'NAS 儲存設備 16TB',    'Hardware', 150000.00, 95000.00,  12),
    ('UTM-001',  'UTM 防火牆 企業版',    'Security', 220000.00, 140000.00,  8),
    ('SW-ERP-01','ERP 企業授權 (100U)',   'Software', 180000.00, 80000.00,  50),
    ('NET-IND-01','工業路由器 5G',        'Network',   60000.00, 35000.00,  25),
    ('HW-TAB-01','工業平板電腦 IP67',     'Hardware',  75000.00, 45000.00,  30),
    ('SEC-CAM-01','監控攝影機套組 8CH',   'Security',  45000.00, 25000.00,  40);

-- 5. 訂單
INSERT INTO m3_orders (order_number, order_date, status, total_amount, customer_id, salesperson_id) VALUES
    ('ORD-2024-001', '2024-01-15', 'COMPLETED', 520000.00, 1, 1),
    ('ORD-2024-002', '2024-02-01', 'COMPLETED', 120000.00, 2, 2),
    ('ORD-2024-003', '2024-02-10', 'CANCELLED',       0.00, 3, 3),
    ('ORD-2024-004', '2024-03-05', 'PENDING',   900000.00, 1, 1),
    ('ORD-2024-005', '2024-04-20', 'CONFIRMED',  75000.00, 4, 4);

-- 6. 訂單明細（符合 1NF：一列一個商品，解決重複群組）
INSERT INTO m3_order_items (order_id, product_id, quantity, unit_price) VALUES
    -- ORD-2024-001：NAS x2 + UTM x1
    (1, 1, 2, 150000.00),
    (1, 2, 1, 220000.00),
    -- ORD-2024-002：工業路由器 x2
    (2, 4, 2,  60000.00),
    -- ORD-2024-003：已取消，明細不填（或填後 total_amount=0 均可）
    -- ORD-2024-004：ERP x5
    (4, 3, 5, 180000.00),
    -- ORD-2024-005：工業平板 x1
    (5, 5, 1,  75000.00);


-- ============================================================
--  快速驗證查詢（執行後確認資料正確）
-- ============================================================

/*
-- 查看每筆訂單的客戶、業務員、明細數、金額
SELECT
    o.order_number,
    o.order_date,
    o.status,
    c.company_name,
    s.name            AS salesperson,
    s.region,
    COUNT(oi.product_id) AS item_count,
    SUM(oi.quantity * oi.unit_price) AS calculated_total
FROM m3_orders o
JOIN m3_customers   c  ON c.customer_id   = o.customer_id
LEFT JOIN m3_salespeople s ON s.salesperson_id = o.salesperson_id
LEFT JOIN m3_order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id, o.order_number, o.order_date, o.status,
         c.company_name, s.name, s.region
ORDER BY o.order_date;

-- 查看客戶的所有電話（1NF 子表）
SELECT
    c.company_name,
    p.phone_type,
    p.phone_number
FROM m3_customers c
JOIN m3_customer_phones p ON p.customer_id = c.customer_id
ORDER BY c.customer_id, p.phone_type;
*/
