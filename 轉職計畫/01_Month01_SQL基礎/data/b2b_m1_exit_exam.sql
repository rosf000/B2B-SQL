-- ====================================================================
-- Month 01 Exit Exam: B2B 商業數據偵探考題專屬資料庫初始化腳本
-- 適用資料庫：PostgreSQL 14 / 15 / 16 / 17 / 18
--
-- 💡 【新手執行必讀】：
--   本腳本負責建立結業考所需之「資料表與資料」（Table & Data）。
--   【方案 A（強烈推薦：獨立資料庫）】：
--     若想保留 01~09 單元的練習資料，請先在 DBeaver 左側「資料庫 (Databases)」
--     按右鍵 ➜ 點選「建立新資料庫 (Create New Database)」➜ 名稱填「b2b_exit_exam」。
--     建立完成後，在「b2b_exit_exam」上按右鍵 ➜「SQL 編輯器」➜「新增 SQL 腳本」，
--     貼上本腳本並按【Alt + X】整份執行即可！
--
--   【方案 B（覆蓋現有 postgres 資料庫）】：
--     若不需要保留舊練習資料，可直接在預設的 postgres 連線上開編輯器執行本腳本。
--
-- 包含：
--   1. 客戶主表 (customers)
--   2. 業務代表表 (sales_reps)
--   3. 產品表 (products)
--   4. 訂單主表 (orders)
--   5. 訂單明細表 (order_items)
--   6. 相容性視圖 (salespeople 雙向支援)
-- ====================================================================

-- 1. 清理舊表 (若存在)
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS sales_reps CASCADE;
DROP VIEW IF EXISTS salespeople CASCADE;

-- 2. 建立業務代表表 (sales_reps)
CREATE TABLE sales_reps (
    rep_id SERIAL PRIMARY KEY,
    rep_name VARCHAR(50) NOT NULL,
    region VARCHAR(30) NOT NULL CHECK (region IN ('North', 'Central', 'South'))
);

-- 3. 建立客戶主表 (customers)
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    company_name VARCHAR(100) NOT NULL,
    industry VARCHAR(50) NOT NULL,
    city VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. 建立產品表 (products)
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    unit_price NUMERIC(12, 2) NOT NULL
);

-- 5. 建立訂單主表 (orders)
CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(customer_id),
    rep_id INT NOT NULL REFERENCES sales_reps(rep_id),
    order_date DATE NOT NULL,
    total_amount NUMERIC(12, 2) NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('Completed', 'Cancelled', 'Refunded'))
);

-- 6. 建立訂單明細表 (order_items)
CREATE TABLE order_items (
    item_id SERIAL PRIMARY KEY,
    order_id INT NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES products(product_id),
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(12, 2) NOT NULL,
    subtotal NUMERIC(12, 2) NOT NULL
);

-- 建立與 salespeople 的相容視圖 (確保其他講義語法亦可運行)
CREATE OR REPLACE VIEW salespeople AS
SELECT 
    rep_id AS salesperson_id,
    rep_name AS name,
    region
FROM sales_reps;

-- ====================================================================
-- 插入測驗測試資料 (Exit Exam Mock Data)
-- ====================================================================

-- 業務代表 (共 5 位，包含 1 位尚無任何成交訂單的新人 Evan Lin)
INSERT INTO sales_reps (rep_id, rep_name, region) VALUES
(1, 'Alice Wang', 'North'),
(2, 'Bob Chen', 'Central'),
(3, 'Charlie Lee', 'South'),
(4, 'Diana Chang', 'North'),
(5, 'Evan Lin', 'Central');

-- 客戶資料 (共 12 家 B2B 客戶，分佈不同產業與城市)
INSERT INTO customers (customer_id, company_name, industry, city, created_at) VALUES
(1,  'Apex Semi Tech',      'Manufacturing', 'Hsinchu',    '2023-01-10 09:30:00'),
(2,  'BlueSky Cloud Ltd',   'SaaS',          'Taipei',     '2023-02-15 14:20:00'),
(3,  'CyberCore Logistics', 'Logistics',     'Taichung',   '2023-03-01 11:00:00'),
(4,  'Delta Retail Group',  'Retail',        'Taipei',     '2023-04-12 16:45:00'),
(5,  'Echo Energy Corp',    'Manufacturing', 'Kaohsiung',  '2023-05-20 10:15:00'),
(6,  'Frontier AI Studio',  'SaaS',          'Taipei',     '2023-06-08 13:00:00'),
(7,  'Grand Harbor Mart',   'Retail',        'Kaohsiung',  '2023-07-14 15:30:00'),
(8,  'HyperScale BioMed',   'Healthcare',    'New Taipei', '2023-08-22 09:00:00'),
(9,  'InnoVision Sensor',   'Manufacturing', 'Tainan',     '2023-09-18 17:10:00'),
(10, 'Jupiter SaaS Hub',    'SaaS',          'Taipei',     '2023-10-05 12:00:00'),
(11, 'Kingston Chain Store','Retail',        'Taichung',   '2023-11-12 14:00:00'),
(12, 'Lunar Dynamics',      'Logistics',     'Hsinchu',    '2023-12-01 10:00:00');

-- 產品資料 (共 8 項產品，包含 1 項未有任何明細、1 項僅出現在取消訂單的滯銷品)
INSERT INTO products (product_id, product_name, category, unit_price) VALUES
(1, 'Enterprise Rack Server X1', 'Hardware', 120000.00),
(2, 'Edge AI Computing Node',    'Hardware',  45000.00),
(3, 'Cloud CRM Platform (1-Yr)', 'Software',  60000.00),
(4, 'BI Analytics Suite (1-Yr)', 'Software',  95000.00),
(5, 'NextGen Firewall Gateway',  'Security',  35000.00),
(6, '24/7 Priority SLA Service', 'Service',   50000.00),
(7, 'Quantum Security Key Dongle','Security', 28000.00), -- 從未被任何訂單購買
(8, 'Legacy Tape Backup Unit',   'Hardware',  60000.00); -- 僅在 Cancelled 訂單中出現

-- 訂單資料 (基準日：2024-03-31)
-- 涵蓋：歷史完成訂單、2024年3月當期訂單、取消訂單、退款訂單、沉睡客戶訂單
INSERT INTO orders (order_id, customer_id, rep_id, order_date, total_amount, status) VALUES
-- 歷史訂單：沉睡客戶 (最後下單距 2024-03-31 超過 90 天)
(1,  6, 4, '2023-11-15',  60000.00, 'Completed'), -- Frontier AI: 沉睡 137 天
(2,  7, 3, '2023-12-10', 120000.00, 'Completed'), -- Grand Harbor: 沉睡 112 天
(3,  8, 1, '2023-12-28', 190000.00, 'Completed'), -- HyperScale: 沉睡 94 天

-- 歷史訂單：活躍客戶 (2024 年 1~2 月下單)
(4,  1, 1, '2024-01-10', 360000.00, 'Completed'),
(5,  2, 2, '2024-01-18', 155000.00, 'Completed'),
(6,  3, 3, '2024-01-25', 105000.00, 'Completed'),
(7,  9, 2, '2024-02-05', 140000.00, 'Completed'),
(8, 10, 4, '2024-02-12',  95000.00, 'Completed'),
(9, 11, 2, '2024-02-20', 210000.00, 'Completed'),
(10, 4, 1, '2024-02-26', 170000.00, 'Completed'),

-- 2024 年 3 月當期訂單 (題目 1 檢測焦點)
(11, 1, 1, '2024-03-05', 180000.00, 'Completed'),
(12, 2, 2, '2024-03-12', 340000.00, 'Completed'),
(13, 5, 3, '2024-03-25', 215000.00, 'Completed'),
(14, 4, 1, '2024-03-18',  95000.00, 'Cancelled'), -- 3月份取消損失
(15, 3, 2, '2024-03-22', 120000.00, 'Refunded'),  -- 3月份退款損失

-- 非3月份異常訂單 (僅出現在 Cancelled 訂單中的產品測試)
(16, 12, 3, '2024-01-15', 60000.00, 'Cancelled');

-- 訂單明細資料 (order_items)
INSERT INTO order_items (item_id, order_id, product_id, quantity, unit_price, subtotal) VALUES
-- Order 1: 60,000 (Product 3)
(1,  1,  3, 1,  60000.00,  60000.00),
-- Order 2: 120,000 (Product 1)
(2,  2,  1, 1, 120000.00, 120000.00),
-- Order 3: 190,000 (Product 4 x 2)
(3,  3,  4, 2,  95000.00, 190000.00),
-- Order 4: 360,000 (Product 1 x 3)
(4,  4,  1, 3, 120000.00, 360000.00),
-- Order 5: 155,000 (Product 3 x 1 + Product 4 x 1)
(5,  5,  3, 1,  60000.00,  60000.00),
(6,  5,  4, 1,  95000.00,  95000.00),
-- Order 6: 105,000 (Product 5 x 3)
(7,  6,  5, 3,  35000.00, 105000.00),
-- Order 7: 140,000 (Product 2 x 2 + Product 6 x 1)
(8,  7,  2, 2,  45000.00,  90000.00),
(9,  7,  6, 1,  50000.00,  50000.00),
-- Order 8: 95,000 (Product 4 x 1)
(10, 8,  4, 1,  95000.00,  95000.00),
-- Order 9: 210,000 (Product 5 x 6)
(11, 9,  5, 6,  35000.00, 210000.00),
-- Order 10: 170,000 (Product 1 x 1 + Product 6 x 1)
(12, 10, 1, 1, 120000.00, 120000.00),
(13, 10, 6, 1,  50000.00,  50000.00),
-- Order 11: 180,000 (Product 3 x 3)
(14, 11, 3, 3,  60000.00, 180000.00),
-- Order 12: 340,000 (Product 1 x 2 + Product 6 x 2)
(15, 12, 1, 2, 120000.00, 240000.00),
(16, 12, 6, 2,  50000.00, 100000.00),
-- Order 13: 215,000 (Product 2 x 1 + Product 3 x 1 + Product 4 x 1 + Product 5 x 1)
(17, 13, 2, 1,  45000.00,  45000.00),
(18, 13, 3, 1,  60000.00,  60000.00),
(19, 13, 4, 1,  95000.00,  95000.00),
(20, 13, 5, 1,  35000.00,  35000.00),
-- Order 14: 95,000 (Cancelled)
(21, 14, 4, 1,  95000.00,  95000.00),
-- Order 15: 120,000 (Refunded)
(22, 15, 1, 1, 120000.00, 120000.00),
-- Order 16: 60,000 (Cancelled, 產品 8 唯一出處)
(23, 16, 8, 1,  60000.00,  60000.00);

-- 重置各表的序列自增號碼 (確保後續手動 INSERT 時不會產生主鍵衝突)
SELECT setval(pg_get_serial_sequence('sales_reps', 'rep_id'), COALESCE((SELECT MAX(rep_id) FROM sales_reps), 1));
SELECT setval(pg_get_serial_sequence('customers', 'customer_id'), COALESCE((SELECT MAX(customer_id) FROM customers), 1));
SELECT setval(pg_get_serial_sequence('products', 'product_id'), COALESCE((SELECT MAX(product_id) FROM products), 1));
SELECT setval(pg_get_serial_sequence('orders', 'order_id'), COALESCE((SELECT MAX(order_id) FROM orders), 1));
SELECT setval(pg_get_serial_sequence('order_items', 'item_id'), COALESCE((SELECT MAX(item_id) FROM order_items), 1));

