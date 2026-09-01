-- ====================================================================
-- Month 08: 旗艦專案測試種子資料
-- ====================================================================

INSERT INTO m8_salespeople (name, email, region, monthly_target) VALUES
('Alex Hunter', 'alex.h@company.com', 'North', 800000),
('Betty Vance', 'betty.v@company.com', 'North', 700000),
('Carlos Diaz', 'carlos.d@company.com', 'Central', 600000),
('Diana Prince', 'diana.p@company.com', 'South', 500000);

INSERT INTO m8_customers (company_name, tax_id, industry, city, credit_limit, salesperson_id, status) VALUES
('Apex Semiconductor Inc', '28491023', 'Semiconductor', 'Hsinchu', 1500000, 1, 'ACTIVE'),
('BlueSky Cloud Systems', '54329871', 'Software', 'Taipei', 800000, 1, 'ACTIVE'),
('CyberCore Network Ltd', '12984736', 'Hardware', 'New Taipei', 600000, 2, 'ACTIVE'),
('Delta Logistics TW', '98374612', 'Logistics', 'Taichung', 500000, 3, 'ACTIVE'),
('Echo Green Energy', '76451293', 'Energy', 'Kaohsiung', 900000, 4, 'ACTIVE'),
('Future AI Solutions', '34567812', 'Software', 'Taipei', 750000, 2, 'ACTIVE'),
('Grand Precision Forge', '65432198', 'Manufacturing', 'Taichung', 650000, 3, 'ACTIVE');

INSERT INTO m8_products (product_code, product_name, category, unit_price, cost_price, stock_quantity) VALUES
('SRV-900', 'Enterprise AI Server', 'Hardware', 300000, 180000, 15),
('STO-500', 'Flash Array 50TB', 'Hardware', 150000, 90000, 25),
('SFT-800', 'Data Governance Suite', 'Software', 120000, 20000, 999),
('SVC-100', 'Enterprise SLA Support', 'Service', 60000, 20000, 999);

INSERT INTO m8_orders (order_number, customer_id, salesperson_id, order_date, status, total_amount) VALUES
('ORD-8001', 1, 1, '2024-07-05', 'COMPLETED', 600000),
('ORD-8002', 2, 1, '2024-07-12', 'COMPLETED', 120000),
('ORD-8003', 3, 2, '2024-07-20', 'COMPLETED', 210000),
('ORD-8004', 4, 3, '2024-08-01', 'COMPLETED', 300000),
('ORD-8005', 1, 1, '2024-08-15', 'COMPLETED', 360000),
('ORD-8006', 5, 4, '2024-08-20', 'COMPLETED', 150000);

INSERT INTO m8_order_items (order_id, product_id, quantity, unit_price, subtotal) VALUES
(1, 1, 2, 300000, 600000),
(2, 3, 1, 120000, 120000),
(3, 2, 1, 150000, 150000),
(3, 4, 1, 60000, 60000),
(4, 1, 1, 300000, 300000),
(5, 1, 1, 300000, 300000),
(5, 4, 1, 60000, 60000),
(6, 2, 1, 150000, 150000);
