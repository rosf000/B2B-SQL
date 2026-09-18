# 01 Subquery、CTE 與進階 JOIN — 引導式教學版

> 📌 **這份教材的使用方式**
> 每個段落結尾都有「✋ 動手做」，請打開 DBeaver，連到 B2B 資料庫，**邊讀邊跑**。
> 不要只用眼睛看，跑過一次你才會記得住。

---

## 🗺️ 這篇學什麼？學習順序是這樣的

```
第一關：子查詢（Subquery）
  └── 先學「純量子查詢」——最直覺，只回傳一個數字
  └── 再學「表格子查詢」——把結果當成一張表用
  └── 最後「相關子查詢」——最難，實務上常改用 CTE 替代

第二關：CTE（WITH...AS）
  └── 其實就是「幫子查詢取名字」，讓程式碼更好讀
  └── 多段 CTE 串聯（把複雜邏輯拆成幾個步驟）

第三關：進階 JOIN
  └── SELF JOIN / FULL OUTER JOIN / CROSS JOIN / LATERAL
```

> ⏱ 建議學習時間：第一關 + 第二關優先，第三關可以下次再學

---

## 第一關：子查詢（Subquery）

> 🎯 **這一節最重要的一件事（心智定位）**：
> 子查詢是「把一個查詢的輸出，當作另一個查詢的輸入」的運算嵌套，核心在於括號先跑。
>
> 💼 **為什麼非學不可（避坑痛點）**：
> 在商業分析中，比較標準往往是動態變化的（例如高於平均客單價、高於當月指標）。沒有子查詢，你就必須先手動算一次寫死固定數字，下個月數據一變報表就徹底失效！

---

### 關卡說明：為什麼需要子查詢？

先想想這個情境：

> 主管：「幫我找出**訂單金額高於所有訂單平均值**的訂單」

你要怎麼做？

**你的大腦自然會分兩步走：**

1. 先算出「所有訂單的平均金額」（例如算出來是 85,000）
2. 再從訂單裡，篩選出金額 > 85,000 的那些

問題是：SQL 的 `WHERE` 只能比較一個固定的數字，你沒辦法直接寫

```sql
WHERE total_amount > AVG(total_amount)  -- ❌ 這樣會報錯
```

所以需要**先算出那個數字，再拿來用**。這就是子查詢存在的原因。

---

### 第 1 步：先理解「括號裡先跑」

子查詢的核心概念只有一句話：

> **括號裡的 SELECT 會先執行，得到結果後，外層的查詢才繼續跑。**

```sql
-- 讀法：
-- ① 先跑括號裡的：SELECT AVG(total_amount) FROM orders → 得到一個數字，例如 85000
-- ② 外層再用這個數字：WHERE total_amount > 85000
SELECT order_number, total_amount
FROM orders
WHERE total_amount > (SELECT AVG(total_amount) FROM orders);
--                    ↑ 這整個括號 = 一個數字
```

**✋ 動手做 1：拆解執行**

請先單獨跑「括號裡的部分」，確認它只回傳一個數字：

```sql
-- Step 1：只跑裡面，看它回傳什麼
SELECT AVG(total_amount) FROM orders;
```

記下這個數字，再跑外層整段，確認結果是一致的。

---

### 第 2 步：純量子查詢（Scalar Subquery）

> **純量** = 只有一個值（一個數字、一個字、一個日期）

這種子查詢的結果只有一個值，所以可以放在：

- `WHERE` 後面：拿來當篩選條件
- `SELECT` 後面：拿來當顯示欄位

**情境 A：放在 WHERE — 找出金額高於平均的訂單**

```sql
SELECT
    o.order_number    AS 訂單號,
    c.company_name    AS 客戶,
    o.total_amount    AS 金額
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.status = 'COMPLETED'
  AND o.total_amount > (
      -- 純量子查詢：算出全體已完成訂單的平均金額
      SELECT AVG(total_amount)
      FROM orders
      WHERE status = 'COMPLETED'
  )
ORDER BY o.total_amount DESC;
```

**情境 B：放在 SELECT — 每筆訂單同時顯示「全體均值」**

```sql
SELECT
    o.order_number                             AS 訂單號,
    o.total_amount                             AS 本筆金額,
    (SELECT ROUND(AVG(total_amount), 0)
     FROM orders
     WHERE status = 'COMPLETED')               AS 全體均值,
    o.total_amount - (
     SELECT AVG(total_amount)
     FROM orders
     WHERE status = 'COMPLETED'
    )                                          AS 高於均值多少
FROM orders o
WHERE o.status = 'COMPLETED'
ORDER BY 高於均值多少 DESC;
```

**✋ 動手做 2**

1. 跑上面兩段 SQL
2. 試著把括號裡的子查詢單獨取出來跑，確認它回傳一個數字
3. 改看看：把 `AVG` 換成 `MAX`，結果有什麼不同？

---

### 第 3 步：表格子查詢（Derived Table / Table Subquery）

> 上一步的子查詢只回傳「一個數字」
> 這一步的子查詢回傳「一整張表」，然後我們可以 JOIN 它

**情境**：找出「某筆訂單金額超過該客戶自己平均訂單金額 1.2 倍」的大單

分析一下這個需求需要哪些資訊：

- 需要**每位客戶的平均訂單金額**（這是一張表，有多列）
- 再用這張表和 orders 做比較

```sql
-- 先單獨跑「子查詢部分」，看它長什麼樣子
SELECT
    customer_id,
    ROUND(AVG(total_amount), 0) AS 該客戶平均金額
FROM orders
WHERE status = 'COMPLETED'
GROUP BY customer_id;
-- → 這回傳一張有多列的表（每位客戶一列）
```

現在把這張表放進 FROM，就可以用來 JOIN：

```sql
SELECT
    c.company_name    AS 客戶名稱,
    o.order_number    AS 訂單號,
    o.total_amount    AS 本筆金額,
    avg_t.avg_amt     AS 該客戶平均,
    ROUND((o.total_amount / avg_t.avg_amt - 1) * 100, 1) AS 超出比例
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN (
    -- 表格子查詢：每位客戶的平均訂單金額
    SELECT
        customer_id,
        ROUND(AVG(total_amount), 0) AS avg_amt
    FROM orders
    WHERE status = 'COMPLETED'
    GROUP BY customer_id
) AS avg_t ON o.customer_id = avg_t.customer_id
WHERE o.status = 'COMPLETED'
  AND o.total_amount > avg_t.avg_amt * 1.2
ORDER BY 超出比例 DESC;
```

> 💡 **重點**：`JOIN (SELECT ...) AS 別名` — 括號裡的 SELECT 就是一張暫時的表，`AS` 後面要給它一個名字

**✋ 動手做 3**

1. 先單獨跑括號內的子查詢，確認它有多列（每位客戶各一列）
2. 再跑完整版，看看哪些客戶有「異常大單」
3. 把 `1.2` 改成 `1.5`，找出超出均值兩倍的大單

---

### 第 4 步：相關子查詢（Correlated Subquery）— 了解概念即可

這種子查詢最難，但**實務上幾乎都可以用 CTE 或 Window Function 替代**。
你只需要了解它「是什麼」就好，不需要現在就會寫。

**它難在哪裡？**

普通子查詢只跑一次，結果固定。
相關子查詢會**對外層每一列資料，各自跑一次子查詢**。

```sql
-- 找出每位業務「最新的那一筆」訂單
SELECT s.name, o.order_number, o.order_date
FROM orders o
JOIN salespeople s ON o.salesperson_id = s.salesperson_id
WHERE o.order_date = (
    -- 這個子查詢：對外層 o 的每一列，分別找「同業務的最大日期」
    SELECT MAX(o2.order_date)
    FROM orders o2
    WHERE o2.salesperson_id = o.salesperson_id  -- ← 引用外層的 o.salesperson_id
);
```

> ⚠️ **記住這一句就夠了**：相關子查詢效能差，遇到這種需求，**優先用 CTE + Window Function 取代**。第三篇 Window Functions 教材會教你更好的方法。

#### ✋ 第一關空白頁挑戰（不看上方範例）

> **採購主管提問**：
> 「請找出所有售價（`unit_price`）高於『全體產品平均售價』的商品，輸出商品名稱（`product_name`）、類別（`category`）與售價（`unit_price`），並依售價由大到小排序。」
>
> ⚠️ **請在 DBeaver 打開空白頁手寫完成，再展開對照！**

<details>
<summary>💡 需要思考提示嗎？（點擊展開解題思路）</summary>

1. 外層查詢：從 `products` 表選取 `product_name`, `category`, `unit_price`。
2. 過濾條件：`WHERE unit_price > (純量子查詢)`。
3. 純量子查詢：`SELECT AVG(unit_price) FROM products`。
4. 排序：`ORDER BY unit_price DESC`。
</details>

<details>
<summary>✅ 寫完了？點擊查看標準解答與解析</summary>

```sql
SELECT 
    product_name,
    category,
    unit_price
FROM products
WHERE unit_price > (
    SELECT AVG(unit_price) 
    FROM products
)
ORDER BY unit_price DESC;
```
</details>

> 💡 **第一關核心收斂**：
> **括號裡先跑出基準，純量當常數、表格當視圖；動態指標免寫死，子查詢來牽線。**

---

## 第二關：CTE（WITH...AS）

> 🎯 **這一節最重要的一件事（心智定位）**：
> CTE 是把巢狀難讀的子查詢「取名並拉到最上方先算」，讓 SQL 像寫文章一樣由上往下、線性推進。
>
> 💼 **為什麼非學不可（避坑痛點）**：
> 當 SQL 巢狀嵌套超過 3 層時，就像俄羅斯套娃一樣讓人頭皮發麻，連原作者隔天都看不懂，更無法通過團隊 Code Review；CTE 將複雜管線模組化，是現代企業可維護代碼的必備標準。

---

### 關卡說明：子查詢的最大問題是什麼？

寫了一段子查詢後，你會發現一個問題：

```sql
SELECT * FROM (
    SELECT * FROM (
        SELECT * FROM (
            SELECT ...  -- 括號套括號，眼睛已經歪了
        ) AS t1
    ) AS t2
) AS t3;
```

這種「俄羅斯套娃」結構，三個月後連自己都看不懂。

**CTE 的出現，就是為了解決這個問題。**

---

### 核心概念：CTE = 幫子查詢取名字

```sql
-- ❌ 子查詢版（括號裡的邏輯沒有名字）
SELECT company_name
FROM (
    SELECT c.company_name, SUM(o.total_amount) AS total_spent
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.status = 'COMPLETED'
    GROUP BY c.company_name
) AS 匿名表格
WHERE total_spent > 1000000;

-- ✅ CTE 版（給那個子查詢取名叫 customer_spending）
WITH customer_spending AS (
    SELECT c.company_name, SUM(o.total_amount) AS total_spent
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.status = 'COMPLETED'
    GROUP BY c.company_name
)
-- 直接用名字引用，不需要括號
SELECT company_name, total_spent
FROM customer_spending
WHERE total_spent > 1000000;
```

> 💡 `WITH 名稱 AS (...)` 就是說：**「先幫我算這個，叫它 customer_spending，後面要用」**

---

### 第 1 步：基本 CTE 語法

**語法結構：**

```sql
WITH cte名稱 AS (
    -- 這裡放你的 SELECT 語句
    SELECT ...
)
-- 從這裡開始使用 cte名稱，就像使用一張真實的表一樣
SELECT *
FROM cte名稱
WHERE ...;
```

**實際範例：找出消費超過 100 萬的客戶**

```sql
WITH customer_spending AS (
    -- 第一步：計算每位客戶的總消費
    SELECT
        c.customer_id,
        c.company_name,
        c.industry,
        SUM(o.total_amount) AS total_spent
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.status = 'COMPLETED'
    GROUP BY c.customer_id, c.company_name, c.industry
)
-- 第二步：篩選消費超過 100 萬的
SELECT
    company_name,
    industry,
    total_spent
FROM customer_spending
WHERE total_spent > 1000000
ORDER BY total_spent DESC;
```

**✋ 動手做 4**

1. 跑這段 SQL，看看哪些客戶消費超過 100 萬
2. 試著只跑 CTE 的部分（取出括號內 SELECT 單獨跑），確認它是一張多列的表
3. 把金額門檻改成 500,000，看看多了哪些客戶

---

### 第 2 步：多段 CTE 串聯

多個 CTE 之間用逗號隔開，後面的 CTE 可以引用前面的：

```sql
WITH
第一段 AS (
    SELECT ...
),
第二段 AS (
    -- 可以引用「第一段」
    SELECT ... FROM 第一段 ...
)
-- 最終查詢可以引用任何一段
SELECT * FROM 第二段;
```

**情境：找出「高於全體均值」的優質客戶**

```sql
WITH
-- 第一段：算出每位客戶的總消費
customer_spending AS (
    SELECT
        c.customer_id,
        c.company_name,
        c.industry,
        SUM(o.total_amount) AS total_spent
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.status = 'COMPLETED'
    GROUP BY c.customer_id, c.company_name, c.industry
),
-- 第二段：算出全體的平均消費（引用了第一段的結果）
spending_avg AS (
    SELECT AVG(total_spent) AS avg_spent
    FROM customer_spending   -- ← 直接用第一段的名字！
)
-- 最終查詢：找出高於平均的客戶
SELECT
    cs.company_name,
    cs.industry,
    cs.total_spent,
    ROUND(sa.avg_spent, 0)  AS 全體均值,
    ROUND((cs.total_spent - sa.avg_spent) / sa.avg_spent * 100, 1) AS 超出百分比
FROM customer_spending cs
CROSS JOIN spending_avg sa      -- CROSS JOIN：因為 spending_avg 只有一列
WHERE cs.total_spent > sa.avg_spent
ORDER BY 超出百分比 DESC;
```

**逐步解析：**

| 步驟                  | 做什麼               | 結果                   |
| --------------------- | -------------------- | ---------------------- |
| `customer_spending` | 算每位客戶的總消費   | 多列表格（每客戶一列） |
| `spending_avg`      | 從第一段算出均值     | 只有一列一個數字       |
| 最終 SELECT           | 比較每位客戶 vs 均值 | 篩選出優質客戶         |

**✋ 動手做 5**

1. 先只跑 `customer_spending` 的內容（取出括號內 SELECT）
2. 再加上 `spending_avg`，用上一步的結果算均值
3. 最後跑完整版，看看哪些客戶超過平均

---

### 第 3 步：如何「除錯」CTE — 超實用技巧

多段 CTE 最大的優點是**可以只跑某一段，獨立驗證**：

```sql
-- 你在寫很長的 CTE 時，想確認某一段對不對，
-- 只需要把最終 SELECT 改成查那一段就好：

WITH
customer_spending AS ( ... ),
spending_avg AS ( ... )

-- 🔍 除錯用：先只看第一段的結果
SELECT * FROM customer_spending LIMIT 10;

-- 確認對了，再改回最終查詢
-- SELECT ... FROM customer_spending cs CROSS JOIN spending_avg ...
```

**✋ 動手做 6**

把「動手做 5」的完整 SQL，改成只看 `customer_spending` 的前 10 筆，確認資料正確後，再換回最終查詢。

#### ✋ 第二關空白頁挑戰（不看上方範例）

> **營運長提問**：
> 「請用 CTE 撰寫兩階段分析：
> 第一段 CTE `customer_revenue`：先計算每家客戶已完成訂單的總消費金額 `total_spent`。
> 第二段主查詢：篩選出累計消費金額**大於或等於 50 萬**的大客戶，列出客戶名稱 `company_name` 與 `total_spent`，並依金額由大到小排序。」
>
> ⚠️ **請在 DBeaver 打開空白頁手寫完成，再展開對照！**

<details>
<summary>💡 需要思考提示嗎？（點擊展開解題思路）</summary>

1. 第一段 CTE：
   ```sql
   WITH customer_revenue AS (
       SELECT c.company_name, SUM(o.total_amount) AS total_spent
       FROM customers c
       JOIN orders o ON c.customer_id = o.customer_id
       WHERE o.status = 'COMPLETED'
       GROUP BY c.company_name
   )
   ```
2. 主查詢直接從 `customer_revenue` 選取，並加上 `WHERE total_spent >= 500000`。
</details>

<details>
<summary>✅ 寫完了？點擊查看標準解答與解析</summary>

```sql
WITH customer_revenue AS (
    SELECT 
        c.company_name, 
        SUM(o.total_amount) AS total_spent
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.status = 'COMPLETED'
    GROUP BY c.company_name
)
SELECT 
    company_name,
    total_spent
FROM customer_revenue
WHERE total_spent >= 500000
ORDER BY total_spent DESC;
```
</details>

> 💡 **第二關核心收斂**：
> **WITH AS 先起頭，逗號串聯多段流；由上而下好維護，單段除錯最順手。**

---

## 第三關：進階 JOIN（選讀，遇到需求再回來看）

> 🎯 **這一節最重要的一件事（心智定位）**：
> 進階 JOIN（SELF / FULL OUTER / CROSS / LATERAL）是處理層級結構、雙向對帳與網格矩陣運算的特種部隊。
>
> 💼 **為什麼非學不可（避坑痛點）**：
> 遇到「兩個資料庫系統月底雙向對帳」或「同一表中的員工與主管關係」，一般的 INNER/LEFT JOIN 會遺漏一側資料或語意不清，進階 JOIN 能精確掌控兩側資料流向。

> 以下的 JOIN 類型在日常查詢中比較少見，但在特定場景非常有用。
> 建議先把第一、二關練熟，再來看這一部分。

---

### 3.1 SELF JOIN — 一張表和自己比較

**使用場景**：同一張 `customers` 表裡，找同產業的客戶配對

```sql
-- 找出同產業、信用額度差距超過 100 萬的客戶配對
SELECT
    a.industry      AS 產業,
    a.company_name  AS 客戶A,
    a.credit_limit  AS A額度,
    b.company_name  AS 客戶B,
    b.credit_limit  AS B額度
FROM customers a
JOIN customers b
    ON a.industry = b.industry
    AND a.customer_id < b.customer_id        -- 避免 (A,B) 和 (B,A) 重複
    AND ABS(a.credit_limit - b.credit_limit) > 1000000
WHERE a.status = 'ACTIVE' AND b.status = 'ACTIVE'
ORDER BY a.industry;
```

> 💡 `a.customer_id < b.customer_id` 是關鍵技巧：讓 A 的 ID 一定比 B 小，就不會出現兩個方向的重複配對

---

### 3.2 FULL OUTER JOIN — 兩邊都保留

**使用場景**：對帳、找兩個系統之間的差異

| JOIN 類型       | 保留誰                                      |
| --------------- | ------------------------------------------- |
| LEFT JOIN       | 左表全保留，右表配不上的顯示 NULL           |
| RIGHT JOIN      | 右表全保留，左表配不上的顯示 NULL           |
| FULL OUTER JOIN | **兩邊都保留**，互相沒有的都顯示 NULL |

```sql
-- 對帳情境：找出兩份名單的差異
SELECT
    COALESCE(a.customer_id::text, '（無）') AS 舊系統ID,
    COALESCE(b.customer_id::text, '（無）') AS 新系統ID,
    CASE
        WHEN a.customer_id IS NULL THEN '新系統有，舊系統沒有'
        WHEN b.customer_id IS NULL THEN '舊系統有，新系統沒有'
        ELSE '兩邊都有'
    END AS 差異狀態
FROM customers a
FULL OUTER JOIN customers b ON a.customer_id = b.customer_id;
```

---

### 3.3 CROSS JOIN — 產生所有組合

**使用場景**：生成「所有月份 × 所有業務」的報表骨架

```sql
WITH
months AS (
    SELECT generate_series('2024-01-01'::date, '2024-12-01'::date, '1 month')::date AS month_start
),
all_sp AS (
    SELECT salesperson_id, name FROM salespeople
)
-- 骨架：每位業務 × 每個月都有一列（12 個月 × N 位業務）
SELECT
    m.month_start,
    sp.name
FROM months m
CROSS JOIN all_sp sp
ORDER BY m.month_start, sp.name;
```

> 💡 **為什麼需要這個骨架？** 如果某位業務某月沒有業績，直接 GROUP BY 就不會有那一列。先建立骨架、再 LEFT JOIN 業績，就能讓「無業績的月份顯示 0」而非消失。

---

### 3.4 LATERAL — 每列各自跑子查詢

**使用場景**：取「每位客戶最近 3 筆訂單」這種「每行 Top N」需求

```sql
SELECT
    c.company_name,
    recent.order_number,
    recent.order_date,
    recent.total_amount,
    recent.rank_no AS 最近第幾筆
FROM customers c
CROSS JOIN LATERAL (
    -- 這個子查詢可以引用外層的 c.customer_id
    SELECT
        o.order_number, o.order_date, o.total_amount,
        ROW_NUMBER() OVER (ORDER BY o.order_date DESC) AS rank_no
    FROM orders o
    WHERE o.customer_id = c.customer_id
      AND o.status = 'COMPLETED'
    ORDER BY o.order_date DESC
    LIMIT 3
) AS recent
WHERE c.status = 'ACTIVE'
ORDER BY c.company_name, recent.rank_no;
```

---

## 本章練習題（循序漸進）

---

### 🟢 練習 1（純量子查詢）

**需求**：列出所有 COMPLETED 的訂單，並且顯示：

- 訂單金額
- 全體 COMPLETED 訂單的平均金額
- 該筆訂單「是否高於平均」（TRUE / FALSE）

<details>
<summary>💡 提示（點開看）</summary>

- 純量子查詢放在 SELECT 裡，計算 AVG(total_amount)
- `total_amount > (SELECT AVG... )` 會回傳 TRUE/FALSE

</details>

<details>
<summary>🎯 參考解答（點開看）</summary>

```sql
SELECT
    order_number                                               AS 訂單編號,
    total_amount                                               AS 訂單金額,
    ROUND((
        SELECT AVG(total_amount) 
        FROM orders 
        WHERE status = 'COMPLETED'
    ), 2)                                                      AS 全體平均金額,
    (total_amount > (
        SELECT AVG(total_amount) 
        FROM orders 
        WHERE status = 'COMPLETED'
    ))                                                         AS 是否高於平均
FROM orders
WHERE status = 'COMPLETED'
ORDER BY total_amount DESC;
```

</details>

---

### 🟢 練習 2（表格子查詢）

**需求**：找出每個「產業別」裡，消費金額最高的那一家客戶

<details>
<summary>💡 提示（點開看）</summary>

步驟拆解：

1. 先用子查詢算出「每個產業的最高消費金額」（GROUP BY industry）
2. 再 JOIN 回去找出是哪家客戶

</details>

<details>
<summary>🎯 參考解答（點開看）</summary>

```sql
SELECT
    cust_total.industry,
    cust_total.company_name,
    cust_total.total_spent
FROM (
    -- 子查詢 1：計算每位客戶在 COMPLETED 訂單的總消費
    SELECT
        c.customer_id,
        c.company_name,
        c.industry,
        SUM(o.total_amount) AS total_spent
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.status = 'COMPLETED'
    GROUP BY c.customer_id, c.company_name, c.industry
) cust_total
JOIN (
    -- 子查詢 2：計算各產業別的「最高消費金額」
    SELECT
        industry,
        MAX(total_spent) AS max_spent
    FROM (
        SELECT
            c.industry,
            SUM(o.total_amount) AS total_spent
        FROM customers c
        JOIN orders o ON c.customer_id = o.customer_id
        WHERE o.status = 'COMPLETED'
        GROUP BY c.customer_id, c.industry
    ) t
    GROUP BY industry
) ind_max
  ON cust_total.industry = ind_max.industry
 AND cust_total.total_spent = ind_max.max_spent
ORDER BY cust_total.total_spent DESC;
```

> 💡 *進階提示：這題在學完下一章 [02 Window Functions](./02_Window_Functions全解析.md) 的 `ROW_NUMBER()` 或 `DENSE_RANK()` 後，可以用更簡潔的語法完成！*

</details>

---

### 🟡 練習 3（基本 CTE）

**需求**：找出「有 COMPLETED 訂單，且信用額度超過 50 萬」的客戶，列出其公司名稱、產業、總消費金額

<details>
<summary>💡 提示（點開看）</summary>

用一段 CTE 先算每位客戶的總消費，再在外層加上 `credit_limit > 500000` 的篩選

</details>

<details>
<summary>🎯 參考解答（點開看）</summary>

```sql
WITH customer_spending AS (
    SELECT
        c.customer_id,
        c.company_name,
        c.industry,
        c.credit_limit,
        SUM(o.total_amount) AS total_spent
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.status = 'COMPLETED'
    GROUP BY c.customer_id, c.company_name, c.industry, c.credit_limit
)
SELECT
    company_name AS 客戶名稱,
    industry     AS 產業,
    credit_limit AS 信用額度,
    total_spent  AS 總消費金額
FROM customer_spending
WHERE credit_limit > 500000
ORDER BY total_spent DESC;
```

</details>

---

### 🟡 練習 4（多段 CTE）

**需求**：

- 第一段 CTE：算出每位業務的總業績
- 第二段 CTE：算出全體業務的平均業績
- 最終查詢：列出高於平均業績的業務，並顯示「超出均值百分比」

<details>
<summary>💡 提示（點開看）</summary>

結構：

```sql
WITH
salesperson_revenue AS (...),   -- 每位業務的業績
avg_revenue AS (                -- 從第一段算均值
    SELECT AVG(total) FROM salesperson_revenue
)
SELECT ... FROM salesperson_revenue, avg_revenue ...
```

</details>

<details>
<summary>🎯 參考解答（點開看）</summary>

```sql
WITH
-- 第 1 段：每位業務員的總業績
salesperson_revenue AS (
    SELECT
        s.salesperson_id,
        s.name              AS salesperson_name,
        SUM(o.total_amount) AS total_revenue
    FROM salespeople s
    JOIN orders o ON s.salesperson_id = o.salesperson_id
    WHERE o.status = 'COMPLETED'
    GROUP BY s.salesperson_id, s.name
),
-- 第 2 段：全體業務的平均業績（以第 1 段為基礎）
avg_revenue AS (
    SELECT AVG(total_revenue) AS avg_sales
    FROM salesperson_revenue
)
-- 最終查詢：篩選高於平均者並計算百分比
SELECT
    sr.salesperson_name                                                AS 業務員,
    sr.total_revenue                                                   AS 總業績,
    ROUND(ar.avg_sales, 2)                                            AS 全體平均業績,
    ROUND(((sr.total_revenue - ar.avg_sales) / ar.avg_sales) * 100, 2) AS 超出均值百分比
FROM salesperson_revenue sr
CROSS JOIN avg_revenue ar
WHERE sr.total_revenue > ar.avg_sales
ORDER BY sr.total_revenue DESC;
```

</details>

---

### 🔴 練習 5（綜合應用）

**需求**：行銷部門想找出「從未購買過 Hardware 類別產品」的 ACTIVE 客戶名單，準備針對他們推播硬體促銷廣告。

<details>
<summary>💡 提示（點開看）</summary>

- 用 `NOT EXISTS` 而非 `NOT IN`（避免 NULL 陷阱）
- 需要 JOIN orders → order_items → products 來確認類別

</details>

<details>
<summary>🎯 參考解答（點開看）</summary>

```sql
SELECT
    c.customer_id   AS 客戶ID,
    c.company_name  AS 客戶名稱,
    c.industry      AS 產業
FROM customers c
WHERE c.status = 'ACTIVE'
  AND NOT EXISTS (
      -- 檢查該客戶是否存在任何一筆購買 Hardware 類別的 COMPLETED 訂單明細
      SELECT 1
      FROM orders o
      JOIN order_items oi ON o.order_id = oi.order_id
      JOIN products p ON oi.product_id = p.product_id
      WHERE o.customer_id = c.customer_id
        AND o.status = 'COMPLETED'
        AND p.category = 'Hardware'
  )
ORDER BY c.company_name;
```

</details>

> 💡 **第三關核心收斂**：
> **SELF JOIN 查同表層級，FULL OUTER 做雙向對帳；CROSS 生成全網格矩陣，NOT EXISTS 防 NULL 刺客。**

---

## 重點速查卡

### 什麼時候用哪種？

| 需求                                     | 用什麼                                |
| ---------------------------------------- | ------------------------------------- |
| 先算一個基準值（平均、最大），再拿來篩選 | **純量子查詢** 或 **CTE** |
| 要先整理一張表，再拿來 JOIN              | **表格子查詢** 或 **CTE** |
| 邏輯複雜，超過兩層                       | **多段 CTE**（強烈推薦）        |
| 找「存在 / 不存在」的關係                | **EXISTS / NOT EXISTS**         |
| 每列要取 Top N                           | **LATERAL JOIN**                |

### EXISTS vs IN vs JOIN

|           | EXISTS       | IN               | JOIN          |
| --------- | ------------ | ---------------- | ------------- |
| 適用      | 找「有沒有」 | 比對小清單       | 需要右表欄位  |
| NULL 安全 | ✅ 安全      | ⚠️ NOT IN 有坑 | 需加 DISTINCT |
| 效能      | ⭐⭐⭐ 最好  | ⭐⭐ 普通        | ⭐⭐ 視情況   |

---

*下一篇：[02 Window Functions 全解析](./02_Window_Functions全解析.md)*
*— 學完這篇，相關子查詢你幾乎就不需要了，Window Function 更強更快*
