# 05 — JOIN 陷阱與資料粒度問題

> **「JOIN 後資料變兩倍，但你不知道。這是工作中最常見的 SQL 錯誤之一。」**

---

## JOIN Explosion 是什麼？

當你 JOIN 兩張表時，如果關聯是「一對多」，結果的列數會膨脹。

### 基本範例

> 💡【概念示意範例】（此處使用簡化的抽象訂單表說明 1:N 關聯原理；Canonical 資料庫請參閱 `data/b2b_m1_sample.sql`）：

```
customers 表：
customer_id | name
-----------+------
1          | Alice
2          | Bob

orders 表：
order_id | customer_id | amount
--------+-------------+-------
101     | 1           | 100
102     | 1           | 200
103     | 2           | 150
```

JOIN 後：

```sql
-- 【概念示意查詢】
SELECT c.customer_id, c.name, o.amount
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id;
```

結果：
```
customer_id | name  | amount
-----------+-------+-------
1          | Alice | 100    ← Alice 出現兩次（因為有 2 筆訂單）
1          | Alice | 200
2          | Bob   | 150
```

這是**正確**的！因為一個客戶有多筆訂單。

---

## 危險案例：SUM 變成三倍

> 💡【概念示意範例】（展示 1:N 明細關聯對 SUM 的放大效應）：

```
orders 表（3 筆，總金額 = 450）：
order_id | amount
--------+-------
101     | 100
102     | 200
103     | 150

order_items 表（每筆訂單有 2 個商品）：
order_id | product_id | qty
--------+-----------+----
101     | A          | 2
101     | B          | 3
102     | C          | 1
102     | A          | 4
103     | B          | 2
103     | D          | 1
```

**錯誤 SQL：**

```sql
-- ⚠️ 這條 SQL 結果是錯的！
-- 【概念示意】：若以 orders.total_amount（此處以概念欄位 amount 示意）直接在 JOIN order_items 後加總：
SELECT
    o.customer_id,
    SUM(o.amount) AS total_revenue      -- 問題在這裡：被 order_items 的行數重複放大
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.customer_id;
```

為什麼錯？

```
JOIN 後，orders 101 的 amount=100 被重複了 2 次（因為 101 有 2 個 order_items）
orders 102 的 amount=200 被重複了 2 次
orders 103 的 amount=150 被重複了 2 次

SUM 結果 = (100+100) + (200+200) + (150+150) = 900
正確結果 = 100 + 200 + 150 = 450

→ 結果是正確值的 2 倍！
```

---

## 四種常見 JOIN 陷阱

### 陷阱 1：一對多導致 SUM 膨脹

**症狀：** SUM 的結果遠大於預期

**診斷（可直接在 Canonical 資料庫執行）：**
```sql
-- 先不 GROUP BY，看 JOIN 後的原始資料
SELECT o.order_id, o.total_amount, oi.product_id
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
LIMIT 20;
-- 看看同一個 order_id 出現幾次
```

**修正方法（Canonical 資料庫適用）：**
```sql
-- 方法 1：先 SUM order_items，再 JOIN（CTE 預先聚合，Month 02 會深入解析 CTE）
WITH order_totals AS (
    SELECT order_id, SUM(subtotal) AS line_total
    FROM order_items
    GROUP BY order_id
)
SELECT o.customer_id, SUM(ot.line_total) AS total_revenue
FROM orders o
JOIN order_totals ot ON o.order_id = ot.order_id
GROUP BY o.customer_id;

-- 方法 2：直接從 order_items 計算，不碰 orders.total_amount
SELECT o.customer_id, SUM(oi.subtotal) AS total_revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.customer_id;
```

---

### 陷阱 2：Many-to-Many 造成笛卡兒積

**場景：** 客戶有多個標籤（tags），訂單也有多個標籤

```sql
-- ⚠️ 危險：customers (N tags) JOIN orders (M tags)
-- 結果是 N × M 列！
SELECT c.customer_id, COUNT(o.order_id) AS order_count
FROM customers c
JOIN customer_tags ct ON c.customer_id = ct.customer_id
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id;
-- 每個訂單被計算了 N 次（N = 客戶的標籤數）
```

**修正：**
```sql
-- 分開處理，或先 DISTINCT
SELECT c.customer_id, COUNT(DISTINCT o.order_id) AS order_count  -- DISTINCT 去重
FROM customers c
JOIN customer_tags ct ON c.customer_id = ct.customer_id
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id;
```

---

### 陷阱 3：JOIN Key 不唯一

**場景：** 以為 FK 是唯一的，但其實有重複

```sql
-- 先確認 JOIN Key 是否唯一
SELECT customer_id, COUNT(*) AS count
FROM orders
GROUP BY customer_id
HAVING COUNT(*) > 1;
-- 如果有結果，代表 customer 對應多筆 orders，JOIN 會膨脹
```

---

### 陷阱 4：LEFT JOIN 後 NULL 被 COUNT 計入

```sql
-- ⚠️ 這個 COUNT 包含了沒有訂單的客戶
SELECT c.customer_id, COUNT(o.order_id) AS order_count
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id;

-- 沒有訂單的客戶：order_id = NULL → COUNT(o.order_id) = 0 ← 這是對的

-- 但如果你這樣寫：
SELECT c.customer_id, COUNT(*) AS order_count  -- ⚠️ COUNT(*) 算 NULL！
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id;
-- 沒有訂單的客戶會被計為 1（因為 COUNT(*) 計算列數，不管是不是 NULL）
```

**規則：LEFT JOIN 後，COUNT 要用 `COUNT(column_name)`，不要用 `COUNT(*)`**

---

## 實戰練習：找出 JOIN Explosion

```sql
-- 練習 1：驗證你的 JOIN 沒有膨脹
-- 比較 JOIN 前後的列數

-- JOIN 前
SELECT COUNT(*) FROM orders;  -- 應該是 N 筆

-- JOIN 後（如果是一對多，應該 >= N 筆）
SELECT COUNT(*) FROM orders o JOIN order_items oi ON o.order_id = oi.order_id;

-- 如果 JOIN 後列數 >> JOIN 前，要小心 SUM 計算！
```

```sql
-- 練習 2：找出 JOIN 後的重複問題
-- 檢查哪些 order_id 在 JOIN 後出現最多次
SELECT o.order_id, COUNT(*) AS times_repeated
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_id
ORDER BY times_repeated DESC
LIMIT 10;
```

---

## 診斷 JOIN 結果的 SOP

```
看到 SUM / COUNT 結果時，必問三個問題：

1. JOIN 後，這張查詢的 Grain 是什麼？
   → 每列代表什麼？

2. 我 SUM 的欄位在哪張表？
   → 這張表在 JOIN 後有沒有被重複？

3. 結果比預期大很多嗎？
   → 試著 SELECT 幾列原始資料，確認有沒有重複
```

---

## 快速診斷 SQL
```sql
-- 當你懷疑 JOIN 有問題，用這個模式在 Canonical 資料庫確認：

SELECT
    o.order_id,
    o.total_amount,                          -- orders 表的 total_amount
    COUNT(oi.item_id) AS item_count,         -- 有幾個 order_items
    SUM(oi.subtotal) AS calculated_amount    -- 由明細彙總出的金額
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_id, o.total_amount
ORDER BY o.order_id
LIMIT 10;

-- 如果 orders.total_amount 和 calculated_amount 差很多，就有問題
```

---

## 自我測驗

不看答案，試著回答：

- [ ] 為什麼 `JOIN order_items` 後 `SUM(orders.total_amount)` 會變成兩倍？
- [ ] `COUNT(*)` 和 `COUNT(column_name)` 在 LEFT JOIN 後有什麼差別？
- [ ] 如果懷疑 JOIN 有 Explosion，你會怎麼診斷？
- [ ] 什麼情況下 Many-to-Many JOIN 會造成「笛卡兒積」？

---

## 🔗 下一步與章節導航

- **前一篇**：[04_SQL商業問題拆解框架.md](./04_SQL商業問題拆解框架.md)（5 Level 拆解思維模板）
- **下一篇（全面排錯）**：[07_SQL除錯方法論.md](./07_SQL除錯方法論.md)（Syntax / Logic / Data 三型態排錯指南）
- **實戰手寫題庫**：[06_30道B2B商業SQL實戰練習題.md](./06_30道B2B商業SQL實戰練習題.md)（特別推薦 Q21-Q30 跨表實戰與對賬）
- **結業考核**：[10_Exit_Exam_B2B商業數據偵探考題.md](./10_Exit_Exam_B2B商業數據偵探考題.md)（包含 AI JOIN 膨脹抓錯題）
- **回到目錄**：[Month 01 學習模組主導航](./README.md)
