# 01 Subquery、CTE 與進階 JOIN 完全攻略

> **寫在前面：從「能跑出結果」到「寫出好 SQL」**
> 當你的 SQL 從單表查詢進化到多表關聯，最常見的問題不是「跑不出來」，而是「寫出像俄羅斯套娃一樣的巢狀括號，自己看不懂自己寫的東西」。
> 本篇的核心目標：**讓你的 SQL 像寫作文一樣，有段落、有邏輯，讓同事第一眼就能看懂你的意圖。**
>
> 📌 請搭配 DBeaver 連線到 B2B 資料庫（`customers / orders / order_items / products / salespeople`），邊讀邊跑。

---

## 🗺️ 本篇學習地圖

```
Subquery（子查詢）
  ├── 純量子查詢（Scalar Subquery）
  ├── 表格子查詢（Table Subquery）
  └── 相關子查詢（Correlated Subquery）

CTE（Common Table Expression）
  ├── 基本 WITH ... AS
  ├── 多段 CTE 串聯
  └── 遞迴 CTE（Recursive CTE）

進階 JOIN
  ├── SELF JOIN（自關聯）
  ├── FULL OUTER JOIN（全外部連結）
  ├── CROSS JOIN（笛卡兒積）
  ├── LATERAL JOIN（側向連結）
  └── EXISTS vs IN vs JOIN 效能比較
```

---

## 一、Subquery 子查詢

### 1.1 為什麼需要子查詢？

在實際業務中，你的資料分析問題通常是**分層次的**：

1. 先算出某個基準值（例如：全體客戶的平均消費額）
2. 再用這個基準值去篩選資料（例如：找出消費超過平均的客戶）

這種「先算基準、再篩選」的模式，就需要子查詢。

---

### 1.2 純量子查詢（Scalar Subquery）

純量子查詢會**只回傳一個值**，可以放在 SELECT 或 WHERE 子句中。

**情境**：查詢每位業務的業績，同時顯示「與全體業務平均業績的差距」。

```sql
SELECT
    s.name                                              AS 業務姓名,
    s.region                                            AS 負責區域,
    COALESCE(SUM(o.total_amount), 0)                    AS 個人業績,
    ROUND(
        COALESCE(SUM(o.total_amount), 0) -
        (
            -- 純量子查詢：計算全體業務的平均業績（只回傳一個數字）
            SELECT AVG(total_by_sp)
            FROM (
                SELECT SUM(total_amount) AS total_by_sp
                FROM orders
                WHERE status = 'COMPLETED'
                GROUP BY salesperson_id
            ) AS sp_totals
        ),
        0
    )                                                   AS 與平均差距
FROM salespeople s
LEFT JOIN orders o
    ON s.salesperson_id = o.salesperson_id
    AND o.status = 'COMPLETED'
GROUP BY s.salesperson_id, s.name, s.region
ORDER BY 個人業績 DESC;
```

> 💡 **業務意義**：HR 或主管用這份報表，一秒就能看出哪些業務高於均線、哪些需要輔導。

---

### 1.3 表格子查詢（Table Subquery / Derived Table）

把子查詢的結果當成一張**暫時的表格**使用（放在 FROM 後面）。

**情境**：找出「單筆訂單金額」超過該客戶「歷史平均訂單金額」的異常大單。

```sql
-- 步驟說明：先算出每位客戶的平均訂單金額，再與個別訂單比較
SELECT
    c.company_name    AS 客戶名稱,
    o.order_number    AS 訂單編號,
    o.order_date      AS 下單日期,
    o.total_amount    AS 本次金額,
    avg_table.avg_amt AS 該客戶歷史均值,
    ROUND(
        (o.total_amount / avg_table.avg_amt - 1) * 100, 1
    )                 AS 超出比例_百分比
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN (
    -- 表格子查詢：計算每個客戶的平均訂單金額
    SELECT
        customer_id,
        ROUND(AVG(total_amount), 2) AS avg_amt
    FROM orders
    WHERE status = 'COMPLETED'
    GROUP BY customer_id
) AS avg_table ON o.customer_id = avg_table.customer_id
WHERE o.status = 'COMPLETED'
  AND o.total_amount > avg_table.avg_amt * 1.5   -- 超出均值 50% 以上
ORDER BY 超出比例_百分比 DESC;
```

---

### 1.4 相關子查詢（Correlated Subquery）

相關子查詢是最強大也最難理解的一種——它的子查詢**會引用外層查詢的欄位**，每一列資料都會觸發一次子查詢執行。

**情境**：找出每位業務的「最新一筆」訂單。

```sql
SELECT
    s.name         AS 業務姓名,
    o.order_number AS 最新訂單號,
    o.order_date   AS 下單日期,
    o.total_amount AS 訂單金額
FROM orders o
JOIN salespeople s ON o.salesperson_id = s.salesperson_id
WHERE o.order_date = (
    -- 相關子查詢：對外層每一列 o，找出同一業務的最大日期
    SELECT MAX(o2.order_date)
    FROM orders o2
    WHERE o2.salesperson_id = o.salesperson_id   -- 關鍵：引用外層的 o.salesperson_id
      AND o2.status = 'COMPLETED'
)
ORDER BY s.name;
```

> ⚠️ **效能警告**：相關子查詢對大表的效能很差（每行都執行一次子查詢）。實務上遇到這種需求，優先考慮用 **Window Function** (`ROW_NUMBER`) 或 **CTE** 來取代。

---

## 二、CTE：讓複雜 SQL 變得可閱讀

### 2.1 為什麼要使用 CTE？

下面用同一個需求（找出消費高於平均的客戶）來對比：

#### ❌ 巢狀子查詢（俄羅斯套娃，難以閱讀）

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

#### ✅ CTE 模組化寫法（推薦）

```sql
WITH customer_spending AS (
    -- 步驟 1：計算每個客戶的總消費額
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
    -- 步驟 2：計算全體客戶的平均消費水準
    SELECT AVG(total_spent) AS avg_benchmark
    FROM customer_spending
)
-- 步驟 3：篩選出高於平均水準的優質客戶
SELECT
    cs.company_name,
    cs.total_spent,
    ROUND(sb.avg_benchmark, 2) AS industry_avg
FROM customer_spending cs
CROSS JOIN spending_benchmark sb
WHERE cs.total_spent > sb.avg_benchmark
ORDER BY cs.total_spent DESC;
```

**CTE 的三大優勢**：

| 優勢       | 說明                                                |
| ---------- | --------------------------------------------------- |
| 可讀性     | 每個`WITH` 區塊就像一個「步驟說明」，邏輯一目了然 |
| 可重複使用 | 同一個 CTE 可以在後續查詢中多次引用                 |
| 除錯方便   | 可以只跑某個 CTE 區塊，獨立驗證中間結果             |

---

### 2.2 多段 CTE 串聯實戰

**情境**：完整的 RFM 客戶價值分層前置計算（Recency / Frequency / Monetary）

```sql
WITH
-- 第一段：計算每個客戶的三個 RFM 指標原始值
rfm_raw AS (
    SELECT
        c.customer_id,
        c.company_name,
        c.industry,
        -- Recency：最近一次交易距今天數（越小越好）
        CURRENT_DATE - MAX(o.order_date)::date            AS recency_days,
        -- Frequency：交易次數（越多越好）
        COUNT(DISTINCT o.order_id)                        AS frequency,
        -- Monetary：總消費金額（越大越好）
        COALESCE(SUM(o.total_amount), 0)                  AS monetary
    FROM customers c
    LEFT JOIN orders o
        ON c.customer_id = o.customer_id
        AND o.status = 'COMPLETED'
    GROUP BY c.customer_id, c.company_name, c.industry
),
-- 第二段：用 NTILE 將各指標分為 1~4 分（分位數評分）
rfm_scores AS (
    SELECT
        *,
        -- 注意：recency 越小越好，所以倒序排列
        NTILE(4) OVER (ORDER BY recency_days DESC)   AS r_score,
        NTILE(4) OVER (ORDER BY frequency ASC)       AS f_score,
        NTILE(4) OVER (ORDER BY monetary ASC)        AS m_score
    FROM rfm_raw
),
-- 第三段：加總分數並貼標籤
rfm_labeled AS (
    SELECT
        *,
        (r_score + f_score + m_score)               AS total_score,
        CASE
            WHEN (r_score + f_score + m_score) >= 10 THEN '🏆 黃金客戶'
            WHEN (r_score + f_score + m_score) >= 7  THEN '💎 潛力客戶'
            WHEN (r_score + f_score + m_score) >= 5  THEN '🔄 需要維繫'
            ELSE                                          '⚠️  流失風險'
        END                                         AS customer_tier
    FROM rfm_scores
)
-- 最終輸出
SELECT
    company_name,
    industry,
    recency_days,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    total_score,
    customer_tier
FROM rfm_labeled
ORDER BY total_score DESC;
```

---

### 2.3 遞迴 CTE（Recursive CTE）— 處理樹狀階層資料

遞迴 CTE 是處理**組織圖、類別樹、BOM 清單**等階層型資料的利器。語法結構固定：

```sql
WITH RECURSIVE cte_name AS (
    -- ① 錨點查詢（Anchor）：從根節點出發
    SELECT ... FROM table WHERE parent_id IS NULL

    UNION ALL

    -- ② 遞迴查詢（Recursive Member）：每次往下找子節點
    SELECT child.* FROM table child
    JOIN cte_name parent ON child.parent_id = parent.id
)
SELECT * FROM cte_name;
```

**情境**：假設我們有一個產品類別樹（`product_categories` 表），找出某類別下的所有子類別（任意深度）：

```sql
-- 先假設表結構：
-- product_categories(category_id, category_name, parent_category_id)

WITH RECURSIVE category_tree AS (
    -- ① 錨點：從最頂層（沒有父類別）開始
    SELECT
        category_id,
        category_name,
        parent_category_id,
        0                       AS depth,           -- 深度計數
        category_name::TEXT     AS full_path         -- 完整路徑
    FROM product_categories
    WHERE parent_category_id IS NULL

    UNION ALL

    -- ② 遞迴：找出子類別
    SELECT
        c.category_id,
        c.category_name,
        c.parent_category_id,
        ct.depth + 1,
        (ct.full_path || ' > ' || c.category_name)::TEXT
    FROM product_categories c
    JOIN category_tree ct ON c.parent_category_id = ct.category_id
)
SELECT
    REPEAT('  ', depth) || category_name   AS 類別（縮排顯示層級）,
    depth                                   AS 層級,
    full_path                               AS 完整路徑
FROM category_tree
ORDER BY full_path;
```

**實際 B2B 資料庫的遞迴應用**：業務負責人找出「自己底下所有業務的業績加總」：

```sql
-- 假設 salespeople 表有 manager_id 欄位，形成樹狀結構
WITH RECURSIVE subordinates AS (
    -- 從指定業務開始（以 salesperson_id = 1 為例，即最高主管）
    SELECT salesperson_id, name, manager_id, 0 AS depth
    FROM salespeople
    WHERE salesperson_id = 1

    UNION ALL

    -- 往下找直屬下屬
    SELECT s.salesperson_id, s.name, s.manager_id, sub.depth + 1
    FROM salespeople s
    JOIN subordinates sub ON s.manager_id = sub.salesperson_id
)
SELECT
    sub.name                              AS 業務姓名,
    sub.depth                             AS 層級,
    COALESCE(SUM(o.total_amount), 0)      AS 業績
FROM subordinates sub
LEFT JOIN orders o
    ON sub.salesperson_id = o.salesperson_id
    AND o.status = 'COMPLETED'
GROUP BY sub.salesperson_id, sub.name, sub.depth
ORDER BY sub.depth, 業績 DESC;
```

---

## 三、進階 JOIN 技巧

### 3.1 SELF JOIN（自關聯查詢）

SELF JOIN 是**同一張表和自己做關聯**，常用於：

- 組織圖（找出員工與主管的關係）
- 在同一張客戶表中找出同城市的客戶配對

```sql
-- 情境：找出「同一產業」內，信用額度差距超過 100 萬的客戶配對
-- 可以用來識別：同業競爭者的信用差異，評估潛在風險
SELECT
    a.industry          AS 產業別,
    a.company_name      AS 客戶A,
    a.credit_limit      AS A的信用額度,
    b.company_name      AS 客戶B,
    b.credit_limit      AS B的信用額度,
    (a.credit_limit - b.credit_limit) AS 信用差距
FROM customers a
JOIN customers b
    ON a.industry = b.industry                    -- 同產業
    AND a.customer_id < b.customer_id             -- 避免重複配對（A,B 和 B,A 只算一次）
    AND ABS(a.credit_limit - b.credit_limit) > 1000000  -- 差距超過 100 萬
WHERE a.status = 'ACTIVE' AND b.status = 'ACTIVE'
ORDER BY a.industry, 信用差距 DESC;
```

---

### 3.2 FULL OUTER JOIN（全外部連結）

保留兩張表的**所有資料**，無法配對的那側會是 NULL。最常用於**跨系統資料對帳（Reconciliation）**。

```sql
-- 情境：比對 ERP 系統的訂單與銀行收款紀錄，找出異常
-- （真實工作場景：月底財務對帳時用到）
SELECT
    COALESCE(e.erp_order_id, '無對應') AS ERP訂單號,
    e.erp_amount                       AS ERP金額,
    COALESCE(b.bank_trans_id, '無對應') AS 銀行交易號,
    b.bank_amount                      AS 銀行入帳金額,
    CASE
        WHEN e.erp_order_id IS NULL      THEN '⚠️  銀行有收款，ERP 無對應訂單'
        WHEN b.bank_trans_id IS NULL     THEN '❌ ERP 有訂單，銀行尚未收款'
        WHEN e.erp_amount != b.bank_amount THEN '🔴 金額不符，請核查'
        ELSE                                  '✅ 對帳正常'
    END AS 對帳狀態
FROM erp_orders e
FULL OUTER JOIN bank_transactions b ON e.erp_order_id = b.order_id
ORDER BY 對帳狀態, e.erp_order_id;
```

---

### 3.3 CROSS JOIN（笛卡兒積）

CROSS JOIN 產生兩張表的**所有組合**（m 列 × n 列 = m×n 列）。聽起來很暴力，但有幾個合理的使用場景：

**合理使用 1**：生成「所有月份 × 所有業務」的報表骨架（避免某月無業績就消失）

> 💡 **小叮嚀（進階時序語法提前預覽）**：  
> 下方範例中使用了 `generate_series()`（產生連續月份）與 `DATE_TRUNC()`（日期截斷到月初）。如果你還沒看過這兩個語法，完全不用擔心！我們在第 03 篇《日期字串處理與效能優化入門》會有專章深入講解。  
> 這裡的核心學習目標是：**理解如何用 `CROSS JOIN` 笛卡兒積生成「月份 × 業務」的完整骨架矩陣，再用 `LEFT JOIN` 補齊零業績月份**！

```sql
-- 第一步：產生 2024 年 1~12 月的月份序列
WITH months AS (
    SELECT
        generate_series(
            '2024-01-01'::date,
            '2024-12-01'::date,
            '1 month'::interval
        )::date AS month_start
),
-- 第二步：所有業務
all_salespeople AS (
    SELECT salesperson_id, name FROM salespeople
),
-- 第三步：骨架 = 月份 × 業務（CROSS JOIN）
skeleton AS (
    SELECT m.month_start, sp.salesperson_id, sp.name
    FROM months m
    CROSS JOIN all_salespeople sp
)
-- 第四步：LEFT JOIN 實際業績（沒有業績的月份顯示 0）
SELECT
    s.month_start                                   AS 月份,
    s.name                                          AS 業務姓名,
    COALESCE(SUM(o.total_amount), 0)                AS 月業績,
    s.salesperson_id IN (
        SELECT DISTINCT salesperson_id FROM orders
        WHERE DATE_TRUNC('month', order_date) = s.month_start
        AND status = 'COMPLETED'
    )                                               AS 當月有成交
FROM skeleton s
LEFT JOIN orders o
    ON s.salesperson_id = o.salesperson_id
    AND DATE_TRUNC('month', o.order_date) = s.month_start
    AND o.status = 'COMPLETED'
GROUP BY s.month_start, s.salesperson_id, s.name
ORDER BY s.month_start, s.name;
```

---

### 3.4 LATERAL JOIN（側向連結）

`LATERAL` 是 PostgreSQL 特有的強大功能，允許右側的子查詢**引用左側表的每一列**，類似在 JOIN 內使用相關子查詢。

**情境**：取每位客戶**最近 3 筆**訂單（用一般 JOIN 很難做到，LATERAL 一步到位）

```sql
SELECT
    c.company_name    AS 客戶名稱,
    recent.order_number AS 訂單號,
    recent.order_date   AS 下單日期,
    recent.total_amount AS 金額,
    recent.rank_no      AS 最近第幾筆
FROM customers c
-- LATERAL 讓子查詢可以引用外層的 c.customer_id
CROSS JOIN LATERAL (
    SELECT
        o.order_number,
        o.order_date,
        o.total_amount,
        ROW_NUMBER() OVER (ORDER BY o.order_date DESC) AS rank_no
    FROM orders o
    WHERE o.customer_id = c.customer_id     -- 引用外層 c
      AND o.status = 'COMPLETED'
    ORDER BY o.order_date DESC
    LIMIT 3                                 -- 只取最近 3 筆
) AS recent
WHERE c.status = 'ACTIVE'
ORDER BY c.company_name, recent.rank_no;
```

> 💡 **LATERAL vs 相關子查詢**：兩者概念類似，但 `LATERAL` 更靈活，可以傳回多列多欄，而相關子查詢通常只傳回單一值。

---

### 3.5 EXISTS vs IN vs JOIN 效能比較

這三種寫法常常可以達到同樣的結果，但效能差異顯著：

**情境**：找出「至少有一筆 COMPLETED 訂單」的客戶

#### 寫法一：IN

```sql
SELECT company_name
FROM customers
WHERE customer_id IN (
    SELECT DISTINCT customer_id
    FROM orders
    WHERE status = 'COMPLETED'
);
```

#### 寫法二：EXISTS（推薦）

```sql
SELECT c.company_name
FROM customers c
WHERE EXISTS (
    SELECT 1
    FROM orders o
    WHERE o.customer_id = c.customer_id
      AND o.status = 'COMPLETED'
);
```

#### 寫法三：JOIN + DISTINCT

```sql
SELECT DISTINCT c.company_name
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.status = 'COMPLETED';
```

**效能與適用場景比較**：

| 寫法       | 效能           | 適用場景                | 注意事項                     |
| ---------- | -------------- | ----------------------- | ---------------------------- |
| `IN`     | 中等           | 子查詢結果小（< 1萬行） | 子查詢含 NULL 時結果可能出錯 |
| `EXISTS` | **最佳** | 找「存在/不存在」關係   | 找到第一筆就停止，不掃全表   |
| `JOIN`   | 視情況         | 需要取右表欄位時        | 多對多時需加 DISTINCT 去重   |

**找「沒有任何 COMPLETED 訂單」的客戶（NOT EXISTS vs NOT IN 的陷阱）**：

```sql
-- ✅ 推薦：NOT EXISTS（安全）
SELECT c.company_name
FROM customers c
WHERE NOT EXISTS (
    SELECT 1
    FROM orders o
    WHERE o.customer_id = c.customer_id
      AND o.status = 'COMPLETED'
);

-- ⚠️ 危險：NOT IN（若子查詢有 NULL，會傳回空結果！）
-- 以下查詢如果 orders 表中有 customer_id 為 NULL 的列，會傳回 0 筆
SELECT company_name
FROM customers
WHERE customer_id NOT IN (
    SELECT customer_id   -- 若此欄有 NULL，整個 NOT IN 失效
    FROM orders
    WHERE status = 'COMPLETED'
);
```

> ⚠️ **NULL 陷阱**：`NOT IN` 遇到子查詢有 NULL 值，整個條件會評估為 UNKNOWN，導致沒有任何資料被回傳。這是 SQL 初學者最常踩的坑之一。**一律使用 NOT EXISTS 取代 NOT IN。**

---

## 四、商業情境練習題

以下 5 題均基於 B2B 資料庫（`customers / orders / order_items / products / salespeople`）。

---

### 題目 1：找出「高於自己產業均值」的優質客戶

**情境**：業務主管想知道，在各自的產業別（`industry`）中，哪些客戶的總消費額高於該產業的平均水準？

```sql
-- 解答
WITH industry_avg AS (
    SELECT
        c.industry,
        AVG(o_total.total_by_customer) AS avg_spending
    FROM customers c
    JOIN (
        SELECT customer_id, SUM(total_amount) AS total_by_customer
        FROM orders
        WHERE status = 'COMPLETED'
        GROUP BY customer_id
    ) o_total ON c.customer_id = o_total.customer_id
    GROUP BY c.industry
),
customer_spending AS (
    SELECT
        c.customer_id,
        c.company_name,
        c.industry,
        SUM(o.total_amount) AS total_spending
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.status = 'COMPLETED'
    GROUP BY c.customer_id, c.company_name, c.industry
)
SELECT
    cs.company_name,
    cs.industry,
    cs.total_spending,
    ROUND(ia.avg_spending, 0)        AS 產業均值,
    ROUND(
        (cs.total_spending - ia.avg_spending) / ia.avg_spending * 100, 1
    )                                AS 超出均值百分比
FROM customer_spending cs
JOIN industry_avg ia ON cs.industry = ia.industry
WHERE cs.total_spending > ia.avg_spending
ORDER BY 超出均值百分比 DESC;
```

---

### 題目 2：跨部門訂單貢獻度與高於平均績效分析（多層 CTE 拆解）

**情境**：財務部希望找出每位業務員「單筆訂單金額大於該部門平均訂單金額」的所有成交通知單，並計算高出部門平均多少百分比，以利評選季度卓越專案。

<details>
<summary>💡 思維導引與步驟提示（點擊展開）</summary>

1. **第一層 CTE (`dept_avg_orders`)**：將 `orders` 與 `salespeople` 關聯，以 `department` 分組，計算各部門已完成訂單（`COMPLETED`）的平均訂單金額 `ROUND(AVG(total_amount), 2)`。
2. **第二層 CTE (`above_avg_orders`)**：篩選出每筆訂單的 `total_amount` 大於該部門平均值的紀錄，並計算超出金額。
3. **最終輸出**：關聯 `salespeople` 與 `customers`，列出業務姓名、部門、客戶名稱、訂單編號、訂單金額、部門平均金額、超出百分比。
</details>

<details>
<summary>🎯 參考實作代碼（自我檢測完成後再看）</summary>

```sql
-- 第一步：計算各部門的平均訂單金額
WITH dept_avg AS (
    SELECT
        s.department,
        ROUND(AVG(o.total_amount), 2) AS avg_dept_order_amount
    FROM orders o
    JOIN salespeople s ON o.salesperson_id = s.salesperson_id
    WHERE o.status = 'COMPLETED'
    GROUP BY s.department
),
-- 第二步：篩選出大於所屬部門平均的成交通知單
above_avg AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.salesperson_id,
        o.total_amount,
        s.department,
        da.avg_dept_order_amount,
        ROUND(
            (o.total_amount - da.avg_dept_order_amount) / da.avg_dept_order_amount * 100,
            1
        ) AS pct_above_dept_avg
    FROM orders o
    JOIN salespeople s ON o.salesperson_id = s.salesperson_id
    JOIN dept_avg da ON s.department = da.department
    WHERE o.status = 'COMPLETED'
      AND o.total_amount > da.avg_dept_order_amount
)
-- 第三步：關聯業務與客戶名稱產出報表
SELECT
    s.name                  AS 業務姓名,
    aa.department           AS 部門,
    c.company_name          AS 客戶名稱,
    aa.order_id             AS 訂單編號,
    aa.total_amount         AS 訂單金額,
    aa.avg_dept_order_amount AS 部門平均金額,
    aa.pct_above_dept_avg   AS 超出部門平均百分比
FROM above_avg aa
JOIN salespeople s ON aa.salesperson_id = s.salesperson_id
JOIN customers c ON aa.customer_id = c.customer_id
ORDER BY aa.department, aa.pct_above_dept_avg DESC;
```
</details>

---

### 題目 3：找出從未購買某類別產品的客戶

**情境**：行銷部門想向「從未買過 Security 類別產品」的 ACTIVE 客戶推播資安產品廣告。

```sql
-- 解答（使用 NOT EXISTS，避免 NOT IN 的 NULL 陷阱）
SELECT
    c.customer_id,
    c.company_name,
    c.industry,
    c.city
FROM customers c
WHERE c.status = 'ACTIVE'
  AND NOT EXISTS (
      SELECT 1
      FROM orders o
      JOIN order_items oi ON o.order_id = oi.order_id
      JOIN products p ON oi.product_id = p.product_id
      WHERE o.customer_id = c.customer_id
        AND o.status = 'COMPLETED'
        AND p.category = 'Security'
  )
ORDER BY c.company_name;
```

---

### 題目 4：LATERAL 取每位業務的 Top 3 成交客戶

**情境**：年度業績報告中，每位業務需要列出自己業績貢獻最高的前三名客戶。

```sql
-- 解答
SELECT
    s.name                  AS 業務姓名,
    top_cust.company_name   AS 客戶名稱,
    top_cust.total_purchase AS 總購買金額,
    top_cust.rank_no        AS 排名
FROM salespeople s
CROSS JOIN LATERAL (
    SELECT
        c.company_name,
        SUM(o.total_amount) AS total_purchase,
        RANK() OVER (ORDER BY SUM(o.total_amount) DESC) AS rank_no
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.salesperson_id = s.salesperson_id
      AND o.status = 'COMPLETED'
    GROUP BY c.company_name
    ORDER BY total_purchase DESC
    LIMIT 3
) AS top_cust
ORDER BY s.name, top_cust.rank_no;
```

---

### 題目 5：遞迴 CTE — 計算產品類別的多層級彙總

**情境**：產品分為 Hardware > Server > GPU Server 三個層級。用遞迴 CTE 計算每個類別（含所有子類別）的合計銷售額。

```sql
-- 假設 product_categories 表結構已存在
WITH RECURSIVE category_tree AS (
    -- 錨點：從最頂層類別出發
    SELECT
        category_id,
        category_name,
        parent_category_id,
        category_id AS root_id
    FROM product_categories
    WHERE parent_category_id IS NULL

    UNION ALL

    SELECT
        c.category_id,
        c.category_name,
        c.parent_category_id,
        ct.root_id
    FROM product_categories c
    JOIN category_tree ct ON c.parent_category_id = ct.category_id
),
category_sales AS (
    SELECT
        p.category,
        SUM(oi.quantity * oi.unit_price) AS sales
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.status = 'COMPLETED'
    GROUP BY p.category
)
SELECT
    ct.category_name                   AS 類別名稱,
    COALESCE(cs.sales, 0)              AS 直接銷售額,
    SUM(COALESCE(cs2.sales, 0))
        OVER (PARTITION BY ct.root_id) AS 含子類別合計銷售額
FROM category_tree ct
LEFT JOIN category_sales cs ON ct.category_name = cs.category
LEFT JOIN category_tree ct2 ON ct2.root_id = ct.root_id
LEFT JOIN category_sales cs2 ON ct2.category_name = cs2.category
GROUP BY ct.category_id, ct.category_name, ct.root_id, cs.sales
ORDER BY ct.root_id, ct.category_id;
```

---

## 五、本章重點彙整

```
子查詢（Subquery）
  ✅ 純量子查詢：放在 SELECT / WHERE 中，只回傳一個值
  ✅ 表格子查詢：放在 FROM 中，當作暫時表格使用
  ✅ 相關子查詢：引用外層欄位，效能差，優先改用 Window Function

CTE（WITH ... AS）
  ✅ 多段 CTE 串聯：讓複雜邏輯有段落，易於維護
  ✅ 遞迴 CTE：處理樹狀/階層資料（組織圖、類別樹）
  ✅ 格式：錨點查詢 UNION ALL 遞迴查詢

進階 JOIN
  ✅ SELF JOIN：同表自關聯，處理層級關係
  ✅ FULL OUTER JOIN：對帳、找差異
  ✅ CROSS JOIN：生成骨架表（月份×業務）
  ✅ LATERAL：取 Top N 等每行需要獨立子查詢的場景
  ✅ EXISTS 優於 NOT IN（避免 NULL 陷阱）
```

---

*下一篇：[02 Window Functions 全解析](./02_Window_Functions全解析.md) — 用視窗函數做排名、同比、環比分析*
