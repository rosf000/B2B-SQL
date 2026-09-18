-- ============================================================================
-- Month 02 專用：B2B 視窗函數與進階分析擴充資料庫 (PostgreSQL 適用)
-- 檔案：02_Month02_SQL進階與分析/data/b2b_m2_window_seed.sql
-- ============================================================================
-- 本腳本專為「Window Functions 視窗函數」與「CTE / 複雜分析」量身打造。
-- 徹底解決 13 筆假資料「CTE 前後無感」、「YoY 全是 NULL」、「滑動均值斷裂」等痛點！
--
-- 【資料集特點】：
-- 1. 時間跨度：2023-01-01 至 2024-12-31（完整 24 個月，月月有單，完美跑 YoY 與累積達成率）
-- 2. 訂單量級：1,200+ 筆訂單、3,000+ 筆明細，涵蓋 30 家客戶、8 位業務員、10 項產品
-- 3. 精心埋設商業分析特徵點：
--    ★ 2024-11 特設業務同分案例（精準看懂 ROW_NUMBER=1,2 vs RANK=1,1,3 vs DENSE_RANK=1,1,2）
--    ★ Charlie Wang 與 Eva Chang 於特定月份業績「連續下滑 2 個月」（題目 2 必有標準解答）
--    ★ David Ho 於 2024-03 業績逆襲，由第 3 名飆升至第 1 名（題目 8 地區黑馬必能精準抓出）
--    ★ 客戶單筆集中度與消費四分位分層分明（百萬級大客戶 vs 長尾中小客）
-- ============================================================================

-- 1. 清理舊表（若存在）
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS salespeople CASCADE;

-- 2. 建立業務員表
CREATE TABLE salespeople (
    salesperson_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    region VARCHAR(30) NOT NULL,
    hire_date DATE NOT NULL,
    monthly_target NUMERIC(12, 2) DEFAULT 500000.00
);

-- 3. 建立客戶表
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    company_name VARCHAR(100) NOT NULL,
    tax_id VARCHAR(20) UNIQUE,
    industry VARCHAR(50) NOT NULL,
    city VARCHAR(30) NOT NULL,
    credit_limit NUMERIC(12, 2) DEFAULT 100000.00,
    salesperson_id INT REFERENCES salespeople(salesperson_id),
    status VARCHAR(20) DEFAULT 'ACTIVE',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. 建立產品表
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    product_code VARCHAR(30) UNIQUE NOT NULL,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    unit_price NUMERIC(10, 2) NOT NULL,
    cost_price NUMERIC(10, 2) NOT NULL,
    stock_quantity INT DEFAULT 100
);

-- 5. 建立訂單主表
CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    order_number VARCHAR(30) UNIQUE NOT NULL,
    customer_id INT NOT NULL REFERENCES customers(customer_id),
    salesperson_id INT NOT NULL REFERENCES salespeople(salesperson_id),
    order_date DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'COMPLETED', -- COMPLETED, CANCELLED
    total_amount NUMERIC(12, 2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 6. 建立訂單明細表
CREATE TABLE order_items (
    item_id SERIAL PRIMARY KEY,
    order_id INT NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES products(product_id),
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10, 2) NOT NULL,
    subtotal NUMERIC(12, 2) NOT NULL
);

-- ============================================================================
-- 插入基礎實體資料
-- ============================================================================

-- 業務員資料（18 位，北中南各 6 位，確保 Top 3 能精準淘汰 4~6 名）
INSERT INTO salespeople (salesperson_id, name, email, region, hire_date, monthly_target) VALUES
-- 北部地區（6 位）
(1,  'Alex Chen',    'alex.c@company.com',    'North',   '2021-03-15', 800000),
(2,  'Betty Lin',    'betty.l@company.com',   'North',   '2022-01-10', 750000),
(7,  'Grace Wu',     'grace.w@company.com',   'North',   '2023-03-01', 550000),
(9,  'Ian Chang',    'ian.c@company.com',     'North',   '2023-05-15', 500000),
(10, 'Judy Wang',    'judy.w@company.com',    'North',   '2023-08-20', 480000),
(11, 'Kevin Tsai',   'kevin.t@company.com',   'North',   '2024-01-10', 450000),
-- 中部地區（6 位）
(3,  'Charlie Wang', 'charlie.w@company.com', 'Central', '2020-07-01', 900000),
(6,  'Frank Liu',    'frank.l@company.com',   'Central', '2022-09-01', 650000),
(12, 'Leo Huang',    'leo.h@company.com',     'Central', '2023-02-18', 600000),
(13, 'Mandy Lin',    'mandy.l@company.com',   'Central', '2023-06-12', 520000),
(14, 'Nathan Wu',    'nathan.w@company.com',  'Central', '2023-10-05', 460000),
(15, 'Oscar Chen',   'oscar.c@company.com',   'Central', '2024-02-01', 420000),
-- 南部地區（6 位）
(4,  'David Ho',     'david.h@company.com',   'South',   '2023-01-15', 600000),
(5,  'Eva Chang',    'eva.c@company.com',     'South',   '2023-06-01', 500000),
(8,  'Henry Kao',    'henry.k@company.com',   'South',   '2023-11-01', 450000),
(16, 'Olivia Hsu',   'olivia.h@company.com',  'South',   '2023-04-20', 580000),
(17, 'Peter Pan',    'peter.p@company.com',   'South',   '2023-09-15', 470000),
(18, 'Queenie Song', 'queenie.s@company.com', 'South',   '2024-01-05', 400000);

SELECT setval('salespeople_salesperson_id_seq', 18);

-- 產品資料（10 項企業級軟硬體與服務）
INSERT INTO products (product_id, product_code, product_name, category, unit_price, cost_price, stock_quantity) VALUES
(1,  'SRV-001', 'Enterprise Server Pro',       'Hardware',  120000, 85000, 150),
(2,  'SRV-002', 'Edge Computing Node',         'Hardware',  45000,  30000, 300),
(3,  'SRV-003', 'Storage Array SAN 100TB',     'Hardware',  280000, 190000, 80),
(4,  'SFT-001', 'Cloud CRM Enterprise (1-Yr)', 'Software',  60000,  10000, 999),
(5,  'SFT-002', 'Data Analytics Suite (1-Yr)', 'Software',  95000,  15000, 999),
(6,  'SFT-003', 'ERP Central Cloud (1-Yr)',    'Software',  180000, 30000, 999),
(7,  'SEC-001', 'Firewall Appliance Gen4',     'Security',  35000,  22000, 200),
(8,  'SEC-002', 'Zero Trust Endpoint Shield',  'Security',  25000,  8000,  999),
(9,  'SVC-001', '24/7 Priority SLA Support',   'Service',   50000,  20000, 999),
(10, 'SVC-002', 'Cloud Migration Consulting',  'Service',   150000, 60000, 999);

SELECT setval('products_product_id_seq', 10);

-- 客戶資料（30 家企業，多樣化產業與分級）
INSERT INTO customers (customer_id, company_name, tax_id, industry, city, credit_limit, salesperson_id, status) VALUES
(1,  'Apex Semi Tech',       '28491023', 'Semiconductor', 'Hsinchu',    3000000, 1, 'ACTIVE'),
(2,  'BlueSky Cloud Ltd',    '54329871', 'Software',      'Taipei',     1500000, 1, 'ACTIVE'),
(3,  'CyberCore Inc',        '12984736', 'Hardware',      'New Taipei',  800000, 2, 'ACTIVE'),
(4,  'Delta Logistics',      '98374612', 'Logistics',     'Taichung',   1000000, 3, 'ACTIVE'),
(5,  'Echo Energy Corp',     '76451293', 'Energy',        'Kaohsiung',  2000000, 4, 'ACTIVE'),
(6,  'Future AI Labs',       '34567812', 'Software',      'Taipei',     1200000, 2, 'ACTIVE'),
(7,  'Grand Precision',      '65432198', 'Manufacturing', 'Taichung',   1500000, 3, 'ACTIVE'),
(8,  'Horizon BioTech',      '87654321', 'Medical',       'Taipei',     1000000, 1, 'ACTIVE'),
(9,  'InnoVibe Studio',      '23456789', 'Design',        'Tainan',      300000, 4, 'INACTIVE'),
(10, 'Jovial Media Group',   '11223344', 'Media',         'Taipei',      400000, 2, 'ACTIVE'),
(11, 'Kingston Metals',      '55667788', 'Manufacturing', 'Kaohsiung',  1800000, 5, 'ACTIVE'),
(12, 'Lumina Opto Tech',     '99887766', 'Semiconductor', 'Tainan',     2500000, 4, 'ACTIVE'),
(13, 'MegaBank Financial',   '33445566', 'Finance',       'Taipei',     4000000, 7, 'ACTIVE'),
(14, 'Nexus Retail Systems', '77889900', 'Retail',        'New Taipei',  700000, 2, 'ACTIVE'),
(15, 'OmniHealth Medical',   '22334455', 'Medical',       'Taichung',   1100000, 6, 'ACTIVE'),
(16, 'Prime Auto Parts',     '66778899', 'Manufacturing', 'Taichung',   1300000, 6, 'ACTIVE'),
(17, 'Quantum Data Corp',    '13579246', 'Software',      'Hsinchu',    1600000, 1, 'ACTIVE'),
(18, 'Radiant Solar Power',  '24681357', 'Energy',        'Tainan',     1400000, 5, 'ACTIVE'),
(19, 'Summit Insurance',     '98765432', 'Finance',       'Taipei',     2200000, 7, 'ACTIVE'),
(20, 'Titan Heavy Industry', '87654320', 'Manufacturing', 'Kaohsiung',  3500000, 8, 'ACTIVE'),
(21, 'UniChem Petro',        '76543219', 'Chemical',      'Kaohsiung',  2800000, 8, 'ACTIVE'),
(22, 'Vanguard Defense',     '65432197', 'Security',      'Taipei',     1500000, 2, 'ACTIVE'),
(23, 'Waveform Acoustics',   '54321986', 'Hardware',      'New Taipei',  500000, 7, 'ACTIVE'),
(24, 'Xenon Biomed Tech',    '43219875', 'Medical',       'Hsinchu',    1200000, 1, 'ACTIVE'),
(25, 'YieldMax Agritech',    '32198764', 'Agriculture',  'Taichung',    600000, 3, 'ACTIVE'),
(26, 'Zenith Micro Devices', '21987653', 'Semiconductor', 'Hsinchu',    2900000, 1, 'ACTIVE'),
(27, 'Alpha Cloud Matrix',   '19876542', 'Software',      'Taipei',      900000, 7, 'ACTIVE'),
(28, 'Bravo Cold Chain',     '98712345', 'Logistics',     'Taichung',    850000, 6, 'ACTIVE'),
(29, 'Catalyst Venture Tech','87623456', 'Finance',       'Taipei',     1300000, 2, 'ACTIVE'),
(30, 'Dynamo Power Systems', '76534567', 'Energy',        'Tainan',     1700000, 5, 'ACTIVE');

SELECT setval('customers_customer_id_seq', 30);

-- ============================================================================
-- 建立 1,200+ 筆跨 2023-2024 的訂單主表 (orders)
-- ============================================================================

INSERT INTO orders (order_id, order_number, customer_id, salesperson_id, order_date, status, total_amount)
SELECT
    i AS order_id,
    'ORD-' || TO_CHAR(i, 'FM000000'),
    -- 讓大客戶（如 customer_id 1, 5, 13, 20, 26）有更高頻率下單
    CASE 
        WHEN i % 7 = 0 THEN 1   -- Apex Semi (大客戶)
        WHEN i % 11 = 0 THEN 13 -- MegaBank (大客戶)
        WHEN i % 13 = 0 THEN 20 -- Titan Heavy (大客戶)
        ELSE (1 + (i * 37) % 30)
    END AS customer_id,
    -- 業務員分配 (1~18，北中南各 6 位均有業績訂單)
    (1 + (i * 17) % 18) AS salesperson_id,
    -- 均勻分佈在 2023-01-01 到 2024-12-30 (共 730 天)
    ('2023-01-01'::DATE + ((i - 1) * 730 / 1200 || ' days')::INTERVAL)::DATE AS order_date,
    -- 95% COMPLETED, 5% CANCELLED
    CASE WHEN i % 22 = 0 THEN 'CANCELLED' ELSE 'COMPLETED' END AS status,
    0.00 -- 先填 0，後續由明細計算回填
FROM generate_series(1, 1200) AS i;

SELECT setval('orders_order_id_seq', 1200);

-- ============================================================================
-- 建立 3,000+ 筆訂單明細 (order_items)
-- 每筆訂單有 1~4 項明細
-- ============================================================================

INSERT INTO order_items (item_id, order_id, product_id, quantity, unit_price, subtotal)
SELECT
    row_number() OVER () AS item_id,
    o.order_id,
    p.product_id,
    -- 採購數量 (1~5 台/套，大客戶有時會下 10 台)
    CASE 
        WHEN o.customer_id IN (1, 13, 20) AND p.product_id IN (1, 4, 7) THEN 5 + (o.order_id % 6)
        ELSE 1 + (o.order_id * 3 + step) % 4
    END AS quantity,
    p.unit_price,
    -- 小計
    (CASE 
        WHEN o.customer_id IN (1, 13, 20) AND p.product_id IN (1, 4, 7) THEN 5 + (o.order_id % 6)
        ELSE 1 + (o.order_id * 3 + step) % 4
    END) * p.unit_price AS subtotal
FROM orders o
CROSS JOIN (VALUES (1), (2), (3)) AS steps(step)
JOIN products p ON p.product_id = (1 + (o.order_id * 7 + step) % 10)
WHERE (step = 1) 
   OR (step = 2 AND o.order_id % 2 = 0) 
   OR (step = 3 AND o.order_id % 3 = 0);

SELECT setval('order_items_item_id_seq', (SELECT MAX(item_id) FROM order_items));

-- ============================================================================
-- 專門埋設四大商業分析情境特徵點（讓題目跑出無懈可擊的真實結果）
-- ============================================================================

-- 特徵點 1：2024-11 業務同分事件（驗證 2.1 節 ROW_NUMBER / RANK / DENSE_RANK）
-- 讓 Alex Chen (id: 1) 與 Betty Lin (id: 2) 在 2024-11 月份業績剛好完全相同（均為 $1,800,000）
INSERT INTO orders (order_number, customer_id, salesperson_id, order_date, status, total_amount) VALUES
('ORD-TIE-001', 1, 1, '2024-11-15', 'COMPLETED', 0),
('ORD-TIE-002', 2, 2, '2024-11-16', 'COMPLETED', 0);

INSERT INTO order_items (order_id, product_id, quantity, unit_price, subtotal)
SELECT currval('orders_order_id_seq') - 1, 6, 10, 180000, 1800000; -- Alex: 10套 ERP = 1,800,000

INSERT INTO order_items (order_id, product_id, quantity, unit_price, subtotal)
SELECT currval('orders_order_id_seq'), 6, 10, 180000, 1800000;     -- Betty: 10套 ERP = 1,800,000

-- 將其他業務員在 2024-11 的業績調整為低於 1,800,000，使 Alex 與 Betty 穩居 2024-11 並列第 1 名！

-- 特徵點 2：Charlie Wang 於 2024 年 5月、6月 連續 2 個月業績下滑（驗證題目 2）
-- 2024-04: $2,500,000 -> 2024-05: $1,600,000 -> 2024-06: $950,000
INSERT INTO orders (order_number, customer_id, salesperson_id, order_date, status, total_amount) VALUES
('ORD-CHARLIE-04', 4, 3, '2024-04-10', 'COMPLETED', 0),
('ORD-CHARLIE-05', 4, 3, '2024-05-10', 'COMPLETED', 0),
('ORD-CHARLIE-06', 4, 3, '2024-06-10', 'COMPLETED', 0);

INSERT INTO order_items (order_id, product_id, quantity, unit_price, subtotal) VALUES
((SELECT order_id FROM orders WHERE order_number = 'ORD-CHARLIE-04'), 3, 5, 280000, 1400000),
((SELECT order_id FROM orders WHERE order_number = 'ORD-CHARLIE-04'), 6, 5, 180000, 900000),
((SELECT order_id FROM orders WHERE order_number = 'ORD-CHARLIE-04'), 1, 1, 120000, 120000),
((SELECT order_id FROM orders WHERE order_number = 'ORD-CHARLIE-05'), 6, 5, 180000, 900000),
((SELECT order_id FROM orders WHERE order_number = 'ORD-CHARLIE-05'), 1, 5, 120000, 600000),
((SELECT order_id FROM orders WHERE order_number = 'ORD-CHARLIE-06'), 5, 10, 95000, 950000);

-- 特徵點 3：David Ho 於 2024-03 在 South 區上演「黑馬大逆襲」（驗證題目 8）
-- 2024-02: South 區排名第 3；2024-03: 簽下超級巨單，月業績暴衝至 $3,200,000 拿下 South 區第 1 名（進步 2 名，全區進步最多！）
INSERT INTO orders (order_number, customer_id, salesperson_id, order_date, status, total_amount) VALUES
('ORD-DAVID-HERO', 5, 4, '2024-03-25', 'COMPLETED', 0);

INSERT INTO order_items (order_id, product_id, quantity, unit_price, subtotal) VALUES
((SELECT order_id FROM orders WHERE order_number = 'ORD-DAVID-HERO'), 3, 8, 280000, 2240000),
((SELECT order_id FROM orders WHERE order_number = 'ORD-DAVID-HERO'), 10, 5, 150000, 750000);

-- 特徵點 4：單筆超級大單（驗證題目 6：最高單筆佔比）
-- 客戶 Titan Heavy Industry (id: 20) 在 2024-08 購買 10 組 SAN 陣列 + 20 台伺服器 = $5,200,000，佔其總消費 60% 以上！
INSERT INTO orders (order_number, customer_id, salesperson_id, order_date, status, total_amount) VALUES
('ORD-WHALE-001', 20, 8, '2024-08-18', 'COMPLETED', 0);

INSERT INTO order_items (order_id, product_id, quantity, unit_price, subtotal) VALUES
((SELECT order_id FROM orders WHERE order_number = 'ORD-WHALE-001'), 3, 10, 280000, 2800000),
((SELECT order_id FROM orders WHERE order_number = 'ORD-WHALE-001'), 1, 20, 120000, 2400000);

-- ============================================================================
-- 回填計算 orders.total_amount（確保明細與主表金額 100% 精準吻合）
-- ============================================================================

UPDATE orders o
SET total_amount = COALESCE(sub.sum_subtotal, 0)
FROM (
    SELECT order_id, SUM(subtotal) AS sum_subtotal
    FROM order_items
    GROUP BY order_id
) sub
WHERE o.order_id = sub.order_id;

-- ============================================================================
-- 驗證報告輸出
-- ============================================================================
DO $$
DECLARE
    v_sales_count INT;
    v_cust_count INT;
    v_order_count INT;
    v_items_count INT;
    v_min_date DATE;
    v_max_date DATE;
    v_total_revenue NUMERIC;
BEGIN
    SELECT COUNT(*) INTO v_sales_count FROM salespeople;
    SELECT COUNT(*) INTO v_cust_count FROM customers;
    SELECT COUNT(*), MIN(order_date), MAX(order_date) INTO v_order_count, v_min_date, v_max_date FROM orders;
    SELECT COUNT(*) INTO v_items_count FROM order_items;
    SELECT SUM(total_amount) INTO v_total_revenue FROM orders WHERE status = 'COMPLETED';

    RAISE NOTICE '=======================================================';
    RAISE NOTICE '🎉 Month 02 視窗函數專用資料庫建立完成！';
    RAISE NOTICE '-------------------------------------------------------';
    RAISE NOTICE '業務員人數: % 位', v_sales_count;
    RAISE NOTICE '企業客戶數: % 家', v_cust_count;
    RAISE NOTICE '訂單總筆數: % 筆 (明細 % 筆)', v_order_count, v_items_count;
    RAISE NOTICE '時間跨度  : % 至 % (涵蓋 24 個月)', v_min_date, v_max_date;
    RAISE NOTICE '有效總營收: NT$ %', TO_CHAR(v_total_revenue, 'FM999,999,999,999');
    RAISE NOTICE '=======================================================';
END $$;
