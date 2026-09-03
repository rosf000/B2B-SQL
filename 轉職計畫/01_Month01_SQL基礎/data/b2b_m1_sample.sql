-- ====================================================================
-- Month 01: B2B 模擬資料集初始化腳本 (PostgreSQL 適用)
-- 包含：業務員 (salespeople)、客戶 (customers)、產品 (products)、
--       訂單 (orders)、訂單明細 (order_items)
-- ====================================================================

-- 1. 清理舊表 (若存在)
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
    industry VARCHAR(50),
    city VARCHAR(30),
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
    stock_quantity INT DEFAULT 0
);

-- 5. 建立訂單主表
CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    order_number VARCHAR(30) UNIQUE NOT NULL,
    customer_id INT NOT NULL REFERENCES customers(customer_id),
    salesperson_id INT NOT NULL REFERENCES salespeople(salesperson_id),
    order_date DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'COMPLETED', -- PENDING, COMPLETED, CANCELLED
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

-- ====================================================================
-- 插入測試資料 (Mock Data)
-- ====================================================================

-- 業務員資料
INSERT INTO salespeople (name, email, region, hire_date, monthly_target) VALUES
('Alex Chen', 'alex.c@company.com', 'North', '2021-03-15', 600000),
('Betty Lin', 'betty.l@company.com', 'North', '2022-01-10', 500000),
('Charlie Wang', 'charlie.w@company.com', 'Central', '2020-07-01', 700000),
('David Ho', 'david.h@company.com', 'South', '2023-05-20', 400000),
('Eva Chang', 'eva.c@company.com', 'South', '2024-02-01', 300000);

-- 客戶資料
INSERT INTO customers (company_name, tax_id, industry, city, credit_limit, salesperson_id, status) VALUES
('Apex Semi Tech', '28491023', 'Semiconductor', 'Hsinchu', 1000000, 1, 'ACTIVE'),
('BlueSky Cloud Ltd', '54329871', 'Software', 'Taipei', 500000, 1, 'ACTIVE'),
('CyberCore Inc', '12984736', 'Hardware', 'New Taipei', 300000, 2, 'ACTIVE'),
('Delta Logistics', '98374612', 'Logistics', 'Taichung', 400000, 3, 'ACTIVE'),
('Echo Energy Corp', '76451293', 'Energy', 'Kaohsiung', 800000, 4, 'ACTIVE'),
('Future AI Labs', '34567812', 'Software', 'Taipei', 600000, 2, 'ACTIVE'),
('Grand Precision', '65432198', 'Manufacturing', 'Taichung', 500000, 3, 'ACTIVE'),
('Horizon BioTech', '87654321', 'Medical', 'Taipei', 450000, 1, 'ACTIVE'),
('InnoVibe Studio', '23456789', 'Design', 'Tainan', 150000, 4, 'INACTIVE'),
('Jovial Media Group', NULL, 'Media', 'Taipei', 100000, 2, 'SUSPENDED');

-- 產品資料
INSERT INTO products (product_code, product_name, category, unit_price, cost_price, stock_quantity) VALUES
('SRV-001', 'Enterprise Server Pro', 'Hardware', 120000, 85000, 25),
('SRV-002', 'Edge Computing Node', 'Hardware', 45000, 30000, 50),
('SFT-001', 'Cloud CRM Enterprise (1-Yr)', 'Software', 60000, 10000, 999),
('SFT-002', 'Data Analytics Suite (1-Yr)', 'Software', 95000, 15000, 999),
('SEC-001', 'Firewall Appliance Gen4', 'Security', 35000, 22000, 40),
('SVC-001', '24/7 Priority SLA Support', 'Service', 50000, 20000, 999);

-- 訂單主表資料
INSERT INTO orders (order_number, customer_id, salesperson_id, order_date, status, total_amount) VALUES
('ORD-2024-001', 1, 1, '2024-01-15', 'COMPLETED', 360000),
('ORD-2024-002', 2, 1, '2024-01-20', 'COMPLETED', 155000),
('ORD-2024-003', 4, 3, '2024-02-18', 'COMPLETED', 240000),
('ORD-2024-004', 3, 2, '2024-02-05', 'COMPLETED', 80000),
('ORD-2024-005', 8, 5, '2024-02-25', 'CANCELLED', 60000),
('ORD-2024-006', 5, 4, '2024-03-22', 'COMPLETED', 190000),
('ORD-2024-007', 1, 1, '2024-03-10', 'COMPLETED', 450000),
('ORD-2024-008', 6, 2, '2024-04-02', 'COMPLETED', 60000),
('ORD-2024-009', 7, 3, '2024-04-15', 'COMPLETED', 135000),
('ORD-2024-010', 2, 1, '2024-05-01', 'COMPLETED', 95000),
('ORD-2024-011', 8, 1, '2024-05-12', 'COMPLETED', 170000),
('ORD-2024-012', 1, 1, '2024-06-01', 'COMPLETED', 290000),
('ORD-2024-013', 4, 3, '2024-06-15', 'CANCELLED', 120000);

-- 訂單明細資料
INSERT INTO order_items (order_id, product_id, quantity, unit_price, subtotal) VALUES
(1, 1, 3, 120000, 360000),
(2, 3, 1, 60000, 60000),
(2, 4, 1, 95000, 95000),
(3, 1, 2, 120000, 240000),
(4, 2, 1, 45000, 45000),
(4, 5, 1, 35000, 35000),
(5, 3, 1, 60000, 60000),
(6, 4, 2, 95000, 190000),
(7, 1, 3, 120000, 360000),
(7, 2, 2, 45000, 90000),
(8, 3, 1, 60000, 60000),
(9, 2, 3, 45000, 135000),
(10, 4, 1, 95000, 95000),
(11, 1, 1, 120000, 120000),
(11, 6, 1, 50000, 50000),
(12, 1, 2, 120000, 240000),
(12, 6, 1, 50000, 50000),
(13, 1, 1, 120000, 120000);
