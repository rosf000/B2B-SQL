# 03 PostgreSQL DDL, DML 與資料庫管理實務

## 一、DDL (Data Definition Language) 常用指令

```sql
-- 1. 建立具有約束條件的資料表
CREATE TABLE sample_contracts (
    contract_id SERIAL PRIMARY KEY,
    contract_code VARCHAR(30) UNIQUE NOT NULL,
    customer_id INT NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    annual_value NUMERIC(12, 2) CHECK (annual_value > 0),
    status VARCHAR(20) DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'ACTIVE', 'EXPIRED', 'TERMINATED')),
    signed_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. 修改表結構 (ALTER TABLE)
ALTER TABLE sample_contracts ADD COLUMN notes TEXT;
ALTER TABLE sample_contracts DROP COLUMN IF EXISTS notes;
ALTER TABLE sample_contracts ALTER COLUMN annual_value SET NOT NULL;

-- 3. 建立視圖 (View) 簡化複雜查詢
CREATE OR REPLACE VIEW v_customer_order_summary AS
SELECT 
    c.customer_id,
    c.company_name,
    c.city,
    COUNT(o.order_id) AS total_orders,
    COALESCE(SUM(o.total_amount), 0) AS total_revenue
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id AND o.status = 'COMPLETED'
GROUP BY c.customer_id, c.company_name, c.city;
```

---

## 二、備份與還原實務（終端機指令）

### 1. 備份資料庫 (`pg_dump`)
```bash
# 備份完整資料庫為 SQL 腳本檔案
pg_dump -U postgres -h localhost -p 5432 -d b2b_db -F p -f b2b_db_backup.sql

# 僅備份表結構 (Schema only)
pg_dump -U postgres -h localhost -d b2b_db --schema-only -f b2b_schema.sql
```

### 2. 還原資料庫 (`psql` / `pg_restore`)
```bash
# 建立目標資料庫並還原 SQL 備份
createdb -U postgres -h localhost b2b_db_restored
psql -U postgres -h localhost -d b2b_db_restored -f b2b_db_backup.sql
```
