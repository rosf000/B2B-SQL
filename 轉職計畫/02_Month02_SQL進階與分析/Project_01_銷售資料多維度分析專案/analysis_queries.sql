-- ====================================================================
-- Project 1: 四大多維度商業分析進階 SQL 查詢
-- ====================================================================

-- --------------------------------------------------------------------
-- 主題一：RFM 客戶價值模型分群 (Recency, Frequency, Monetary)
-- --------------------------------------------------------------------
WITH customer_rfm_raw AS (
    SELECT 
        c.customer_id,
        c.company_name,
        c.industry,
        -- R: 最近一次下單距今天數 (以 2024-12-31 為基準日)
        ('2024-12-31'::DATE - MAX(o.order_date)) AS recency_days,
        -- F: 歷史下單總頻次
        COUNT(o.order_id) AS frequency_count,
        -- M: 歷史消費總金額
        SUM(o.total_amount) AS monetary_total
    FROM proj1_customers c
    JOIN proj1_orders o ON c.customer_id = o.customer_id
    WHERE o.status = 'COMPLETED'
    GROUP BY c.customer_id, c.company_name, c.industry
),
rfm_scoring AS (
    SELECT 
        customer_id,
        company_name,
        industry,
        recency_days,
        frequency_count,
        monetary_total,
        -- 使用 NTILE 分成 1~5 分
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score, -- 越近下單分數越高 (DESC反向)
        NTILE(5) OVER (ORDER BY frequency_count ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary_total ASC) AS m_score
    FROM customer_rfm_raw
)
SELECT 
    customer_id,
    company_name,
    industry,
    recency_days,
    frequency_count,
    monetary_total,
    r_score, f_score, m_score,
    CASE 
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN '👑 核心 VIP 客戶 (Champions)'
        WHEN r_score >= 3 AND f_score >= 3 THEN '⭐ 忠誠主力客戶 (Loyal Customers)'
        WHEN r_score >= 4 AND f_score <= 2 THEN '🌱 新晉潛力客戶 (New Potential)'
        WHEN r_score <= 2 AND m_score >= 4 THEN '⚠️ 重要挽留客戶 (At Risk VIP)'
        ELSE '💤 沉睡/一般客戶 (Lost / Hibernating)'
    END AS customer_segment
FROM rfm_scoring
ORDER BY monetary_total DESC;

-- --------------------------------------------------------------------
-- 主題二：客戶 Cohort 同梯次留存分析 (月度複購留存率)
-- --------------------------------------------------------------------
WITH first_purchase AS (
    -- 找出每位客戶的首次下單月份 (Cohort Month)
    SELECT 
        customer_id,
        DATE_TRUNC('month', MIN(order_date))::DATE AS cohort_month
    FROM proj1_orders
    WHERE status = 'COMPLETED'
    GROUP BY customer_id
),
monthly_activity AS (
    -- 找出客戶後續每個月的活躍狀況
    SELECT 
        o.customer_id,
        fp.cohort_month,
        DATE_TRUNC('month', o.order_date)::DATE AS order_month,
        -- 計算下單月份與首購月份相差幾個月 (Month Index)
        (EXTRACT(YEAR FROM o.order_date) - EXTRACT(YEAR FROM fp.cohort_month)) * 12 +
        (EXTRACT(MONTH FROM o.order_date) - EXTRACT(MONTH FROM fp.cohort_month)) AS month_index
    FROM proj1_orders o
    JOIN first_purchase fp ON o.customer_id = fp.customer_id
    WHERE o.status = 'COMPLETED'
    GROUP BY o.customer_id, fp.cohort_month, DATE_TRUNC('month', o.order_date)::DATE, o.order_date
),
cohort_size AS (
    SELECT cohort_month, COUNT(DISTINCT customer_id) AS total_cohort_users
    FROM first_purchase
    GROUP BY cohort_month
)
SELECT 
    ma.cohort_month,
    cs.total_cohort_users,
    ma.month_index,
    COUNT(DISTINCT ma.customer_id) AS active_users,
    ROUND(COUNT(DISTINCT ma.customer_id)::NUMERIC / cs.total_cohort_users * 100, 2) AS retention_rate_pct
FROM monthly_activity ma
JOIN cohort_size cs ON ma.cohort_month = cs.cohort_month
GROUP BY ma.cohort_month, cs.total_cohort_users, ma.month_index
ORDER BY ma.cohort_month, ma.month_index;

-- --------------------------------------------------------------------
-- 主題三：產品帕雷托 ABC 分類分析 (Pareto 80/20 Rule)
-- --------------------------------------------------------------------
WITH product_revenue AS (
    SELECT 
        p.product_id,
        p.product_name,
        p.category,
        SUM(oi.subtotal) AS product_total_revenue
    FROM proj1_products p
    JOIN proj1_order_items oi ON p.product_id = oi.product_id
    JOIN proj1_orders o ON oi.order_id = o.order_id
    WHERE o.status = 'COMPLETED'
    GROUP BY p.product_id, p.product_name, p.category
),
product_cumulative AS (
    SELECT 
        product_id,
        product_name,
        category,
        product_total_revenue,
        -- 計算累計營收佔比
        SUM(product_total_revenue) OVER (ORDER BY product_total_revenue DESC) AS running_total,
        SUM(product_total_revenue) OVER () AS grand_total
    FROM product_revenue
)
SELECT 
    product_name,
    category,
    product_total_revenue,
    ROUND(product_total_revenue / grand_total * 100, 2) AS revenue_share_pct,
    ROUND(running_total / grand_total * 100, 2) AS cumulative_share_pct,
    CASE 
        WHEN running_total / grand_total <= 0.70 THEN 'Class A (核心主力 70%)'
        WHEN running_total / grand_total <= 0.90 THEN 'Class B (次要穩定 20%)'
        ELSE 'Class C (長尾微量 10%)'
    END AS abc_category
FROM product_cumulative
ORDER BY product_total_revenue DESC;

-- --------------------------------------------------------------------
-- 主題四：業務員配額達成率與月度動態排名 (Salesperson Performance Matrix)
-- --------------------------------------------------------------------
WITH monthly_rep_sales AS (
    SELECT 
        DATE_TRUNC('month', o.order_date)::DATE AS sales_month,
        s.salesperson_id,
        s.name,
        s.region,
        s.monthly_quota,
        SUM(o.total_amount) AS achieved_revenue
    FROM proj1_salespeople s
    JOIN proj1_orders o ON s.salesperson_id = o.salesperson_id
    WHERE o.status = 'COMPLETED'
    GROUP BY DATE_TRUNC('month', o.order_date)::DATE, s.salesperson_id, s.name, s.region, s.monthly_quota
)
SELECT 
    sales_month,
    name,
    region,
    monthly_quota,
    achieved_revenue,
    ROUND((achieved_revenue / monthly_quota) * 100, 2) AS quota_attainment_pct,
    DENSE_RANK() OVER (PARTITION BY sales_month ORDER BY achieved_revenue DESC) AS monthly_rank,
    -- 相比上個月業績成長額
    achieved_revenue - LAG(achieved_revenue, 1) OVER (
        PARTITION BY salesperson_id ORDER BY sales_month
    ) AS mom_revenue_growth
FROM monthly_rep_sales
ORDER BY sales_month DESC, monthly_rank ASC;
