-- ====================================================================
-- Project 2: 初始資料種子 (Seed Data)
-- ====================================================================

INSERT INTO b2b_salespeople (name, email, region, hire_date, monthly_target) VALUES
('Marcus Vance', 'marcus.v@enterprisetech.io', 'North', '2022-04-01', 1200000.00),
('Sophia Hsu', 'sophia.h@enterprisetech.io', 'North', '2023-01-15', 900000.00),
('Daniel Tsai', 'daniel.t@enterprisetech.io', 'Central', '2021-11-01', 800000.00),
('Rachel Kuo', 'rachel.k@enterprisetech.io', 'South', '2023-08-01', 750000.00);

INSERT INTO b2b_customers (company_name, tax_id, industry, city, address, credit_limit, salesperson_id, status) VALUES
('Quantum Foundry TW', '10293847', 'Semiconductor', 'Hsinchu', 'No. 88, Science Park Rd.', 2500000.00, 1, 'ACTIVE'),
('Nexus FinTech Global', '91827364', 'Finance', 'Taipei', 'Sec. 5, Xinyi Rd.', 1800000.00, 1, 'ACTIVE'),
('OmniLogistics Hub', '56473829', 'Logistics', 'Taichung', 'Taichung Port Zone 3', 800000.00, 3, 'ACTIVE'),
('Apex AI Automation', '47382910', 'Software', 'Taipei', 'Nangang Software Park', 1200000.00, 2, 'ACTIVE'),
('Southern Polymer Corp', '38495012', 'Manufacturing', 'Kaohsiung', 'Qianzhen Tech District', 950000.00, 4, 'ACTIVE');

INSERT INTO b2b_products (product_code, product_name, category, unit_price, cost_price, stock_quantity) VALUES
('HW-SRV-900', 'Enterprise AI Inference Server', 'Hardware', 350000.00, 220000.00, 15),
('HW-STO-500', 'NVMe Flash Storage Array 100TB', 'Hardware', 180000.00, 110000.00, 20),
('SW-DAT-800', 'Enterprise Data Governance Platform', 'Software', 150000.00, 25000.00, 999),
('NW-SEC-300', 'Zero-Trust SASE Gateway', 'Security', 75000.00, 38000.00, 30),
('SV-ARC-100', 'Solution Architecture Consulting (40hr)', 'Service', 120000.00, 50000.00, 999);

INSERT INTO b2b_orders (order_number, customer_id, salesperson_id, order_date, status, total_amount, notes) VALUES
('PO-2024-0081', 1, 1, '2024-07-10', 'COMPLETED', 700000.00, 'Phase 1 AI Server deployment'),
('PO-2024-0082', 2, 1, '2024-07-18', 'COMPLETED', 150000.00, 'Annual Data Governance License'),
('PO-2024-0083', 3, 3, '2024-08-02', 'CONFIRMED', 255000.00, 'Storage Array + Security Gateway');

INSERT INTO b2b_order_items (order_id, product_id, quantity, unit_price, subtotal) VALUES
(1, 1, 2, 350000.00, 700000.00),
(2, 3, 1, 150000.00, 150000.00),
(3, 2, 1, 180000.00, 180000.00),
(3, 4, 1, 75000.00, 75000.00);

INSERT INTO b2b_invoices (invoice_number, order_id, issue_date, due_date, total_amount, payment_status, paid_at) VALUES
('INV-2024-0701', 1, '2024-07-12', '2024-08-12', 700000.00, 'PAID', '2024-07-28 14:30:00+08'),
('INV-2024-0702', 2, '2024-07-20', '2024-08-20', 150000.00, 'PAID', '2024-08-05 10:15:00+08'),
('INV-2024-0801', 3, '2024-08-03', '2024-09-03', 255000.00, 'UNPAID', NULL);
