-- ====================================================================
-- Month 08: 旗艦專案生產級資料庫 Schema
-- ====================================================================

DROP TABLE IF EXISTS m8_order_items CASCADE;
DROP TABLE IF EXISTS m8_orders CASCADE;
DROP TABLE IF EXISTS m8_products CASCADE;
DROP TABLE IF EXISTS m8_customers CASCADE;
DROP TABLE IF EXISTS m8_salespeople CASCADE;

CREATE TABLE m8_salespeople (
    salesperson_id SERIAL PRIMARY KEY,
    name VARCHAR(60) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    region VARCHAR(30) NOT NULL,
    monthly_target NUMERIC(12, 2) NOT NULL DEFAULT 500000.00
);

CREATE TABLE m8_customers (
    customer_id SERIAL PRIMARY KEY,
    company_name VARCHAR(120) NOT NULL,
    tax_id VARCHAR(20) UNIQUE,
    industry VARCHAR(50) NOT NULL,
    city VARCHAR(30) NOT NULL,
    credit_limit NUMERIC(12, 2) DEFAULT 100000.00,
    salesperson_id INT REFERENCES m8_salespeople(salesperson_id),
    status VARCHAR(20) DEFAULT 'ACTIVE',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE m8_products (
    product_id SERIAL PRIMARY KEY,
    product_code VARCHAR(30) NOT NULL UNIQUE,
    product_name VARCHAR(120) NOT NULL,
    category VARCHAR(50) NOT NULL,
    unit_price NUMERIC(10, 2) NOT NULL,
    cost_price NUMERIC(10, 2) NOT NULL,
    stock_quantity INT DEFAULT 0
);

CREATE TABLE m8_orders (
    order_id SERIAL PRIMARY KEY,
    order_number VARCHAR(40) NOT NULL UNIQUE,
    customer_id INT NOT NULL REFERENCES m8_customers(customer_id),
    salesperson_id INT NOT NULL REFERENCES m8_salespeople(salesperson_id),
    order_date DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'COMPLETED',
    total_amount NUMERIC(12, 2) DEFAULT 0.00
);

CREATE TABLE m8_order_items (
    item_id SERIAL PRIMARY KEY,
    order_id INT NOT NULL REFERENCES m8_orders(order_id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES m8_products(product_id),
    quantity INT NOT NULL,
    unit_price NUMERIC(10, 2) NOT NULL,
    subtotal NUMERIC(12, 2) NOT NULL
);

CREATE INDEX idx_m8_cust_tax ON m8_customers(tax_id);
CREATE INDEX idx_m8_orders_date ON m8_orders(order_date);
CREATE INDEX idx_m8_orders_cust ON m8_orders(customer_id);
CREATE INDEX idx_m8_items_order ON m8_order_items(order_id);
