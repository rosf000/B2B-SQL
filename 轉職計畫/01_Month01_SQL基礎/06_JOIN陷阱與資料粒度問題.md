# 06 — JOIN 陷阱與資料粒度問題（Fan-out 深度防坑指南）

> 🎯 **這一節最重要的一件事（心智定位）**：
> 跨表 JOIN 是一對多（1:N）的維度展開；一旦在明細粒度上對主表金額執行 SUM，就會產生致命的 Fan-out 乘數膨脹！
>
> 💼 **為什麼非學不可（避坑痛點）**：
> 某家客戶實際只買了 25 萬，因為 JOIN 了訂單明細，金額瞬間虛胖變成 50 萬。如果你拿著膨脹兩倍的虛假業績報給總經理與財務長，就是嚴重的商業舞弊與誠信事故！

> [!IMPORTANT]
> 本篇範例均基於 **B2B Canonical 資料庫**（`data/b2b_m1_sample_v2.sql`）。
> 建議在 DBeaver 中執行每段 SQL，並對照預期查詢結果確認列數與金額變化。

---

## JOIN Explosion 是什麼？

當你 JOIN 兩張表時，如果關聯是「一對多」，結果的列數會膨脹。

### 基本範例

確認 `orders` 與 `order_items` JOIN 前後的列數變化：

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

> ORD-2024-002 包含 2 個品項，關聯後展開為 2 列符合預期；但若在此粒度下對 `orders.total_amount` 做 SUM，該金額就會被重複計算。

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

若在 JOIN `order_items` 之後，直接對 `orders.total_amount` 進行加總：

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

##### 📊 預期查詢結果（⚠️ 這是錯誤的答案！）

| company_name      |       wrong_total       |
| :---------------- | :---------------------: |
| BlueSky Cloud Ltd | **405000.00** ⚠️ 錯誤！ |

> [!CAUTION]
> **原因分析**：ORD-2024-002 有 2 個品項，JOIN 後其 `total_amount` (155,000) 被重複計算 2 次（計 310,000）。
> ORD-2024-010 只有 1 個品項（計 95,000）。
> 加總結果為 405,000，比正確總額 250,000 虛增了 155,000。

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

> `order_id = 2` 出現了 2 列，且每列的 `total_amount` 皆為 155,000。若對此欄位直接做 SUM，155,000 就會被計算兩次。

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
-- 預期結果：250000.00 ← 與正確答案一致！
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
-- 預期結果：250000.00 ← 同樣正確！
```

---

### 陷阱 2：兩邊都是「多筆」，JOIN 後會互相配對

> **先體驗現象，再認識術語。**

#### ① 先複習 1:N — 受控的展開

陷阱 1 示範的 `orders → order_items` 屬於 **一對多（1:N）**：

```text
1 筆訂單
   └── 2 個品項（item A、item B）

JOIN 後：1 × 2 = 2 列
→ 展開幅度 = 那筆訂單的品項數，這叫做 Fan-out（受控展開）
```

只要你清楚 Grain，1:N 的展開是**可預期的、受控的**。

---

#### ② 再看 N:M — 兩個「多」互相放大

現在換個場景：  
**客戶 1 同時有 3 個標籤（tag）和 2 筆訂單**，  
我們把兩張表都透過 `customer_id` JOIN 回客戶：

**客戶 1 的標籤表（customer_tags）**

| customer_id | tag        |
| :---------: | :--------- |
|      1      | VIP        |
|      1      | Cloud      |
|      1      | Enterprise |

**客戶 1 的訂單表（orders）**

| customer_id | order_id |
| :---------: | :------- |
|      1      | ORD-101  |
|      1      | ORD-102  |

問題來了：

> 如果把 `customer_tags` 和 `orders` 都 JOIN 到 `customer_id = 1`，  
> **一個 tag 會配到幾筆 order？**

答案：**2 筆。** 每一個 tag 都會和每一筆 order 配一次：

```text
VIP          × ORD-101
VIP          × ORD-102

Cloud        × ORD-101
Cloud        × ORD-102

Enterprise   × ORD-101
Enterprise   × ORD-102

→ 3 個 tag × 2 筆 order = 6 列
```

這就是「兩個多互相放大」的核心現象。

---

#### ③ 最後才是術語

| 情況         | 左邊 | 右邊 | JOIN 後 | 是否危險           |
| :----------- | ---: | ---: | ------: | :----------------- |
| 1:1          |    1 |    1 |       1 | 通常不會           |
| 1:N          |    1 |    3 |       3 | ⚠️ Fan-out（受控） |
| N:1          |    3 |    1 |       3 | 通常可預期         |
| **N:M**  | **3** | **2** | **6** | 🚨 N×M 資料膨脹    |
| CROSS JOIN   |    3 |    2 |       6 | 🚨 笛卡兒積        |

> **JOIN 不只是「把兩張表接起來」，而是在決定「一列資料會變成幾列」。**

三個關鍵名詞：

- **1:N Fan-out**：有正確 ON 條件，展開幅度 = 每筆主表資料對應的從表列數加總。13 筆訂單展開成 18 筆，**不是 13×18**，是受控的。
- **N:M 資料膨脹**：兩張表透過同一個 Key 各自對應「多筆」，**兩個「多」互乘**，結果列數 = 左邊 × 右邊，且很難從 SUM 結果察覺。
- **CROSS JOIN（笛卡兒積）**：SQL 中**沒有 ON 條件**的明確語法；左表每一列都和右表每一列配對，結果必然是 N×M。N:M 資料膨脹和 CROSS JOIN 的**症狀相同，但成因不同**，要分開理解。

---

**場景：** 客戶同時有多個標籤（tags）和多筆訂單，兩者都 JOIN 到客戶表（B2B 資料庫無 tags 表，以下為概念示意）

```sql
-- ⚠️ 危險示意：customer_tags（N 列）+ orders（M 列）同時 JOIN 到 customers
-- customer 1 有 3 個 tag、2 筆 orders → 結果：3 × 2 = 6 列
-- 此時 COUNT(order_id) 會回傳 6，而非正確的 2！
-- （customer_tags 表在 B2B 資料庫中不存在，此為示意）
SELECT
    c.customer_id,
    COUNT(o.order_id) AS WRONG_order_count   -- ⚠️ 被 tag 數量放大了！
FROM customers c
JOIN customer_tags ct ON c.customer_id = ct.customer_id    -- 3 倍放大
JOIN orders o        ON c.customer_id = o.customer_id      -- 再 × 2 倍
GROUP BY c.customer_id;
-- 回傳 6，實際上只有 2 筆訂單
```

**修正：加 DISTINCT 去重**

```sql
-- ✅ 用 COUNT(DISTINCT ...) 去除因 tag 展開造成的重複
SELECT
    c.customer_id,
    COUNT(DISTINCT o.order_id) AS correct_order_count   -- DISTINCT 只計唯一值
FROM customers c
JOIN customer_tags ct ON c.customer_id = ct.customer_id
JOIN orders o        ON c.customer_id = o.customer_id
GROUP BY c.customer_id;
-- 回傳 2，正確！
```

> [!TIP]
> 預防 N:M 膨脹的根本方法是**在 JOIN 之前確認每張表的粒度（Grain）**：
> - `orders` 的粒度是「每筆訂單」
> - `customer_tags` 的粒度是「每個標籤」
> - 兩者同時 JOIN 到 `customers` 後，粒度變成「每筆訂單 × 每個標籤」的組合，而非「每筆訂單」。
>
> **只要發現兩張「多」的表都以同一個 Key JOIN 到主表，就必須警戒 N×M 膨脹。**

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
|      4      |      2      |
|      2      |      2      |
|      8      |      2      |

> `customer_id = 1`（Apex Semi Tech）在 orders 表中有 3 筆資料。以 `customer_id` 關聯時展開為 3 列屬於 1:N 關係的正常結果；此時若要進行聚合，不可直接對屬於 1 的端欄位進行金額加總。

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

## 🔬 實戰練習：驗證 JOIN 粒度與膨脹

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

比對 `orders.total_amount` 與 `order_items.subtotal` 加總是否一致：

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
> 若 `diff` 均為 0.00，代表明細小計彙總值與主表訂單金額一致。此類對帳語法常用於檢查資料一致性與業務 Trigger 是否正常運作。

---

## 📋 診斷 JOIN 結果的 SOP

遇到異常聚合結果時的檢查清單：

```
看到 SUM / COUNT 結果時，必問三個問題：

1. JOIN 後，這張查詢的 Grain（粒度）是什麼？
   → 現在每一列代表什麼？（是「每筆訂單」還是「每個訂單品項」？）

2. 我 SUM 的欄位來自哪張表？
   → 那張表在 JOIN 後有沒有被複製出多列？
   → 做個簡單驗證：比對 JOIN 前後的 COUNT(*) 是否相同！

3. 結果比預期大很多嗎？
   → 先 SELECT 幾列原始資料，肉眼確認有無重複列
   → 再用「快速診斷 SQL」做 diff 對帳，數字差異一目了然
```

> 💡 **資料粒度與 JOIN 防坑核心收斂**：
> **多表關聯看基數，1:N 展開必控度；明細表裡算細項，主表總額絕不重 SUM。**

---

### ✋ 粒度防坑空白頁挑戰（不看範例自主對帳）

> **稽核主管抽查**：
> 「請寫一段安全的 SQL，統計 **Apex Semi Tech（`customer_id = 1`）** 的已完成（`COMPLETED`）訂單總額。請分別輸出：
> 1. 直接從 `orders` 表加總的正確總金額 `orders_total`
> 2. JOIN 到 `order_items` 後，加總 `oi.subtotal` 的金額 `items_total`
> 3. 計算兩者的差額 `diff`，以證明你的查詢沒有發生 Fan-out 膨脹。」
>
> ⚠️ **請在 DBeaver 打開空白頁手寫完成，再展開對照！**

<details>
<summary>💡 需要思考提示嗎？（點擊展開解題思路）</summary>

1. 你可以直接在一個查詢中計算，或者使用子查詢 / CTE 分別計算兩表總額再相減。
2. 最簡單的方式：直接對 `orders` 串 `order_items`，但千萬不要對 `o.total_amount` 做 SUM，而是對 `oi.subtotal` 做 SUM！
3. 也可以透過對帳模式，按訂單驗證每筆訂單的 `diff = o.total_amount - SUM(oi.subtotal)` 是否為 0。
</details>

<details>
<summary>✅ 寫完了？點擊查看標準對帳代碼與解析</summary>

```sql
-- 方式 A：訂單層級逐筆對帳（最推薦）
SELECT 
    o.order_id,
    o.order_number,
    o.total_amount AS orders_recorded,
    SUM(oi.subtotal) AS items_calculated,
    o.total_amount - SUM(oi.subtotal) AS diff
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.customer_id = 1 AND o.status = 'COMPLETED'
GROUP BY o.order_id, o.order_number, o.total_amount;
```

**解析**：
- 如果 `diff` 全為 0，代表明細的小計總和與主表記錄的訂單金額完全一致，沒有發生漏算或重複計算。
</details>

---

## 自我測驗

不看答案，試著回答：

- [ ] 為什麼 `JOIN order_items` 後 `SUM(orders.total_amount)` 會變成兩倍？（用 ORD-2024-002 舉例說明）
- [ ] `COUNT(*)` 和 `COUNT(o.order_id)` 在 LEFT JOIN 後有什麼差別？（用 InnoVibe Studio 舉例）
- [ ] 如果懷疑 JOIN 有 Explosion，你會怎麼診斷？（說出 3 個步驟）
- [ ] 1:N JOIN 的 Fan-out（受控展開）與 Many-to-Many 真正笛卡兒積（N×M 爆炸）有什麼差異？

---

## 🔗 下一步與章節導航

- **前一篇**：[05_SQL除錯方法論.md](./05_SQL除錯方法論.md)（除錯自救心法）
- **下一篇（需求拆解）**：[07_SQL商業問題拆解框架.md](./07_SQL商業問題拆解框架.md)（5 Level 拆解思維模板）
- **實戰手寫題庫**：[09_30道B2B商業SQL實戰練習題.md](./09_30道B2B商業SQL實戰練習題.md)（特別推薦 Q21-Q30 跨表實戰與對帳）
- **結業考核**：[10_Exit_Exam_B2B商業數據偵探考題.md](./10_Exit_Exam_B2B商業數據偵探考題.md)（包含 AI JOIN 膨脹抓錯題）
- **回到目錄**：[Month 01 學習模組主導航](./README.md)
