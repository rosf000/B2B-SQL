# 05 — SQL 除錯方法論（初學報錯自救 SOP）

> **AI 時代，寫 SQL 越來越容易；但判斷 SQL 是否正確，越來越重要。**
> 這是你不能外包給 AI 的核心能力。

---

## SQL 錯誤的三種類型

```
Type 1：Syntax Error   → SQL 跑不起來
Type 2：Logic Error    → SQL 跑得起來，但結果是錯的
Type 3：Data Error     → SQL 和邏輯都對，但資料本身有問題
```

**Type 2 和 Type 3 比 Type 1 危險 10 倍**，因為你不知道結果是錯的。

---

## Type 1 — Syntax Error（語法錯誤）

SQL 無法執行，會直接報錯。

### 常見症狀

```sql
-- 錯誤 1：拼錯關鍵字
SELEC * FROM customers;
-- ERROR: syntax error at or near "SELEC"

-- 錯誤 2：忘記逗號
SELECT customer_id name FROM customers;  -- name 被解讀為 alias
-- 不會報錯，但 customer_id 的 alias 變成 name

-- 錯誤 3：字串用雙引號（PostgreSQL 要用單引號）
SELECT * FROM customers WHERE country = "Taiwan";
-- ERROR: column "Taiwan" does not exist

-- 錯誤 4：GROUP BY 沒包含所有 SELECT 的非聚合欄位
SELECT customer_id, status, SUM(total_amount)
FROM orders
GROUP BY customer_id;
-- ERROR: column "orders.status" must appear in the GROUP BY clause or be used in an aggregate function

-- 錯誤 5：JOIN 條件寫錯
SELECT * FROM orders JOIN customers;
-- ERROR: JOIN requires ON or USING
```

### 診斷流程

```
1. 看錯誤訊息，找 "at or near" 的位置
2. 檢查錯誤行的前一行（錯誤通常在上一行末尾）
3. 確認：關鍵字大小寫、引號、逗號、括號是否對稱
4. 把 SQL 縮短，從最小的片段開始跑，逐步加回
```

---

## Type 2 — Logic Error（邏輯錯誤）

SQL 成功執行，但結果不符合業務需求。

### 常見症狀

#### 2a：NULL 陷阱

```sql
-- 想找「不是台灣」的客戶
SELECT * FROM customers WHERE country != 'Taiwan';

-- ⚠️ 問題：country IS NULL 的客戶被排除了！
-- NULL != 'Taiwan' 的結果是 NULL（不是 TRUE），所以這些列不會出現

-- 正確寫法：
SELECT * FROM customers
WHERE country != 'Taiwan' OR country IS NULL;

-- 或更清楚的版本：
SELECT * FROM customers
WHERE COALESCE(country, '') != 'Taiwan';
```

#### 2b：日期範圍邊界

```sql
-- 想找「2026年1月的訂單」
SELECT * FROM orders WHERE order_date BETWEEN '2026-01-01' AND '2026-01-31';

-- ⚠️ 問題：如果 order_date 是 TIMESTAMP 類型
-- '2026-01-31' 被解讀為 '2026-01-31 00:00:00'
-- 1月31日的訂單（下午）會被漏掉！

-- 正確寫法：
SELECT * FROM orders
WHERE order_date >= '2026-01-01' AND order_date < '2026-02-01';
```

#### 2c：JOIN 方向錯誤

```sql
-- 想找「所有客戶，包含沒有下單的」
SELECT c.customer_id, COUNT(o.order_id) AS order_count
FROM orders o
RIGHT JOIN customers c ON o.customer_id = c.customer_id  -- RIGHT JOIN
GROUP BY c.customer_id;

-- 等價但更清楚的寫法（建議用這個）：
SELECT c.customer_id, COUNT(o.order_id) AS order_count
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id  -- LEFT JOIN，以 customers 為主
GROUP BY c.customer_id;
```

#### 2d：HAVING 和 WHERE 搞混

```sql
-- 想找「有超過 5 筆訂單的客戶」

-- ⚠️ 錯誤：WHERE 在 GROUP BY 之前執行，不能過濾聚合結果
SELECT customer_id, COUNT(*) AS order_count
FROM orders
WHERE COUNT(*) > 5  -- ERROR: WHERE 不能用聚合函數
GROUP BY customer_id;

-- 正確：HAVING 在 GROUP BY 之後過濾
SELECT customer_id, COUNT(*) AS order_count
FROM orders
GROUP BY customer_id
HAVING COUNT(*) > 5;
```

#### 2e：DISTINCT 放錯位置

```sql
-- 想計算有多少個不重複的客戶下過訂單
SELECT COUNT(DISTINCT customer_id) FROM orders;  -- ✅ 正確

SELECT DISTINCT COUNT(customer_id) FROM orders;  -- ❌ 這只有一列，意義不同
```

---

## Type 3 — Data Error（資料錯誤）

SQL 語法和邏輯都對，但資料本身有問題，導致結果不可信。

### 常見症狀

#### 3a：重複資料導致 SUM 變大

```sql
-- 計算客戶 1 的總營收
SELECT SUM(total_amount) FROM orders WHERE customer_id = 1;
-- 結果可能遠高於實際業務數字
-- → 可能是 orders 表有重複記錄，或 JOIN 之後發生了 Grain 膨脹！
```

**診斷：**
```sql
-- 找出重複的訂單
SELECT order_id, COUNT(*)
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;

-- 或更詳細地看
SELECT *
FROM orders
WHERE order_id IN (
    SELECT order_id FROM orders
    GROUP BY order_id HAVING COUNT(*) > 1
)
ORDER BY order_id;
```

#### 3b：測試資料混入正式資料

```sql
-- 刪除或排除測試資料前，先用 SELECT 確認
SELECT * FROM customers WHERE company_name ILIKE '%test%';
SELECT * FROM salespeople WHERE email LIKE '%@test.%';
SELECT * FROM orders WHERE total_amount = 0;
SELECT * FROM orders WHERE total_amount < 0;  -- 負值異常訂單？
```

#### 3c：時區問題

```sql
-- 你的 server 是 UTC，但業務資料是台灣時間
-- '2026-01-31 23:30:00 UTC' = '2026-02-01 07:30:00 台灣時間'
-- 月份統計會差一天！

SELECT
    DATE_TRUNC('month', order_date AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Taipei') AS month,
    SUM(total_amount)
FROM orders
GROUP BY 1
ORDER BY 1;
```

---

## SQL Debug SOP

```
遇到可疑結果時的標準流程：

Step 1: 確認是哪種錯誤
  → SQL 能跑嗎？（Type 1）
  → 結果和預期差多少？（Type 2 或 3）

Step 2: 縮小範圍
  → 從 WHERE 加條件，只看一個客戶 / 一個月
  → 比較這個小樣本的結果和預期

Step 3: 確認 Grain
  → SELECT 幾列原始資料（不 GROUP BY）
  → 確認有沒有重複

Step 4: 確認 NULL 處理
  → 把 WHERE 條件拿掉，看 NULL 的列有沒有被排除

Step 5: 用「已知答案」驗證
  → 找一個你知道答案的小樣本
  → 用 SQL 算出來，對比
```

---

## Debug 題庫（5 題）

### 題目 1：找出 Bug

```sql
-- 題目：找出每個業務員的客戶數
SELECT s.name, COUNT(c.customer_id) AS customer_count
FROM salespeople s
JOIN customers c ON s.salesperson_id = c.salesperson_id
GROUP BY s.salesperson_id;

-- 問題：結果少了幾個業務員
-- 為什麼？怎麼修？
```

<details>
<summary>提示（先自己想再看）</summary>

JOIN 是 INNER JOIN，沒有客戶的業務員不會出現。應改為 LEFT JOIN。
同時 GROUP BY 要包含 s.name（或改成 GROUP BY s.salesperson_id, s.name）。

</details>

---

### 題目 2：找出 Bug

```sql
-- 題目：計算 2026 年每月新客戶數（定義：第一次下單的月份）
SELECT
    DATE_TRUNC('month', order_date) AS month,
    COUNT(DISTINCT customer_id) AS new_customers
FROM orders
WHERE EXTRACT(YEAR FROM order_date) = 2026
GROUP BY 1
ORDER BY 1;

-- 問題：這個 SQL 不是「新客戶」，是「當月有下單的客戶」
-- 怎麼找真正的新客戶（第一次下單）？
```

<details>
<summary>提示</summary>

需要先找每個客戶的 `MIN(order_date)`（第一筆訂單日期），
再用這個日期做統計，而不是用所有訂單的日期。

</details>

---

### 題目 3：Type 3 Data Error

```sql
-- 計算 VIP 客戶（歷史消費 > 100 萬）的數量
SELECT COUNT(*) FROM (
    SELECT customer_id, SUM(total_amount) AS total
    FROM orders
    GROUP BY customer_id
    HAVING SUM(total_amount) > 1000000
) AS vip;

-- 結果：147 個 VIP 客戶
-- 但行銷說只有 50 個，哪裡有問題？
```

<details>
<summary>診斷方向</summary>

可能原因：
1. orders 有重複記錄（total_amount 被加了多倍）
2. 有測試訂單、取消訂單沒有排除
3. 有負值的退款訂單需要扣除

診斷 SQL：先 `SELECT order_id, COUNT(*) FROM orders GROUP BY order_id HAVING COUNT(*) > 1`
</details>

---

## 自我測驗

- [ ] NULL 和空字串 `''` 在 WHERE 條件中有什麼不同？
- [ ] 為什麼 `WHERE country != 'Taiwan'` 會漏掉 country 是 NULL 的列？
- [ ] BETWEEN 在處理 TIMESTAMP 時有什麼邊界問題？
- [ ] Type 2 Logic Error 和 Type 3 Data Error，你怎麼分辨？

---

## 🔗 下一步與章節導航

- **前一篇**：[04_SQL核心語法_SELECT到JOIN全解析.md](./04_SQL核心語法_SELECT到JOIN全解析.md)（核心語法精粹）
- **下一篇（跨表與粒度）**：[06_JOIN陷阱與資料粒度問題.md](./06_JOIN陷阱與資料粒度問題.md)（JOIN Explosion 與 Fan-out 深度診斷）
- **商業問題拆解**：[07_SQL商業問題拆解框架.md](./07_SQL商業問題拆解框架.md)（將需求拆解為 SQL 思維）
- **實戰題庫**：[09_30道B2B商業SQL實戰練習題.md](./09_30道B2B商業SQL實戰練習題.md)（將 Debug 思維應用於題目）
- **回到目錄**：[Month 01 學習模組主導航](./README.md)
