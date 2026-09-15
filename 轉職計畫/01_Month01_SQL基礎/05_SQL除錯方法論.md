# 05 — SQL 除錯方法論（初學報錯自救 SOP）

> **AI 時代，寫 SQL 越來越容易；但判斷 SQL 是否正確，越來越重要。**
> 這是你不能外包給 AI 的核心能力。

---

## 一、SQL 錯誤的三種類型

```
Type 1：Syntax Error   → SQL 跑不起來（語法錯誤）
Type 2：Logic Error    → SQL 跑得起來，但結果是錯的（邏輯錯誤）
Type 3：Data Error     → SQL 和邏輯都對，但資料本身有問題（資料品質問題）
```

> ⚠️ **Type 2 和 Type 3 比 Type 1 危險 10 倍**，因為你不知道結果是錯的，還可能拿去做決策。

---

## 二、Type 1 — Syntax Error（語法錯誤）

SQL 無法執行，會直接報錯。錯誤訊息通常是你最好的線索。

### 常見症狀

```sql
-- 錯誤 1：拼錯關鍵字
SELEC * FROM customers;
-- ERROR: syntax error at or near "SELEC"

-- 錯誤 2：忘記逗號（name 被解讀為 alias，不會報錯但語意錯誤）
SELECT customer_id name FROM customers;

-- 錯誤 3：字串用雙引號（PostgreSQL 要用單引號）
SELECT * FROM customers WHERE country = "Taiwan";
-- ERROR: column "Taiwan" does not exist

-- 錯誤 4：GROUP BY 沒包含所有 SELECT 的非聚合欄位
SELECT customer_id, status, SUM(total_amount)
FROM orders
GROUP BY customer_id;
-- ERROR: column "orders.status" must appear in the GROUP BY clause

-- 錯誤 5：JOIN 缺少 ON 條件
SELECT * FROM orders JOIN customers;
-- ERROR: JOIN requires ON or USING
```

### 診斷流程

```
1. 看錯誤訊息，找 "at or near" 的位置
2. 檢查報錯行的前一行（錯誤通常在上一行末尾）
3. 確認：關鍵字拼寫、引號種類、逗號位置、括號是否對稱
4. 把 SQL 縮短，從最小片段開始跑，逐步加回去驗證
```

---

## 三、Type 2 — Logic Error（邏輯錯誤）

SQL 成功執行，但結果不符合業務需求。這類錯誤最容易被忽視。

### 2a：NULL 陷阱

```sql
-- 想找「不是台灣」的客戶
SELECT * FROM customers WHERE country != 'Taiwan';

-- ⚠️ 問題：country IS NULL 的客戶被排除了！
-- NULL != 'Taiwan' 的結果是 NULL（不是 TRUE），因此這些列不會出現

-- ✅ 正確寫法：明確處理 NULL
SELECT * FROM customers
WHERE country != 'Taiwan' OR country IS NULL;

-- ✅ 或更簡潔的版本：
SELECT * FROM customers
WHERE COALESCE(country, '') != 'Taiwan';
```

### 2b：日期範圍邊界

```sql
-- 想找「2026年1月的訂單」
-- 建議用 >= / < 而不用 BETWEEN，避免時間戳邊界問題
SELECT * FROM orders
WHERE order_date >= '2026-01-01' AND order_date < '2026-02-01';
```

### 2c：JOIN 方向錯誤

```sql
-- 想找「所有客戶，包含沒有下單的」

-- ❌ 容易搞混的寫法（RIGHT JOIN 不直觀）：
SELECT c.customer_id, COUNT(o.order_id) AS order_count
FROM orders o
RIGHT JOIN customers c ON o.customer_id = c.customer_id
GROUP BY c.customer_id;

-- ✅ 建議寫法（以主表 customers 為起點，LEFT JOIN 更直觀）：
SELECT c.customer_id, COUNT(o.order_id) AS order_count
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id;
```

### 2d：HAVING 和 WHERE 搞混

```sql
-- 想找「有超過 5 筆訂單的客戶」

-- ❌ 錯誤：WHERE 在 GROUP BY 之前執行，無法對聚合結果過濾
SELECT customer_id, COUNT(*) AS order_count
FROM orders
WHERE COUNT(*) > 5       -- ERROR: aggregate functions are not allowed in WHERE
GROUP BY customer_id;

-- ✅ 正確：HAVING 在 GROUP BY 之後過濾聚合結果
SELECT customer_id, COUNT(*) AS order_count
FROM orders
GROUP BY customer_id
HAVING COUNT(*) > 5;
```

### 2e：DISTINCT 放錯位置

```sql
-- 想計算有多少個不重複的客戶下過訂單
SELECT COUNT(DISTINCT customer_id) FROM orders;   -- ✅ 計算不重複客戶數
SELECT DISTINCT COUNT(customer_id) FROM orders;   -- ❌ 只有一列，語意完全不同
```

---

## 四、Type 3 — Data Error（資料品質問題）

SQL 語法和邏輯都對，但資料本身有問題，導致結果不可信。這是最難發現的錯誤。

### 3a：重複資料導致 SUM 虛增

```sql
-- 計算客戶 1 的總營收
SELECT SUM(total_amount) FROM orders WHERE customer_id = 1;
-- 結果遠高於實際業務數字？
-- → 可能是 orders 表有重複記錄，或 JOIN 之後發生 Grain 膨脹

-- 診斷：找出重複的訂單
SELECT order_id, COUNT(*)
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;
```

### 3b：測試資料混入正式資料

```sql
-- 排除或刪除前，先用 SELECT 確認範圍
SELECT * FROM customers  WHERE company_name ILIKE '%test%';
SELECT * FROM salespeople WHERE email LIKE '%@test.%';
SELECT * FROM orders     WHERE total_amount = 0;
SELECT * FROM orders     WHERE total_amount < 0;  -- 負值異常訂單？
```

---

## 五、SQL Debug SOP（標準除錯流程）

```
遇到可疑結果時，依序執行以下步驟：

Step 1：確認是哪種錯誤
  → SQL 能跑嗎？             → 是 Type 1（Syntax Error）
  → 結果和預期差很多？       → 可能是 Type 2 或 Type 3

Step 2：縮小範圍
  → 加 WHERE 只看一個客戶 / 一個月
  → 比較這個小樣本的結果和你的預期

Step 3：確認 Grain（資料粒度）
  → 去掉 GROUP BY，SELECT 幾列原始資料
  → 確認有沒有重複列

Step 4：確認 NULL 的處理
  → 把 WHERE 條件拿掉，看有 NULL 的列是否被意外排除

Step 5：用「已知答案」驗證
  → 找一個你確定答案的小樣本
  → 用 SQL 算出來，對比，找出差異點
```

---

## 六、Debug 題庫（3 題）

### 題目 1：JOIN 方向問題

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

`JOIN` 預設是 `INNER JOIN`，沒有客戶的業務員不會出現。應改為 `LEFT JOIN`。
同時 `GROUP BY` 要包含 `s.name`，改為 `GROUP BY s.salesperson_id, s.name`。

</details>

---

### 題目 2：NULL 陷阱

```sql
-- 題目：找出所有「非 VIP」的客戶（status 不等於 'VIP'）
SELECT * FROM customers WHERE status != 'VIP';

-- 問題：比預期少了一批客戶
-- 為什麼？怎麼修？
```

<details>
<summary>提示（先自己想再看）</summary>

`status IS NULL` 的客戶被排除了。`NULL != 'VIP'` 結果是 `NULL`，不是 `TRUE`。

正確寫法：
```sql
SELECT * FROM customers
WHERE status != 'VIP' OR status IS NULL;
```

</details>

---

### 題目 3：HAVING vs WHERE

```sql
-- 題目：找出下單金額總和超過 50,000 的客戶
SELECT customer_id, SUM(total_amount) AS total
FROM orders
WHERE SUM(total_amount) > 50000
GROUP BY customer_id;

-- 問題：SQL 直接報錯
-- 為什麼？怎麼修？
```

<details>
<summary>提示（先自己想再看）</summary>

`WHERE` 在 `GROUP BY` 之前執行，不能使用聚合函數。應改用 `HAVING`：
```sql
SELECT customer_id, SUM(total_amount) AS total
FROM orders
GROUP BY customer_id
HAVING SUM(total_amount) > 50000;
```

</details>



---

## 七、自我測驗

- [ ] NULL 和空字串 `''` 在 WHERE 條件中有什麼不同？
- [ ] 為什麼 `WHERE country != 'Taiwan'` 會漏掉 country 是 NULL 的列？
- [ ] Type 2 Logic Error 和 Type 3 Data Error，你怎麼分辨？
- [ ] `HAVING` 和 `WHERE` 的執行順序差在哪裡？
- [ ] 什麼情況下，SQL 跑對了，結果卻是錯的？

---

## 🔗 章節導航

- **前一篇**：[04_SQL核心語法_SELECT到JOIN全解析.md](./04_SQL核心語法_SELECT到JOIN全解析.md)（語法全套建立）
- **下一篇**：[06_JOIN陷阱與資料粒度問題.md](./06_JOIN陷阱與資料粒度問題.md)（JOIN Explosion 與 Fan-out 深度診斷）
- **商業問題拆解**：[07_SQL商業問題拆解框架.md](./07_SQL商業問題拆解框架.md)（5 Level 分層思維模板）
- **實戰題庫**：[09_30道B2B商業SQL實戰練習題.md](./09_30道B2B商業SQL實戰練習題.md)（特別推薦 Q11–Q20 含大量除錯實戰題）
- **回到目錄**：[Month 01 學習模組主導航](./README.md)
