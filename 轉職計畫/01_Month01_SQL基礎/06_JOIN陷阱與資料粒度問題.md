# 06 — JOIN 陷阱與資料粒度問題（Fan-out 深度防坑指南）

> **「JOIN 後資料變兩倍，但你不知道。這是工作中最常見的 SQL 錯誤之一。」**

> [!IMPORTANT]
> 本篇所有範例均使用 **你的 B2B Canonical 資料庫**（`data/b2b_m1_sample_v2.sql`）。
> 請在 DBeaver 中執行每段 SQL，對照【預期查詢結果】親身感受 JOIN 爆炸發生的瞬間！

---

## JOIN Explosion 是什麼？

當你 JOIN 兩張表時，如果關聯是「一對多」，結果的列數會膨脹。

### 基本範例（可直接執行）

> 💡 讓我們先看 `orders` ×  `order_items` JOIN 後，**同一筆訂單的 `total_amount` 會出現幾次**：

```sql
-- 【Step 1】先確認 orders 有幾筆
SELECT COUNT(*) AS orders_count FROM orders;
-- 預期結果：13

-- 【Step 2】JOIN order_items 後，看看列數怎麼了
SELECT COUNT(*) AS after_join_count
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id;
-- 預期結果：18  ← 從 13 膨脹到 18！
```

#### 📊 為什麼從 13 變 18？

```sql
-- 看看每筆訂單在 JOIN 後出現了幾次
SELECT
    o.order_id,
    o.order_number,
    o.total_amount,
    COUNT(oi.item_id) AS times_repeated   -- 這筆訂單有幾個 order_items
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_id, o.order_number, o.total_amount
ORDER BY o.order_id;
```

##### 📊 預期查詢結果

| order_id | order_number | total_amount |       times_repeated       |
| :------: | :----------- | :----------: | :------------------------: |
|    1    | ORD-2024-001 |  360000.00  |        **1**        |
|    2    | ORD-2024-002 |  155000.00  | **2** ← 出現 2 次！ |
|    3    | ORD-2024-003 |  240000.00  |        **1**        |
|    4    | ORD-2024-004 |   80000.00   | **2** ← 出現 2 次！ |
|    5    | ORD-2024-005 |   60000.00   |        **1**        |
|    6    | ORD-2024-006 |  190000.00  |        **1**        |
|    7    | ORD-2024-007 |  450000.00  | **2** ← 出現 2 次！ |
|    8    | ORD-2024-008 |   60000.00   |        **1**        |
|    9    | ORD-2024-009 |  135000.00  |        **1**        |
|    10    | ORD-2024-010 |   95000.00   |        **1**        |
|    11    | ORD-2024-011 |  170000.00  | **2** ← 出現 2 次！ |
|    12    | ORD-2024-012 |  290000.00  | **2** ← 出現 2 次！ |
|    13    | ORD-2024-013 |  120000.00  |        **1**        |

> **這是正確的！** 因為 ORD-2024-002 這筆訂單有 2 個品項（Cloud CRM + 分析套件），
> JOIN 後它就自然出現 2 列。**問題在於你如果對 `total_amount` 做 SUM，就會把它算兩遍！**

---

## ⚠️ 危險案例：SUM 變成兩倍（真實可驗證）

我們以 **BlueSky Cloud Ltd（customer_id = 2）** 為例，他們有 3 筆訂單：

```sql
-- 先確認 BlueSky Cloud 的訂單正確總額
SELECT
    c.company_name,
    SUM(o.total_amount) AS correct_total
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE c.company_name = 'BlueSky Cloud Ltd'
  AND o.status = 'COMPLETED'
GROUP BY c.company_name;
```

##### 📊 預期查詢結果（正確答案）

| company_name      |    correct_total    |
| :---------------- | :-----------------: |
| BlueSky Cloud Ltd | **250000.00** |

> 計算過程：ORD-2024-002（155,000）+ ORD-2024-010（95,000）+ 其餘已完成訂單

---

現在，**刻意犯錯**：加入 `order_items` JOIN 後，不假思索地對 `orders.total_amount` 做 SUM：

```sql
-- ⚠️ 這條 SQL 結果是錯的！（Fan-out 陷阱示範）
SELECT
    c.company_name,
    SUM(o.total_amount) AS WRONG_total     -- 問題在這裡！
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id    -- 加了這行後就爆炸
WHERE c.company_name = 'BlueSky Cloud Ltd'
  AND o.status = 'COMPLETED'
GROUP BY c.company_name;
```

##### 📊 預期查詢結果（被放大的錯誤答案）

| company_name      |                   WRONG_total                   |
| :---------------- | :---------------------------------------------: |
| BlueSky Cloud Ltd | **≠ 345000** ← 執行後自行記錄這個數字！ |

> [!CAUTION]
> **為什麼錯？** ORD-2024-002 這筆訂單有 2 筆紀錄，
> JOIN 後它的 `total_amount = 155000` 被計算了 **2 次**（155000 × 2 = 310000）。
> ORD-2024-010 只有 1 個品項，所以 95000 只算 1 次。
> 最終 SUM = 310000 + 95000 = **405000**（比正確值多了 60000！）

---

## 四種常見 JOIN 陷阱

### 陷阱 1：一對多導致 SUM 膨脹

**症狀：** SUM 的結果遠大於預期（以倍數放大）

**診斷方法（先不 GROUP BY，看 JOIN 後的原始資料）：**

```sql
-- 🔍 診斷步驟：先 SELECT 幾列原始 JOIN 結果，確認重複情況
SELECT
    o.order_id,
    o.order_number,
    o.total_amount,      -- orders 表的總額
    oi.item_id,
    oi.product_id,
    oi.subtotal          -- order_items 表的小計
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
ORDER BY o.order_id
LIMIT 10;
```

##### 📊 預期查詢結果（前 10 列）

| order_id | order_number | total_amount | item_id | product_id | subtotal |
| :------: | :----------- | :----------: | :-----: | :--------: | :-------: |
|    1    | ORD-2024-001 |  360000.00  |    1    |     1     | 360000.00 |
|    2    | ORD-2024-002 |  155000.00  |    2    |     3     | 60000.00 |
|    2    | ORD-2024-002 |  155000.00  |    3    |     4     | 95000.00 |
|    3    | ORD-2024-003 |  240000.00  |    4    |     1     | 240000.00 |
|    4    | ORD-2024-004 |   80000.00   |    5    |     2     | 45000.00 |
|    4    | ORD-2024-004 |   80000.00   |    6    |     5     | 35000.00 |
|    5    | ORD-2024-005 |   60000.00   |    7    |     3     | 60000.00 |
|    6    | ORD-2024-006 |  190000.00  |    8    |     4     | 190000.00 |
|    7    | ORD-2024-007 |  450000.00  |    9    |     1     | 360000.00 |
|    7    | ORD-2024-007 |  450000.00  |   10   |     2     | 90000.00 |

> 👆 **一眼就看出問題**：order_id = 2 出現了 **2 列**，
> 而 `total_amount = 155000` 在兩列中都是一樣的。
> 如果你對 `total_amount` 做 SUM，155000 就會被算兩次！

---

**正確修正方法（二選一）：**

```sql
-- ✅ 方法 1：不碰 orders.total_amount，直接從 order_items 的 subtotal 加總
-- （order_items.subtotal 是每個品項的小計，天然沒有重複問題）
SELECT
    c.company_name,
    SUM(oi.subtotal) AS correct_total_from_items
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE c.company_name = 'BlueSky Cloud Ltd'
  AND o.status = 'COMPLETED'
GROUP BY c.company_name;
-- 預期結果：345000.00 ← 與正確答案一致！
```

```sql
-- ✅ 方法 2：用 CTE 先把 order_items 聚合完，再 JOIN（Month 02 會深入解析 CTE）
WITH order_line_totals AS (
    SELECT order_id, SUM(subtotal) AS line_total
    FROM order_items
    GROUP BY order_id
)
SELECT
    c.company_name,
    SUM(olt.line_total) AS correct_total_from_cte
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_line_totals olt ON o.order_id = olt.order_id
WHERE c.company_name = 'BlueSky Cloud Ltd'
  AND o.status = 'COMPLETED'
GROUP BY c.company_name;
-- 預期結果：345000.00 ← 同樣正確！
```

---

### 陷阱 2：Many-to-Many 造成笛卡兒積

**場景：** 客戶有多個標籤（tags），訂單也有多個標籤（本 B2B 資料庫未建 tags 表，以下為示意）

```sql
-- ⚠️ 示意危險：customers (N tags) JOIN orders (M tags)
-- 結果是 N × M 列！
-- （此為概念示意，customer_tags 表在 B2B 資料庫中不存在）
SELECT c.customer_id, COUNT(o.order_id) AS order_count
FROM customers c
JOIN customer_tags ct ON c.customer_id = ct.customer_id    -- N 倍放大
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id;
-- 每個訂單被計算了 N 次（N = 客戶的標籤數）
```

**修正：**

```sql
-- 分開處理，或先 DISTINCT 去重
SELECT c.customer_id, COUNT(DISTINCT o.order_id) AS order_count  -- DISTINCT 去重
FROM customers c
JOIN customer_tags ct ON c.customer_id = ct.customer_id
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id;
```

> [!TIP]
> 💡 在 B2B 資料庫中遇到 Many-to-Many 的最佳預防方式：查詢前先確認每張表的「粒度（Grain）」——這張表的**每一列代表什麼**？`orders` 的粒度是「每筆訂單」，`order_items` 的粒度是「每筆訂單的每個品項」，兩者 JOIN 後的粒度就變成「每個品項」，而非「每筆訂單」。

---

### 陷阱 3：JOIN Key 不唯一

**診斷（可直接在 B2B 資料庫執行）：**

```sql
-- 先確認 JOIN Key 是否唯一（customer_id 在 orders 中是否重複）
SELECT
    customer_id,
    COUNT(*) AS order_count
FROM orders
GROUP BY customer_id
HAVING COUNT(*) > 1
ORDER BY order_count DESC;
```

##### 📊 預期查詢結果

| customer_id | order_count |
| :---------: | :---------: |
|      1      |      3      |
|      2      |      2      |
|      4      |      2      |
|      8      |      2      |

> 👆 **這說明什麼？**
>
> - customer_id = 1（Apex Semi Tech）在 orders 表中出現了 3 次
> - 如果你以 `customer_id` 做 JOIN key，每個客戶的 orders 會膨脹成 3 列
> - 這不是 Bug，是 1:N 關係的正常現象——但你必須知道 JOIN 後 SUM 就不能直接用了！

---

### 陷阱 4：LEFT JOIN 後 NULL 被 COUNT 計入

```sql
-- ✅ 正確：COUNT(o.order_id) 只計算有訂單的客戶
SELECT
    c.customer_id,
    c.company_name,
    COUNT(o.order_id) AS order_count   -- ← 正確：NULL 不會被計入
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.company_name
ORDER BY c.customer_id;
```

```sql
-- ⚠️ 陷阱：COUNT(*) 把沒有訂單的客戶也算成 1
SELECT
    c.customer_id,
    c.company_name,
    COUNT(*) AS WRONG_order_count      -- ← 錯誤：沒有訂單的客戶也被計為 1
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.company_name
ORDER BY c.customer_id;
```

##### 📊 兩種寫法的結果對比（重點看最後兩列）

| customer_id | company_name                 | COUNT(o.order_id) ✅ |      COUNT(*) ⚠️      |
| :----------: | :--------------------------- | :------------------: | :---------------------: |
|      1      | Apex Semi Tech               |          3          |            3            |
|      2      | BlueSky Cloud Ltd            |          3          |            3            |
|     ...     | ...                          |         ...         |           ...           |
| **9** | **InnoVibe Studio**    |    **0** ✅    | **1** ⚠️ 錯誤！ |
| **10** | **Jovial Media Group** |    **0** ✅    | **1** ⚠️ 錯誤！ |

> [!CAUTION]
> **規則：LEFT JOIN 後，COUNT 要用 `COUNT(column_name)`，不要用 `COUNT(*)`。**
> InnoVibe Studio 和 Jovial Media Group 都沒有下過訂單，
> `COUNT(o.order_id)` 正確顯示為 0；
> `COUNT(*)` 卻因為 LEFT JOIN 補了一列 NULL 而算成 1，造成統計失真！

---

## 🔬 實戰練習：完整驗證 JOIN Explosion

```sql
-- 練習 1：驗證你的 JOIN 沒有膨脹
-- 比較 JOIN 前後的列數

-- JOIN 前
SELECT COUNT(*) AS orders_before_join FROM orders;
-- 預期結果：13

-- JOIN 後（應 >= 13，因為有的訂單有多個品項）
SELECT COUNT(*) AS orders_after_join
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id;
-- 預期結果：18 ← 膨脹了 5 列（對應 5 個「有多個品項」的訂單）
```

```sql
-- 練習 2：找出 JOIN 後重複次數最多的訂單（排行榜）
SELECT
    o.order_id,
    o.order_number,
    o.total_amount,
    COUNT(*) AS times_repeated
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_id, o.order_number, o.total_amount
ORDER BY times_repeated DESC
LIMIT 5;
```

##### 📊 預期查詢結果

| order_id | order_number | total_amount | times_repeated |
| :------: | :----------- | :----------: | :------------: |
|    2    | ORD-2024-002 |  155000.00  |       2       |
|    4    | ORD-2024-004 |   80000.00   |       2       |
|    7    | ORD-2024-007 |  450000.00  |       2       |
|    11    | ORD-2024-011 |  170000.00  |       2       |
|    12    | ORD-2024-012 |  290000.00  |       2       |

---

## 🔎 快速診斷 SQL：對帳驗證

> 這是你以後工作中懷疑 JOIN 有問題時的「標準驗證模板」：

```sql
-- 一次性對帳：orders.total_amount 與由 order_items 加總出的值是否一致？
SELECT
    o.order_id,
    o.order_number,
    o.total_amount    AS orders_recorded,       -- orders 表記錄的金額
    SUM(oi.subtotal)  AS items_calculated,      -- 由明細彙總出的金額
    o.total_amount - SUM(oi.subtotal) AS diff   -- 差異（應為 0）
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_id, o.order_number, o.total_amount
ORDER BY o.order_id;
```

##### 📊 預期查詢結果

| order_id | order_number | orders_recorded | items_calculated |      diff      |
| :------: | :----------- | :-------------: | :--------------: | :------------: |
|    1    | ORD-2024-001 |    360000.00    |    360000.00    | **0.00** |
|    2    | ORD-2024-002 |    155000.00    |    155000.00    | **0.00** |
|    3    | ORD-2024-003 |    240000.00    |    240000.00    | **0.00** |
|    4    | ORD-2024-004 |    80000.00    |     80000.00     | **0.00** |
|   ...   | ...          |       ...       |       ...       | **0.00** |

> [!TIP]
> 💡 **如果 diff 欄位全部是 0.00**，代表你的 B2B 資料庫的 Trigger 運作正常——
> `order_items` 的小計彙總值與 `orders.total_amount` 完全吻合！
> 這也是一個很好的「資料品質驗證 SQL」，在業界的對帳報告中天天都會用到。

---

## 📋 診斷 JOIN 結果的 SOP

```
看到 SUM / COUNT 結果時，必問三個問題：

1. JOIN 後，這張查詢的 Grain（粒度）是什麼？
   → 現在每一列代表什麼？（是「每筆訂單」還是「每個訂單品項」？）

2. 我 SUM 的欄位在哪張表？
   → 這張表在 JOIN 後有沒有被重複？
   → 用 COUNT(*) vs JOIN 前的 COUNT(*) 比一下！

3. 結果比預期大很多嗎？
   → 試著 SELECT 幾列原始資料確認有無重複
   → 用「快速診斷 SQL」做 diff 對帳
```

---

## 自我測驗

不看答案，試著回答：

- [ ] 為什麼 `JOIN order_items` 後 `SUM(orders.total_amount)` 會變成兩倍？（用 ORD-2024-002 舉例說明）
- [ ] `COUNT(*)` 和 `COUNT(o.order_id)` 在 LEFT JOIN 後有什麼差別？（用 InnoVibe Studio 舉例）
- [ ] 如果懷疑 JOIN 有 Explosion，你會怎麼診斷？（說出 3 個步驟）
- [ ] 什麼情況下 Many-to-Many JOIN 會造成「笛卡兒積」？

---

## 🔗 下一步與章節導航

- **前一篇**：[05_SQL除錯方法論.md](./05_SQL除錯方法論.md)（除錯自救心法）
- **下一篇（需求拆解）**：[07_SQL商業問題拆解框架.md](./07_SQL商業問題拆解框架.md)（5 Level 拆解思維模板）
- **實戰手寫題庫**：[09_30道B2B商業SQL實戰練習題.md](./09_30道B2B商業SQL實戰練習題.md)（特別推薦 Q21-Q30 跨表實戰與對帳）
- **結業考核**：[10_Exit_Exam_B2B商業數據偵探考題.md](./10_Exit_Exam_B2B商業數據偵探考題.md)（包含 AI JOIN 膨脹抓錯題）
- **回到目錄**：[Month 01 學習模組主導航](./README.md)
