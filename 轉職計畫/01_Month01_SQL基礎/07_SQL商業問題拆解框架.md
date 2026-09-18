# 07 — SQL 商業問題拆解框架

> 🎯 **這一節最重要的一件事（心智定位）**：
> 寫 SQL 是最後 10% 的打字翻譯；前 90% 的關鍵在於將模糊的商業白話精準拆解為「指標、維度、過濾器、表血緣與資料粒度」。
>
> 💼 **為什麼非學不可（避坑痛點）**：
> 沒先拆解需求就直接盲敲 SELECT，往往寫到一半發現 JOIN 錯表、粒度失控，最後產出看似有數字卻回答不了主管問題的廢棄報表，返工浪費整週時間！

---

## 為什麼要拆解問題？

初學者的流程：
```
看到題目 → 馬上開始寫 SELECT → 卡住 → 問 AI → 複製答案（腦袋一片空白）
```

工程師的流程：
```
看到題目 → 拆解需求 → 確認 Table 和 Grain → 設計 SQL 結構 → 寫 SQL → 驗證結果
```

**第二個流程多了 2 分鐘，但正確率高 10 倍，且能真正建立獨立解決商業問題的工程直覺。**

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
  AND EXTRACT(YEAR FROM o.order_date) = 2026
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

## 拆解框架快速版

撰寫查詢前，先確認以下三個問題：

```
1. 我需要哪幾張表？為什麼？

2. JOIN 之後，這張查詢的 Grain 是什麼？
   （每列代表什麼？）

3. 我怎麼驗證結果是對的？
```

---

## 自我測驗

拿這道進階商業題練習拆解框架（⚠️ **請打開記事本先自己填寫，切勿直接偷看下方折疊！**）：

> **「哪些客戶在過去 12 個月內，每季都有下單，但平均訂單金額在下降？」**

請在你的筆記本中用模板填寫：
- Business Question：
- Metric：
- Dimension：
- Filter：
- Required Tables：
- Join Key：
- Data Grain：
- Aggregation：
- Expected Result：

<details>
<summary>💡 需要拆解提示嗎？（點擊展開提示）</summary>

1. 「過去 12 個月」是 Filter：`order_date >= NOW() - INTERVAL '1 year'`。
2. 「每季都有下單」代表一共有 4 個季度，計算不重複季度數 `COUNT(DISTINCT EXTRACT(QUARTER FROM order_date)) = 4`。
3. 「平均金額下降」在單純 SQL 基礎篇需要用到 CTE 或比較前後季度（在 Month 02 的 Window Functions `LAG()` 是最標準解法）。
</details>

<details>
<summary>✅ 填完了？點擊對照標準拆解結果</summary>

```
Business Question：
  找出持續黏著（近一年四季皆有單）但客單價呈現衰退的高風險萎縮客戶

Metric：
  1. 活躍季度數：COUNT(DISTINCT EXTRACT(QUARTER FROM order_date))
  2. 季度平均訂單金額：AVG(total_amount)

Dimension：
  customer_id, 季度（QUARTER）

Filter：
  - order_date >= 當前日期 - 1 年
  - status = 'COMPLETED'

Required Tables：
  - customers, orders

Join Key：
  customers.customer_id = orders.customer_id

Data Grain：
  最終結果應為「每家高風險客戶一列」

Aggregation：
  第一層按 customer + quarter 分組，第二層按 customer 評估趨勢

Expected Result：
  少數幾家老客戶（警示名單），欄位：customer_id, company_name, warning_flag
```
</details>

> 💡 **商業問題拆解核心收斂**：
> **先定指標再定維，篩選時間表相隨；粒度清楚方下筆，拆解先行百戰歸。**

---

## 🔗 下一步與章節導航

- **前一篇**：[06_JOIN陷阱與資料粒度問題.md](./06_JOIN陷阱與資料粒度問題.md)（JOIN Explosion 與 Fan-out 深度防坑指南）
- **下一篇（AI 協作流程）**：[08_AI協助SQL複習工作流.md](./08_AI協助SQL複習工作流.md)（AI 輔助 Code Review 與學習軌跡存檔）
- **實戰手寫題庫**：[09_30道B2B商業SQL實戰練習題.md](./09_30道B2B商業SQL實戰練習題.md)（30 道 B2B 實戰練習）
- **學習軌跡模板**：[my_solutions/README.md](./my_solutions/README.md)（落實思考 → 寫作 → 改進）
- **回到目錄**：[Month 01 學習模組主導航](./README.md)
