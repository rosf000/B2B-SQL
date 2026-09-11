# 03 — SQL 問題拆解框架

> **「不要看到題目就寫 SQL。先拆問題，再寫 SQL。」**
> 這個習慣是「SQL 初學者」和「資料工程師」的分水嶺。

---

## 為什麼要拆解問題？

初學者的流程：
```
看到題目 → 馬上開始寫 SELECT → 卡住 → 問 AI → 複製答案
```

工程師的流程：
```
看到題目 → 拆解需求 → 確認 Table 和 Grain → 設計 SQL 結構 → 寫 SQL → 驗證結果
```

**第二個流程多了 2 分鐘，但正確率高 10 倍。**

---

## SQL 問題拆解模板

拿到任何 SQL 題目，先填這個表格：

```
Business Question：（用自然語言寫出要回答什麼問題）

Metric（量化指標）：
  → 要計算什麼數字？（SUM / COUNT / AVG / MAX？）

Dimension（分析維度）：
  → 要按什麼分組？（客戶？月份？產業？業務？）

Filter（篩選條件）：
  → 有什麼限制條件？（哪個時間範圍？哪個地區？什麼狀態？）

Time Range（時間範圍）：
  → 過去 30 天？今年？指定季度？

Required Tables（需要哪些表）：
  → 這個問題需要從哪些表拿資料？

Join Key（連接欄位）：
  → 這些表怎麼連起來？

Data Grain（分析後的粒度）：
  → 最終結果一列代表什麼？

Aggregation（彙總方式）：
  → GROUP BY 什麼欄位？

Expected Result（預期結果長什麼樣）：
  → 大概應該有幾列？欄位是什麼？
```

---

## 實戰範例

### 題目：「找出今年前三季、每個業務員的總營收，並標示是否達到 100 萬目標」

#### 拆解過程

```
Business Question：
  今年前三季，每個業務的業績，以及有沒有達標

Metric：
  SUM(order_items.unit_price * order_items.quantity)  ← 訂單總金額

Dimension：
  salesperson（業務員）

Filter：
  - 今年（EXTRACT(year FROM orders.order_date) = 2026）
  - 前三季（EXTRACT(quarter FROM ...) IN (1, 2, 3)）
  - 訂單狀態正常（orders.status != 'cancelled'）

Time Range：
  2026 年 Q1–Q3

Required Tables：
  - salespeople（業務員資料）
  - orders（訂單，含業務員 ID 和日期）
  - order_items（訂單明細，含金額）

Join Key：
  salespeople.salesperson_id = orders.salesperson_id
  orders.order_id = order_items.order_id

Data Grain（JOIN 後）：
  order_items 層級，每列是一個訂單商品
  → GROUP BY salesperson 後，變成每業務一列

Aggregation：
  GROUP BY s.salesperson_id, s.name

Expected Result：
  大約 10–20 列（視業務員人數）
  欄位：salesperson_name, total_revenue, is_target_met
```

#### 寫 SQL

```sql
SELECT
    s.salesperson_id,
    s.name AS salesperson_name,
    SUM(oi.unit_price * oi.quantity) AS total_revenue,
    CASE
        WHEN SUM(oi.unit_price * oi.quantity) >= 1000000 THEN '✅ 達標'
        ELSE '❌ 未達標'
    END AS target_status
FROM salespeople s
JOIN orders o ON s.salesperson_id = o.salesperson_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE
    EXTRACT(YEAR FROM o.order_date) = 2026
    AND EXTRACT(QUARTER FROM o.order_date) IN (1, 2, 3)
    AND o.status != 'CANCELLED'
GROUP BY s.salesperson_id, s.name
ORDER BY total_revenue DESC;
```

#### 驗證結果

```sql
-- 驗證 1：業務員總數對不對？
SELECT COUNT(DISTINCT salesperson_id) FROM salespeople;

-- 驗證 2：隨機抽查一個業務的數字對不對？
SELECT s.name, SUM(oi.unit_price * oi.quantity)
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN salespeople s ON o.salesperson_id = s.salesperson_id
WHERE s.name = 'Alex Chen'
  AND EXTRACT(YEAR FROM o.order_date) = 2024
  AND EXTRACT(QUARTER FROM o.order_date) IN (1, 2, 3)
  AND o.status != 'CANCELLED'
GROUP BY s.name;
```

---

## 30 道商業題的拆解分級

### Level 1 — SQL Translation（直接轉換）

> 題目描述幾乎就是 SQL 的結構

```
題目：找出台灣的所有客戶
拆解：
  Metric: customer_id, name（列表）
  Filter: country = 'Taiwan'
  Table: customers
```

### Level 2 — Aggregation（需要彙總）

```
題目：每個國家有多少客戶？
拆解：
  Metric: COUNT(customer_id)
  Dimension: country
  Table: customers
  Aggregation: GROUP BY country
```

### Level 3 — JOIN（需要跨表）

```
題目：每個客戶的總訂購金額
拆解：
  Metric: SUM(total_amount)
  Dimension: customer
  Tables: customers + orders
  Join Key: customer_id
  ⚠️ Grain 注意：JOIN 後是 orders 粒度
```

### Level 4 — Business Logic（需要商業邏輯判斷）

```
題目：找出「高價值但最近三個月沒有下單」的客戶
拆解：
  高價值 = 歷史總消費 > 50 萬（SUM）
  最近三個月沒下單 = MAX(order_date) < 三個月前
  Tables: customers + orders
  先 GROUP BY customer → HAVING 條件過濾
```

### Level 5 — Debug（找出 SQL 的錯誤）

```
題目：這條 SQL 結果不對，哪裡有問題？
拆解流程：
  1. SQL 能跑嗎？（Syntax Error？）
  2. 結果和預期差多少？（多 10 倍？少一半？）
  3. Grain 有沒有爆炸？（JOIN 後資料變多倍？）
  4. Filter 有沒有把 NULL 吃掉？
  5. 商業邏輯有沒有理解錯？
```

---

## 拆解框架快速版（練習時用）

每道題做完前，至少回答這三個問題：

```
1. 我需要哪幾張表？為什麼？

2. JOIN 之後，這張查詢的 Grain 是什麼？
   （每列代表什麼？）

3. 我怎麼驗證結果是對的？
```

---

## 自我測驗

拿這道題練習拆解框架（不要馬上寫 SQL）：

> **「哪些客戶在過去 12 個月內，每季都有下單，但平均訂單金額在下降？」**

用模板填寫：
- Business Question：
- Metric：
- Dimension：
- Filter：
- Required Tables：
- Join Key：
- Data Grain：
- Aggregation：
- Expected Result：

寫完後再開始寫 SQL。

---

## 🔗 下一步與章節導航

- **前一篇**：[02_SQL核心語法精粹_SELECT至JOIN.md](./02_SQL核心語法精粹_SELECT至JOIN.md)（核心語法與執行順序）
- **下一篇（避坑專案）**：[04_JOIN陷阱與資料重複.md](./04_JOIN陷阱與資料重複.md)（JOIN Explosion 診斷與修正）
- **實戰手寫題庫**：[03_30道商業場景SQL實戰練習題_含解答.md](./03_30道商業場景SQL實戰練習題_含解答.md)（30 道 B2B 實戰練習）
- **學習軌跡模板**：[my_solutions/README.md](./my_solutions/README.md)（落實思考 → 寫作 → 改進）
- **回到目錄**：[Month 01 學習模組主導航](./README.md)
