-- ====================================================================
-- Project 1: 10,000+ 筆大型銷售資料庫架構與自動生成腳本
-- ====================================================================

DROP TABLE IF EXISTS proj1_order_items CASCADE;
DROP TABLE IF EXISTS proj1_orders CASCADE;
DROP TABLE IF EXISTS proj1_products CASCADE;
DROP TABLE IF EXISTS proj1_customers CASCADE;
DROP TABLE IF EXISTS proj1_salespeople CASCADE;

-- 1. 業務員表
CREATE TABLE proj1_salespeople (
    salesperson_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    region VARCHAR(30) NOT NULL,
    monthly_quota NUMERIC(12, 2) NOT NULL
);

INSERT INTO proj1_salespeople (name, region, monthly_quota) VALUES
('Ethan Hunt', 'North', 800000),
('Grace Chen', 'North', 750000),
('Hank Lin', 'Central', 600000),
('Iris Wu', 'Central', 550000),
('Jack Huang', 'South', 500000),
('Karen Lee', 'South', 450000);

-- 2. 客戶表 (產生 200 個 B2B 企業客戶)
CREATE TABLE proj1_customers (
    customer_id SERIAL PRIMARY KEY,
    company_name VARCHAR(100) NOT NULL,
    industry VARCHAR(50) NOT NULL,
    city VARCHAR(30) NOT NULL,
    salesperson_id INT REFERENCES proj1_salespeople(salesperson_id),
    registered_date DATE NOT NULL
);

INSERT INTO proj1_customers (company_name, industry, city, salesperson_id, registered_date)
SELECT 
    'Corp_' || LPAD(i::TEXT, 4, '0'),
    (ARRAY['Semiconductor', 'Software', 'Manufacturing', 'Finance', 'Logistics', 'BioTech'])[1 + (i % 6)],
    (ARRAY['Taipei', 'New Taipei', 'Hsinchu', 'Taichung', 'Tainan', 'Kaohsiung'])[1 + (i % 6)],
    1 + (i % 6),
    '2023-01-01'::DATE + (i * 3 || ' days')::INTERVAL
FROM generate_series(1, 200) AS i;

-- 3. 產品表 (10 項企業產品)
CREATE TABLE proj1_products (
    product_id SERIAL PRIMARY KEY,
    product_code VARCHAR(30) UNIQUE NOT NULL,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    unit_price NUMERIC(10, 2) NOT NULL,
    unit_cost NUMERIC(10, 2) NOT NULL
);

INSERT INTO proj1_products (product_code, product_name, category, unit_price, unit_cost) VALUES
('SRV-100', 'Cloud Rack Server', 'Hardware', 150000, 100000),
('SRV-200', 'Storage Array SAN', 'Hardware', 280000, 190000),
('NET-100', 'Core Switch 100G', 'Network', 80000, 48000),
('NET-200', 'Enterprise Gateway', 'Network', 45000, 26000),
('SFT-100', 'ERP Subscription (1-Yr)', 'Software', 120000, 20000),
('SFT-200', 'BI Dashboard Platform', 'Software', 90000, 15000),
('SFT-300', 'Security Endpoint Pro', 'Software', 35000, 5000),
('SVC-100', 'Consulting & Implementation', 'Service', 200000, 80000),
('SVC-200', 'Annual Maintenance 24/7', 'Service', 60000, 25000),
('SVC-300', 'Cloud Migration Service', 'Service', 180000, 70000);

-- 4. 訂單主表 (生成 10,000+ 筆歷史訂單，跨 2023-01 至 2024-12)
CREATE TABLE proj1_orders (
    order_id SERIAL PRIMARY KEY,
    order_number VARCHAR(30) UNIQUE NOT NULL,
    customer_id INT NOT NULL REFERENCES proj1_customers(customer_id),
    salesperson_id INT NOT NULL REFERENCES proj1_salespeople(salesperson_id),
    order_date DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'COMPLETED',
    total_amount NUMERIC(12, 2) DEFAULT 0
);

INSERT INTO proj1_orders (order_number, customer_id, salesperson_id, order_date, status, total_amount)
SELECT 
    'ORD-' || TO_CHAR(20230000 + i, 'FM99999999'),
    1 + (i % 200),
    1 + (i % 6),
    '2023-01-01'::DATE + ((i * 17) % 700 || ' days')::INTERVAL,
    CASE WHEN i % 25 = 0 THEN 'CANCELLED' ELSE 'COMPLETED' END,
    0
FROM generate_series(1, 10500) AS i;

-- 5. 訂單明細表 (每筆訂單隨機掛 1~3 項產品，累計 20,000+ 筆明細)
CREATE TABLE proj1_order_items (
    item_id SERIAL PRIMARY KEY,
    order_id INT NOT NULL REFERENCES proj1_orders(order_id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES proj1_products(product_id),
    quantity INT NOT NULL,
    unit_price NUMERIC(10, 2) NOT NULL,
    subtotal NUMERIC(12, 2) NOT NULL
);

INSERT INTO proj1_order_items (order_id, product_id, quantity, unit_price, subtotal)
SELECT 
    o.order_id,
    p.product_id,
    1 + (o.order_id % 4),
    p.unit_price,
    (1 + (o.order_id % 4)) * p.unit_price
FROM proj1_orders o
JOIN proj1_products p ON p.product_id = 1 + (o.order_id % 10);

-- 回寫計算訂單總額
UPDATE proj1_orders o
SET total_amount = sub.calc_total
FROM (
    SELECT order_id, SUM(subtotal) AS calc_total
    FROM proj1_order_items
    GROUP BY order_id
) sub
WHERE o.order_id = sub.order_id;

-- 建立常用索引以加速分析查詢
CREATE INDEX idx_proj1_orders_date ON proj1_orders(order_date);
CREATE INDEX idx_proj1_orders_cust ON proj1_orders(customer_id);
CREATE INDEX idx_proj1_orders_sales ON proj1_orders(salesperson_id);
CREATE INDEX idx_proj1_items_order ON proj1_order_items(order_id);
CREATE INDEX idx_proj1_items_prod ON proj1_order_items(product_id);
