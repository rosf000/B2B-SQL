# 02 Window Functions 視窗函數全解析

> **Window Functions 是資料分析師與後端工程師 SQL 能力的分水嶺。**
> 核心特點：**「計算聚合統計指標，但保留每一列 (Row) 的明細，不將資料摺疊壓縮。」**

---

## 一、視窗函數語法骨架

```sql
FUNCTION(...) OVER (
    [PARTITION BY 依據哪些欄位分組]
    [ORDER BY 在組內依據哪些欄位排序]
    [ROWS/RANGE BETWEEN ... 視窗滑動範圍]
)
```

---

## 二、三大核心應用場景

### 1. 排名計算：`ROW_NUMBER()` vs `RANK()` vs `DENSE_RANK()`

假設各業務員業績分數為：`[100, 90, 90, 80]`

| 函數名稱 | 計算結果 | 特點說明 |
| :--- | :--- | :--- |
| `ROW_NUMBER()` | 1, 2, 3, 4 | 嚴格連續唯一編號，即使數值相同也硬排先後 |
| `RANK()` | 1, 2, 2, 4 | 同分並列，但會「跳號」佔位 |
| `DENSE_RANK()` | 1, 2, 2, 3 | 同分並列，但「不跳號」緊密排列 |

```sql
-- 商業題目：找出每個地區 (region) 業績前 2 名的業務員
WITH regional_ranked_sales AS (
    SELECT 
        s.region,
        s.name,
        COALESCE(SUM(o.total_amount), 0) AS total_revenue,
        DENSE_RANK() OVER (
            PARTITION BY s.region 
            ORDER BY COALESCE(SUM(o.total_amount), 0) DESC
        ) AS rank_in_region
    FROM salespeople s
    LEFT JOIN orders o ON s.salesperson_id = o.salesperson_id AND o.status = 'COMPLETED'
    GROUP BY s.salesperson_id, s.name, s.region
)
SELECT * 
FROM regional_ranked_sales
WHERE rank_in_region <= 2;
```

---

### 2. 趨勢與環比計算：`LAG()` 與 `LEAD()`

`LAG(column, offset)`：取前 N 筆紀錄的數值（常用於計算「月增率 MoM」、「與上一筆下單差距」）。
`LEAD(column, offset)`：取後 N 筆紀錄的數值。

```sql
-- 商業題目：計算每個月的營收，以及相比上個月的月增長率 (MoM %)
WITH monthly_sales AS (
    SELECT 
        DATE_TRUNC('month', order_date)::DATE AS sales_month,
        SUM(total_amount) AS current_month_revenue
    FROM orders
    WHERE status = 'COMPLETED'
    GROUP BY DATE_TRUNC('month', order_date)::DATE
)
SELECT 
    sales_month,
    current_month_revenue,
    LAG(current_month_revenue, 1) OVER (ORDER BY sales_month) AS prev_month_revenue,
    ROUND(
        (current_month_revenue - LAG(current_month_revenue, 1) OVER (ORDER BY sales_month)) 
        / NULLIF(LAG(current_month_revenue, 1) OVER (ORDER BY sales_month), 0) * 100, 
        2
    ) AS mom_growth_rate_pct
FROM monthly_sales
ORDER BY sales_month;
```

---

### 3. 累積營收與滾動平均 (Running Total & Moving Average)

```sql
-- 商業題目：計算全年度每天的訂單金額，並統計「年度累計營收 (YTD)」與「近 7 日移動平均」
SELECT 
    order_date,
    SUM(total_amount) AS daily_revenue,
    -- 累積加總 (Running Total)
    SUM(SUM(total_amount)) OVER (
        ORDER BY order_date 
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_revenue_ytd,
    -- 近 7 日滾動平均 (7-Day Moving Average)
    ROUND(
        AVG(SUM(total_amount)) OVER (
            ORDER BY order_date 
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ), 
        2
    ) AS rolling_7day_avg
FROM orders
WHERE status = 'COMPLETED'
GROUP BY order_date
ORDER BY order_date;
```
