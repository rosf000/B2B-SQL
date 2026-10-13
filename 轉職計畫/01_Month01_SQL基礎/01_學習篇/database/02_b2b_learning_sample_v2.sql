-- ============================================================================
-- B2B 模擬資料集 v2：進階版（PostgreSQL 適用）
-- ============================================================================
--
-- 本檔案是 v1 (b2b_m1_sample.sql) 的增強版本，【欄位名稱向下相容】。
-- 03 題庫 Q1~Q30 可直接使用本 v2 資料庫，預期查詢結果與 v1 一致。
--
-- 【v2 相比 v1 的主要升級】
--   • 員工工號 (employee_no)、客戶編碼 (customer_code)
--   • 帳單地址 (billing_address)、付款帳期 (payment_terms)
--   • 統編正則驗證（必須為 8 碼數字）
--   • 軟刪除旗標 (is_active)、離職日期 (resigned_date)
--   • 訂單快照欄位：凍結下單當時的客戶名稱與統編
--   • GENERATED COLUMN：小計 / 成本小計 / 毛利 自動計算，永遠正確
--   • Trigger 自動匯總：明細異動時即時回寫訂單金額
--   • CHECK 約束：金額非負、日期邏輯、狀態值域
--   • ON DELETE RESTRICT：保護財務單據不被意外刪除
--   • 金額一致性約束：total_amount = subtotal_amount + tax_amount
--
-- 【給學習者的提示】
--   如果你目前在 Month01，先專注在 SELECT / WHERE / GROUP BY / JOIN 的練習。
--   v2 新增的進階功能（GENERATED COLUMN、Trigger、CHECK）會在後續月份學到，
--   現在只需要知道「它們在幫你自動維護資料正確性」就好。
--
-- ============================================================================

-- ============================================================================
-- 0. 清理舊表、載入擴充套件、建立通用 Trigger 函數
-- ============================================================================

-- 刪除舊表（依相依性反向刪除，CASCADE 會一併清除相關的索引與觸發器）
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS salespeople CASCADE;

-- 刪除舊函數
DROP FUNCTION IF EXISTS fn_update_timestamp CASCADE;
DROP FUNCTION IF EXISTS fn_recalculate_order_totals CASCADE;

-- uuid-ossp：提供 UUID 生成功能（目前未使用，但 B2B 系統常見需求，先載入備用）
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 通用時間戳更新函數：任何表的 updated_at 欄位在 UPDATE 時自動刷新
-- ※ 你在 Month01 不需要理解這段，只需知道「修改資料時 updated_at 會自動更新」
CREATE OR REPLACE FUNCTION fn_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 1. 業務員資料表 (salespeople)
-- ============================================================================
-- 記錄公司的業務團隊成員資訊
-- 與 v1 差異：新增 employee_no (工號)、resigned_date (離職日)、is_active (在職旗標)

CREATE TABLE salespeople (
    salesperson_id   SERIAL PRIMARY KEY,                                         -- 系統自動編號
    employee_no      VARCHAR(30) NOT NULL UNIQUE,                                -- 員工工號（避免靠姓名辨識）
    name             VARCHAR(100) NOT NULL,                                      -- 姓名
    email            VARCHAR(255) NOT NULL UNIQUE,                               -- Email（唯一）
    region           VARCHAR(20) NOT NULL
                     CHECK (region IN ('North', 'Central', 'South', 'Overseas')),-- 所屬區域
    hire_date        DATE NOT NULL DEFAULT CURRENT_DATE,                         -- 到職日期
    resigned_date    DATE,                                                       -- 離職日期（NULL = 在職）
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,                              -- 在職狀態（軟刪除用）
    monthly_target   NUMERIC(14, 2) NOT NULL DEFAULT 0.00
                     CHECK (monthly_target >= 0),                                -- 月業績目標
    created_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (resigned_date IS NULL OR resigned_date >= hire_date)                  -- 離職日不可早於到職日
);

CREATE TRIGGER trg_salespeople_timestamp
BEFORE UPDATE ON salespeople
FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

-- ============================================================================
-- 2. 客戶主檔 (customers)
-- ============================================================================
-- 記錄企業客戶的基本資訊
-- 與 v1 差異：新增 customer_code、billing_address、payment_terms；tax_id 加正則驗證
-- 欄位名保持相容：city、status、credit_limit 等名稱不變，03 題庫可直接查詢

CREATE TABLE customers (
    customer_id      SERIAL PRIMARY KEY,
    customer_code    VARCHAR(50) NOT NULL UNIQUE,                                -- 客戶內部編碼（如 CUST-0001）
    company_name     VARCHAR(200) NOT NULL,
    tax_id           VARCHAR(8) UNIQUE
                     CHECK (tax_id IS NULL OR tax_id ~ '^[0-9]{8}$'),           -- 台灣統一編號：8 碼數字
    industry         VARCHAR(50) NOT NULL,
    city             VARCHAR(50) NOT NULL,                                       -- 所在城市（保留供 Q30 等題目使用）
    billing_address  TEXT NOT NULL,                                              -- 帳單/發票寄送地址
    payment_terms    VARCHAR(30) NOT NULL DEFAULT 'NET_30'
                     CHECK (payment_terms IN ('COD', 'NET_30', 'NET_60', 'NET_90')), -- B2B 帳期
    credit_limit     NUMERIC(14, 2) NOT NULL DEFAULT 0.00
                     CHECK (credit_limit >= 0),
    salesperson_id   INT REFERENCES salespeople(salesperson_id) ON DELETE RESTRICT, -- 負責業務員
    status           VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
                     CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED')),      -- 客戶狀態
    created_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_customers_salesperson ON customers(salesperson_id);
CREATE INDEX idx_customers_tax_id ON customers(tax_id);

CREATE TRIGGER trg_customers_timestamp
BEFORE UPDATE ON customers
FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

-- ============================================================================
-- 3. 產品主檔 (products)
-- ============================================================================
-- 記錄公司銷售的產品/服務項目
-- 欄位名保持相容：unit_price (售價)、cost_price (成本) 與 v1 相同

CREATE TABLE products (
    product_id       SERIAL PRIMARY KEY,
    product_code     VARCHAR(50) NOT NULL UNIQUE,
    product_name     VARCHAR(200) NOT NULL,
    category         VARCHAR(50) NOT NULL
                     CHECK (category IN ('Hardware', 'Software', 'Security', 'Service')),
    unit_price       NUMERIC(14, 2) NOT NULL CHECK (unit_price >= 0),            -- 公定牌價（未稅）
    cost_price       NUMERIC(14, 2) NOT NULL CHECK (cost_price >= 0),            -- 目前標準進貨成本
    stock_quantity   INT NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),          -- 現貨庫存（服務類可為 0）
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,                              -- 是否停產/下架
    created_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER trg_products_timestamp
BEFORE UPDATE ON products
FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

-- ============================================================================
-- 4. 訂單主表 (orders)
-- ============================================================================
-- 記錄每一筆 B2B 訂單的摘要資訊
-- 欄位名保持相容：status（不是 order_status）、total_amount 與 v1 相同
-- 與 v1 差異：新增快照欄位、金額拆分（未稅 + 稅額 + 含稅）

CREATE TABLE orders (
    order_id               SERIAL PRIMARY KEY,
    order_number           VARCHAR(60) NOT NULL UNIQUE,
    order_date             DATE NOT NULL DEFAULT CURRENT_DATE,
    customer_id            INT NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    salesperson_id         INT NOT NULL REFERENCES salespeople(salesperson_id) ON DELETE RESTRICT,

    -- 歷史快照：凍結下單當時的客戶名稱與統編，即使日後客戶改名也不影響歷史紀錄
    snapshot_company_name  VARCHAR(200) NOT NULL,
    snapshot_tax_id        VARCHAR(8),

    -- 訂單狀態（完整 B2B 生命週期）
    status                 VARCHAR(30) NOT NULL DEFAULT 'DRAFT'
                           CHECK (status IN ('DRAFT', 'APPROVED', 'PROCESSING',
                                             'SHIPPED', 'COMPLETED', 'CANCELLED')),

    -- 金額拆分（未稅 + 稅額 + 含稅總額）
    -- ※ 這三個欄位由 Trigger 自動維護，你不需要手動計算
    currency               CHAR(3) NOT NULL DEFAULT 'TWD',
    subtotal_amount        NUMERIC(14, 2) NOT NULL DEFAULT 0.00 CHECK (subtotal_amount >= 0),
    tax_rate               NUMERIC(4, 3) NOT NULL DEFAULT 0.050,                 -- 預設 5% 營業稅
    tax_amount             NUMERIC(14, 2) NOT NULL DEFAULT 0.00 CHECK (tax_amount >= 0),
    total_amount           NUMERIC(14, 2) NOT NULL DEFAULT 0.00 CHECK (total_amount >= 0),

    notes                  TEXT,
    created_at             TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- 金額一致性約束：確保含稅總額 = 未稅金額 + 稅額，防止資料不一致
    CHECK (total_amount = subtotal_amount + tax_amount)
);

CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_salesperson ON orders(salesperson_id);
CREATE INDEX idx_orders_date_status ON orders(order_date, status);

CREATE TRIGGER trg_orders_timestamp
BEFORE UPDATE ON orders
FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

-- ============================================================================
-- 5. 訂單明細表 (order_items)
-- ============================================================================
-- 記錄訂單中每個品項的數量、成交價與成本
-- 欄位名保持相容：unit_price (成交單價)、subtotal (小計) 與 v1 相同
-- 與 v1 差異：
--   • subtotal 改為 GENERATED COLUMN（自動計算，不可能算錯）
--   • 新增 cost_price 快照、cost_subtotal、gross_profit
--   • 新增 line_number 項次編號
--   • ON DELETE RESTRICT（保護財務單據，不允許直接刪除有明細的訂單）

CREATE TABLE order_items (
    item_id          SERIAL PRIMARY KEY,
    order_id         INT NOT NULL REFERENCES orders(order_id) ON DELETE RESTRICT, -- ⚠️ v1 是 CASCADE，v2 改為 RESTRICT
    line_number      INT NOT NULL,                                                -- 項次（1, 2, 3...）
    product_id       INT NOT NULL REFERENCES products(product_id) ON DELETE RESTRICT,
    quantity         INT NOT NULL CHECK (quantity > 0),
    unit_price       NUMERIC(14, 2) NOT NULL CHECK (unit_price >= 0),             -- 成交單價（未稅）
    cost_price       NUMERIC(14, 2) NOT NULL CHECK (cost_price >= 0),             -- 成交當下成本快照

    -- GENERATED COLUMN：以下三欄由資料庫自動計算，INSERT 時不需要（也不能）指定
    -- ※ Month01 不需要理解語法，只需知道「它們永遠是正確的計算結果」
    subtotal         NUMERIC(14, 2) GENERATED ALWAYS AS (quantity * unit_price) STORED,  -- 未稅小計
    cost_subtotal    NUMERIC(14, 2) GENERATED ALWAYS AS (quantity * cost_price) STORED,  -- 成本小計
    gross_profit     NUMERIC(14, 2) GENERATED ALWAYS AS
                     ((quantity * unit_price) - (quantity * cost_price)) STORED,          -- 該項毛利

    created_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_order_line UNIQUE (order_id, line_number),                      -- 同一張訂單不可有重複項次
    CONSTRAINT uq_order_product UNIQUE (order_id, product_id)                     -- 同一張訂單不可重複出現相同產品
);

CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_product ON order_items(product_id);

-- ============================================================================
-- 6. 自動匯總 Trigger
-- ============================================================================
-- 當 order_items 有新增、修改或刪除時，自動重新計算該訂單的未稅總額、稅額與含稅總額
-- ※ Month01 不需要理解 Trigger 語法，只需知道「改了明細，訂單金額會自動更新」

CREATE OR REPLACE FUNCTION fn_recalculate_order_totals()
RETURNS TRIGGER AS $$
DECLARE
    target_order_id INT;
    v_subtotal NUMERIC(14, 2);
    v_tax_rate NUMERIC(4, 3);
    v_tax NUMERIC(14, 2);
BEGIN
    target_order_id := COALESCE(NEW.order_id, OLD.order_id);

    -- 取得該訂單的稅率設定
    SELECT tax_rate INTO v_tax_rate FROM orders WHERE order_id = target_order_id;
    IF v_tax_rate IS NULL THEN
        v_tax_rate := 0.050;
    END IF;

    -- 加總所有明細行的未稅小計
    SELECT COALESCE(SUM(subtotal), 0.00)
    INTO v_subtotal
    FROM order_items
    WHERE order_id = target_order_id;

    -- 計算稅額（四捨五入到小數第二位）
    v_tax := ROUND(v_subtotal * v_tax_rate, 2);

    -- 回寫訂單主表（自動滿足 CHECK: total = subtotal + tax）
    UPDATE orders
    SET subtotal_amount = v_subtotal,
        tax_amount = v_tax,
        total_amount = v_subtotal + v_tax
    WHERE order_id = target_order_id;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_order_totals
AFTER INSERT OR UPDATE OR DELETE ON order_items
FOR EACH ROW EXECUTE FUNCTION fn_recalculate_order_totals();


-- ============================================================================
-- ============================================================================
--                        測 試 資 料 (Mock Data)
-- ============================================================================
-- ============================================================================
-- 以下資料與 v1 (b2b_m1_sample.sql) 完全相同，
-- 確保 03 題庫 Q1~Q30 的預期查詢結果一致。
-- ============================================================================

-- ============================
-- 業務員資料（5 位）
-- ============================
INSERT INTO salespeople (employee_no, name, email, region, hire_date, monthly_target) VALUES
('EMP-001', 'Alex Chen',     'alex.c@company.com',    'North',   '2021-03-15', 600000),
('EMP-002', 'Betty Lin',     'betty.l@company.com',   'North',   '2022-01-10', 500000),
('EMP-003', 'Charlie Wang',  'charlie.w@company.com', 'Central', '2020-07-01', 700000),
('EMP-004', 'David Ho',      'david.h@company.com',   'South',   '2023-05-20', 400000),
('EMP-005', 'Eva Chang',     'eva.c@company.com',     'South',   '2024-02-01', 300000);

-- ============================
-- 客戶資料（10 家）
-- ============================
INSERT INTO customers (customer_code, company_name, tax_id, industry, city,
                       billing_address, payment_terms, credit_limit, salesperson_id, status) VALUES
('CUST-0001', 'Apex Semi Tech',      '28491023', 'Semiconductor', 'Hsinchu',
             '新竹市東區科學園路100號',   'NET_60',  1000000, 1, 'ACTIVE'),
('CUST-0002', 'BlueSky Cloud Ltd',   '54329871', 'Software',      'Taipei',
             '台北市信義區松高路1號',      'NET_30',  500000,  1, 'ACTIVE'),
('CUST-0003', 'CyberCore Inc',       '12984736', 'Hardware',      'New Taipei',
             '新北市中和區連城路200號',    'NET_30',  300000,  2, 'ACTIVE'),
('CUST-0004', 'Delta Logistics',     '98374612', 'Logistics',     'Taichung',
             '台中市西屯區台灣大道三段100號', 'NET_30', 400000, 3, 'ACTIVE'),
('CUST-0005', 'Echo Energy Corp',    '76451293', 'Energy',        'Kaohsiung',
             '高雄市前鎮區成功二路88號',   'NET_60',  800000,  4, 'ACTIVE'),
('CUST-0006', 'Future AI Labs',      '34567812', 'Software',      'Taipei',
             '台北市南港區三重路19-13號',  'NET_30',  600000,  2, 'ACTIVE'),
('CUST-0007', 'Grand Precision',     '65432198', 'Manufacturing', 'Taichung',
             '台中市大雅區科雅路25號',     'NET_30',  500000,  3, 'ACTIVE'),
('CUST-0008', 'Horizon BioTech',     '87654321', 'Medical',       'Taipei',
             '台北市內湖區瑞光路513巷22號', 'NET_30', 450000,  1, 'ACTIVE'),
('CUST-0009', 'InnoVibe Studio',     '23456789', 'Design',        'Tainan',
             '台南市東區裕農路500號',      'COD',     150000,  4, 'INACTIVE'),
('CUST-0010', 'Jovial Media Group',   NULL,       'Media',         'Taipei',
             '台北市中山區民生東路三段50號', 'NET_30', 100000,  2, 'SUSPENDED');

-- ============================
-- 產品資料（6 項）
-- ============================
INSERT INTO products (product_code, product_name, category, unit_price, cost_price, stock_quantity) VALUES
('SRV-001', 'Enterprise Server Pro',       'Hardware',  120000, 85000, 25),
('SRV-002', 'Edge Computing Node',         'Hardware',  45000,  30000, 50),
('SFT-001', 'Cloud CRM Enterprise (1-Yr)', 'Software',  60000,  10000, 999),
('SFT-002', 'Data Analytics Suite (1-Yr)', 'Software',  95000,  15000, 999),
('SEC-001', 'Firewall Appliance Gen4',     'Security',  35000,  22000, 40),
('SVC-001', '24/7 Priority SLA Support',   'Service',   50000,  20000, 999);

-- ============================
-- 訂單主表資料（13 筆）
-- ============================
-- ※ tax_rate 設為 0.000（免稅），使 total_amount 與 v1 的值完全一致。
--   若日後需要模擬含稅計算，只需將 tax_rate 改為 0.050 (5%)，
--   然後對任一 order_items 做一次 UPDATE（或 DELETE + INSERT）即可觸發重算。
--
-- ※ subtotal_amount / tax_amount / total_amount 不需手動填入，
--   當 order_items 插入後，Trigger 會自動計算回寫。

INSERT INTO orders (order_number, customer_id, salesperson_id, order_date,
                    snapshot_company_name, snapshot_tax_id, status, tax_rate) VALUES
('ORD-2024-001',  1, 1, '2024-01-15', 'Apex Semi Tech',    '28491023', 'COMPLETED', 0.000),
('ORD-2024-002',  2, 1, '2024-01-20', 'BlueSky Cloud Ltd', '54329871', 'COMPLETED', 0.000),
('ORD-2024-003',  4, 3, '2024-02-18', 'Delta Logistics',   '98374612', 'COMPLETED', 0.000),
('ORD-2024-004',  3, 2, '2024-02-05', 'CyberCore Inc',     '12984736', 'COMPLETED', 0.000),
('ORD-2024-005',  8, 5, '2024-02-25', 'Horizon BioTech',   '87654321', 'CANCELLED', 0.000),
('ORD-2024-006',  5, 4, '2024-03-22', 'Echo Energy Corp',  '76451293', 'COMPLETED', 0.000),
('ORD-2024-007',  1, 1, '2024-03-10', 'Apex Semi Tech',    '28491023', 'COMPLETED', 0.000),
('ORD-2024-008',  6, 2, '2024-04-02', 'Future AI Labs',    '34567812', 'COMPLETED', 0.000),
('ORD-2024-009',  7, 3, '2024-04-15', 'Grand Precision',   '65432198', 'COMPLETED', 0.000),
('ORD-2024-010',  2, 1, '2024-05-01', 'BlueSky Cloud Ltd', '54329871', 'COMPLETED', 0.000),
('ORD-2024-011',  8, 1, '2024-05-12', 'Horizon BioTech',   '87654321', 'COMPLETED', 0.000),
('ORD-2024-012',  1, 1, '2024-06-01', 'Apex Semi Tech',    '28491023', 'COMPLETED', 0.000),
('ORD-2024-013',  4, 3, '2024-06-15', 'Delta Logistics',   '98374612', 'CANCELLED', 0.000);

-- ============================
-- 訂單明細資料（18 筆）
-- ============================
-- ※ 不需要填入 subtotal / cost_subtotal / gross_profit，它們是 GENERATED COLUMN 會自動計算。
-- ※ 插入後 Trigger 會自動更新對應訂單的 subtotal_amount / tax_amount / total_amount。
--
-- 欄位說明：
--   order_id     → 所屬訂單
--   line_number  → 項次編號（同一訂單內不可重複）
--   product_id   → 購買的產品
--   quantity     → 數量
--   unit_price   → 成交單價（等同 v1 的 unit_price）
--   cost_price   → 成交當下的進貨成本快照（確保毛利計算不受日後調價影響）

INSERT INTO order_items (order_id, line_number, product_id, quantity, unit_price, cost_price) VALUES
-- 訂單 1：Apex Semi Tech（3 台伺服器）
(1,  1, 1, 3, 120000, 85000),
-- 訂單 2：BlueSky Cloud（CRM + 分析套件各 1）
(2,  1, 3, 1, 60000,  10000),
(2,  2, 4, 1, 95000,  15000),
-- 訂單 3：Delta Logistics（2 台伺服器）
(3,  1, 1, 2, 120000, 85000),
-- 訂單 4：CyberCore Inc（邊緣運算 + 防火牆各 1）
(4,  1, 2, 1, 45000,  30000),
(4,  2, 5, 1, 35000,  22000),
-- 訂單 5：Horizon BioTech（已取消，但明細仍保留以供稽核）
(5,  1, 3, 1, 60000,  10000),
-- 訂單 6：Echo Energy（分析套件 x2）
(6,  1, 4, 2, 95000,  15000),
-- 訂單 7：Apex Semi Tech（3 台伺服器 + 2 台邊緣運算）← Q20 答案：5 件
(7,  1, 1, 3, 120000, 85000),
(7,  2, 2, 2, 45000,  30000),
-- 訂單 8：Future AI Labs（CRM x1）
(8,  1, 3, 1, 60000,  10000),
-- 訂單 9：Grand Precision（邊緣運算 x3）
(9,  1, 2, 3, 45000,  30000),
-- 訂單 10：BlueSky Cloud（分析套件 x1）
(10, 1, 4, 1, 95000,  15000),
-- 訂單 11：Horizon BioTech（伺服器 + SLA 各 1）
(11, 1, 1, 1, 120000, 85000),
(11, 2, 6, 1, 50000,  20000),
-- 訂單 12：Apex Semi Tech（伺服器 x2 + SLA x1）
(12, 1, 1, 2, 120000, 85000),
(12, 2, 6, 1, 50000,  20000),
-- 訂單 13：Delta Logistics（已取消，伺服器 x1）
(13, 1, 1, 1, 120000, 85000);

-- ============================================================================
-- 🎉 資料匯入完成！
-- ============================================================================
-- 快速驗證指令（複製貼上到 DBeaver 執行）：
--
--   SELECT 'salespeople' AS table_name, COUNT(*) AS row_count FROM salespeople
--   UNION ALL
--   SELECT 'customers',   COUNT(*) FROM customers
--   UNION ALL
--   SELECT 'products',    COUNT(*) FROM products
--   UNION ALL
--   SELECT 'orders',      COUNT(*) FROM orders
--   UNION ALL
--   SELECT 'order_items', COUNT(*) FROM order_items;
--
-- 預期結果：salespeople=5, customers=10, products=6, orders=13, order_items=18
--
-- 驗證 Trigger 自動匯總是否正確：
--
--   SELECT order_id, order_number, subtotal_amount, tax_amount, total_amount
--   FROM orders ORDER BY order_id;
--
-- 預期：total_amount 應與 v1 的值一致（因 tax_rate = 0.000）
-- ============================================================================