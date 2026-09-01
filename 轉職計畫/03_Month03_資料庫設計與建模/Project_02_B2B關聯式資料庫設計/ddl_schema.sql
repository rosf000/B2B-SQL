-- ====================================================================
-- Project 2: B2B Enterprise Database DDL Schema
-- 符合 3NF 正規化、完整外鍵約束、唯一性與檢核約束
-- ====================================================================

-- 清理舊物件
DROP TABLE IF EXISTS b2b_invoices CASCADE;
DROP TABLE IF EXISTS b2b_order_items CASCADE;
DROP TABLE IF EXISTS b2b_orders CASCADE;
DROP TABLE IF EXISTS b2b_products CASCADE;
DROP TABLE IF EXISTS b2b_customers CASCADE;
DROP TABLE IF EXISTS b2b_salespeople CASCADE;

-- 1. 業務代表表
CREATE TABLE b2b_salespeople (
    salesperson_id SERIAL PRIMARY KEY,
    name VARCHAR(60) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    region VARCHAR(30) NOT NULL CHECK (region IN ('North', 'Central', 'South', 'East', 'Overseas')),
    hire_date DATE NOT NULL,
    monthly_target NUMERIC(12, 2) NOT NULL CHECK (monthly_target >= 0),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. 客戶主檔表
CREATE TABLE b2b_customers (
    customer_id SERIAL PRIMARY KEY,
    company_name VARCHAR(120) NOT NULL,
    tax_id VARCHAR(20) UNIQUE,
    industry VARCHAR(50) NOT NULL,
    city VARCHAR(30) NOT NULL,
    address TEXT,
    credit_limit NUMERIC(12, 2) DEFAULT 100000.00 CHECK (credit_limit >= 0),
    salesperson_id INT REFERENCES b2b_salespeople(salesperson_id) ON DELETE SET NULL,
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED', 'UNDER_REVIEW')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. 產品主檔表
CREATE TABLE b2b_products (
    product_id SERIAL PRIMARY KEY,
    product_code VARCHAR(30) NOT NULL UNIQUE,
    product_name VARCHAR(120) NOT NULL,
    category VARCHAR(50) NOT NULL CHECK (category IN ('Hardware', 'Software', 'Network', 'Security', 'Service')),
    unit_price NUMERIC(10, 2) NOT NULL CHECK (unit_price > 0),
    cost_price NUMERIC(10, 2) NOT NULL CHECK (cost_price >= 0),
    stock_quantity INT DEFAULT 0 CHECK (stock_quantity >= 0),
    is_available BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. 訂單主檔表
CREATE TABLE b2b_orders (
    order_id SERIAL PRIMARY KEY,
    order_number VARCHAR(40) NOT NULL UNIQUE,
    customer_id INT NOT NULL REFERENCES b2b_customers(customer_id) ON DELETE RESTRICT,
    salesperson_id INT NOT NULL REFERENCES b2b_salespeople(salesperson_id) ON DELETE RESTRICT,
    order_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'CONFIRMED', 'SHIPPED', 'COMPLETED', 'CANCELLED')),
    total_amount NUMERIC(12, 2) DEFAULT 0.00 CHECK (total_amount >= 0),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 5. 訂單明細表 (Junction Table)
CREATE TABLE b2b_order_items (
    item_id SERIAL PRIMARY KEY,
    order_id INT NOT NULL REFERENCES b2b_orders(order_id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES b2b_products(product_id) ON DELETE RESTRICT,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10, 2) NOT NULL CHECK (unit_price >= 0),
    subtotal NUMERIC(12, 2) NOT NULL CHECK (subtotal >= 0),
    CONSTRAINT uk_order_product UNIQUE (order_id, product_id)
);

-- 6. 發票與收款表
CREATE TABLE b2b_invoices (
    invoice_id SERIAL PRIMARY KEY,
    invoice_number VARCHAR(40) NOT NULL UNIQUE,
    order_id INT NOT NULL UNIQUE REFERENCES b2b_orders(order_id) ON DELETE RESTRICT,
    issue_date DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date DATE NOT NULL,
    total_amount NUMERIC(12, 2) NOT NULL CHECK (total_amount >= 0),
    payment_status VARCHAR(20) DEFAULT 'UNPAID' CHECK (payment_status IN ('UNPAID', 'PAID', 'OVERDUE', 'REFUNDED')),
    paid_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 索引最佳化
CREATE INDEX idx_b2b_cust_tax ON b2b_customers(tax_id);
CREATE INDEX idx_b2b_cust_city ON b2b_customers(city);
CREATE INDEX idx_b2b_orders_date ON b2b_orders(order_date);
CREATE INDEX idx_b2b_orders_status ON b2b_orders(status);
CREATE INDEX idx_b2b_items_order ON b2b_order_items(order_id);
CREATE INDEX idx_b2b_invoices_due ON b2b_invoices(due_date);
