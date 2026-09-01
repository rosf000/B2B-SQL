# 01 Subquery, CTE 與進階 JOIN

## 一、為什麼要使用 CTE (Common Table Expression)？

當商業邏輯變複雜時，傳統的巢狀子查詢（Subquery）會形成「俄羅斯套娃」，括號一層套一層，極難閱讀與維護：

### ❌ 巢狀子查詢（難以閱讀）
```sql
SELECT company_name, total_spent
FROM (
    SELECT c.company_name, SUM(o.total_amount) AS total_spent
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.status = 'COMPLETED'
    GROUP BY c.company_name
) AS customer_spending
WHERE total_spent > (
    SELECT AVG(total_spent)
    FROM (
        SELECT SUM(total_amount) AS total_spent
        FROM orders
        WHERE status = 'COMPLETED'
        GROUP BY customer_id
    ) AS avg_calc
);
```

### ✅ CTE 模組化寫法 (`WITH ... AS`)（推薦）
```sql
WITH customer_spending AS (
    -- 步驟 1: 計算每個客戶的總消費額
    SELECT 
        c.customer_id,
        c.company_name,
        SUM(o.total_amount) AS total_spent
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.status = 'COMPLETED'
    GROUP BY c.customer_id, c.company_name
),
spending_benchmark AS (
    -- 步驟 2: 計算全體客戶的平均消費水準
    SELECT AVG(total_spent) AS avg_benchmark
    FROM customer_spending
)
-- 步驟 3: 篩選出高於平均水準的優質客戶
SELECT 
    cs.company_name,
    cs.total_spent,
    ROUND(sb.avg_benchmark, 2) AS industry_avg
FROM customer_spending cs
CROSS JOIN spending_benchmark sb
WHERE cs.total_spent > sb.avg_benchmark
ORDER BY cs.total_spent DESC;
```

---

## 二、進階 JOIN 技巧

### 1. SELF JOIN（自關聯查詢）
常用於「員工-主管層級 (Hierarchical Data)」或「找出同部門中薪資高於同事的人」：
```sql
-- 找出同一個城市中，登記了超過一家以上的客戶配對
SELECT 
    a.city,
    a.company_name AS company_a,
    b.company_name AS company_b
FROM customers a
JOIN customers b ON a.city = b.city AND a.customer_id < b.customer_id;
```

### 2. FULL OUTER JOIN（全外部關聯）
保留兩張表的全部資料，常拿來做「跨系統資料對帳 (Reconciliation)」：
```sql
-- 比對 ERP 系統的訂單與銀行收款紀錄
SELECT 
    e.erp_order_id,
    e.erp_amount,
    b.bank_trans_id,
    b.bank_amount,
    CASE 
        WHEN e.erp_order_id IS NULL THEN 'Bank record missing in ERP'
        WHEN b.bank_trans_id IS NULL THEN 'ERP order unpaid'
        WHEN e.erp_amount != b.bank_amount THEN 'Amount mismatch ⚠️'
        ELSE 'Matched ✅'
    END AS recon_status
FROM erp_orders e
FULL OUTER JOIN bank_transactions b ON e.erp_order_id = b.order_id;
```
