# 🎓 M1 Exit Exam：B2B 商業數據偵探考題【官方參考解答與詳解】

> **「考卷的價值不在於分數，而在於對齊業界 Data Engineer 的思維與產出水準。」**
> 本手冊包含 5 大實作題（含標準 SQL、預期數字與商業結論範本）、3 大口試題白話解答、以及 AI 陷阱題的完整重構思路。請在自行完成作答後，再對照驗證！

---

## 💻 第一部分：B2B 商業數據偵探實作題解答

### 題目 1：營收與履約健康度檢視

#### 🎯 參考 SQL 程式碼

```sql
SELECT 
    SUM(CASE WHEN status = 'Completed' THEN total_amount ELSE 0 END) AS total_revenue,
    COUNT(CASE WHEN status = 'Completed' THEN 1 END) AS completed_order_count,
    SUM(CASE WHEN status IN ('Cancelled', 'Refunded') THEN total_amount ELSE 0 END) AS lost_amount,
    COUNT(CASE WHEN status IN ('Cancelled', 'Refunded') THEN 1 END) AS lost_order_count
FROM orders
WHERE order_date >= '2024-03-01' AND order_date <= '2024-03-31';
```

#### 📊 預期產出數據

|    total_revenue    | completed_order_count |     lost_amount     | lost_order_count |
| :-----------------: | :-------------------: | :-----------------: | :--------------: |
| **735000.00** |      **3**      | **215000.00** |   **2**   |

#### 💼 商業結論與行動建議（範例）

> 「2024 年 3 月份總計完成 3 筆訂單，實收營收 73.5 萬元；但當月因取消與退款造成的損失高達 21.5 萬元，佔全月潛在成交金額的 22.6%。建議營運團隊立即啟動對訂單 14 與 15 的異常履約檢討，優先排查供應鏈延遲或客戶預期落差問題。」

---

### 題目 2：Top 10 旗艦客戶貢獻度分析

#### 🎯 參考 SQL 程式碼

```sql
SELECT 
    c.company_name,
    c.industry,
    SUM(o.total_amount) AS total_spent,
    COUNT(o.order_id) AS order_count,
    ROUND(AVG(o.total_amount), 2) AS avg_order_value
FROM customers c
INNER JOIN orders o ON c.customer_id = o.customer_id
WHERE o.status = 'Completed'
GROUP BY c.customer_id, c.company_name, c.industry
ORDER BY total_spent DESC
LIMIT 10;
```

#### 📊 預期產出數據（前 10 名排行）

| company_name                   | industry      | total_spent | order_count | avg_order_value |
| :----------------------------- | :------------ | :---------: | :---------: | :-------------: |
| **Apex Semi Tech**       | Manufacturing |  540000.00  |      2      |    270000.00    |
| **BlueSky Cloud Ltd**    | SaaS          |  495000.00  |      2      |    247500.00    |
| **Echo Energy Corp**     | Manufacturing |  215000.00  |      1      |    215000.00    |
| **Kingston Chain Store** | Retail        |  210000.00  |      1      |    210000.00    |
| **HyperScale BioMed**    | Healthcare    |  190000.00  |      1      |    190000.00    |
| **Delta Retail Group**   | Retail        |  170000.00  |      1      |    170000.00    |
| **InnoVision Sensor**    | Manufacturing |  140000.00  |      1      |    140000.00    |
| **Grand Harbor Mart**    | Retail        |  120000.00  |      1      |    120000.00    |
| **CyberCore Logistics**  | Logistics     |  105000.00  |      1      |    105000.00    |
| **Jupiter SaaS Hub**     | SaaS          |  95000.00  |      1      |    95000.00    |

#### 💼 商業結論與行動建議（範例）

> 「Top 1 客戶為半導體製造業的 Apex Semi Tech，歷史累計貢獻 54 萬元且客單價高達 27 萬元。建議副總指派資深 Key Account Manager 進行高層拜訪，洽談年度企業級專用合約（Enterprise SLA），以鞏固核心營收護城河。」

---

### 題目 3：高危險沉睡客戶警報 (Churn Alert)

#### 🎯 參考 SQL 程式碼

```sql
SELECT 
    c.customer_id,
    c.company_name,
    c.industry,
    MAX(o.order_date) AS last_order_date,
    (DATE '2024-03-31' - MAX(o.order_date)) AS days_since_last_order
FROM customers c
INNER JOIN orders o ON c.customer_id = o.customer_id
WHERE o.status = 'Completed'
GROUP BY c.customer_id, c.company_name, c.industry
HAVING (DATE '2024-03-31' - MAX(o.order_date)) > 90
ORDER BY days_since_last_order DESC;
```

#### 📊 預期產出數據（共 3 家高危險沉睡客戶）

| customer_id | company_name       | industry   | last_order_date | days_since_last_order |
| :---------: | :----------------- | :--------- | :-------------: | :-------------------: |
| **6** | Frontier AI Studio | SaaS       |   2023-11-15   |     **137**     |
| **7** | Grand Harbor Mart  | Retail     |   2023-12-10   |     **112**     |
| **8** | HyperScale BioMed  | Healthcare |   2023-12-28   |     **94**     |

#### 💼 商業結論與行動建議（範例）

> 「目前共有 3 家重點客戶已沉睡超過 90 天，其中 Frontier AI Studio 更已長達 137 天未有新採購。建議業務團隊優先拜訪生醫業的 HyperScale BioMed（甫過 90 天臨界點，挽回成功率最高），其次安排拜訪 Frontier AI 了解是否有轉用競品之風險。」

---

### 題目 4：業務代表戰力與客單價排行

#### 🎯 參考 SQL 程式碼

```sql
SELECT 
    r.rep_name,
    r.region,
    COALESCE(SUM(o.total_amount), 0) AS sales_volume,
    COUNT(o.order_id) AS deals_closed,
    COALESCE(ROUND(AVG(o.total_amount), 2), 0.00) AS avg_deal_size
FROM sales_reps r
LEFT JOIN orders o ON r.rep_id = o.rep_id AND o.status = 'Completed'
GROUP BY r.rep_id, r.rep_name, r.region
ORDER BY sales_volume DESC;
```

#### 📊 預期產出數據（包含無業績新人）

| rep_name              | region  |    sales_volume    | deals_closed | avg_deal_size |
| :-------------------- | :------ | :-----------------: | :----------: | :------------: |
| **Bob Chen**    | Central | **945000.00** |      4      |   236250.00   |
| **Alice Wang**  | North   | **890000.00** |      4      |   222500.00   |
| **Charlie Lee** | South   | **440000.00** |      3      |   146666.67   |
| **Diana Chang** | North   | **155000.00** |      2      |    77500.00    |
| **Evan Lin**    | Central |   **0.00**   |      0      | **0.00** |

#### 💼 商業結論與行動建議（範例）

> 「Bob Chen 以 94.5 萬元奪得全公司銷售冠軍且客單價最高（23.6 萬）；Diana Chang 雖然成交 2 筆，但客單價僅 7.7 萬，偏向小單銷售；新進業務 Evan Lin 尚未開單，建議主管安排 Top 業務 Bob 進行雙人拜訪搭檔（Shadowing），加速新人開單成熟期。」

---

### 題目 5：長尾滯銷產品盤點

#### 🎯 參考 SQL 程式碼

**⭐ 寫法 1：`LEFT JOIN + ON 條件過濾 + WHERE IS NULL`（Month 01 課綱版・最推薦）**

> 💡 這是完全使用 Month 01 課綱語法的標準解法，也是實務上最直觀易讀的寫法。

```sql
SELECT
    p.product_id,
    p.product_name,
    p.category,
    p.unit_price
FROM products p
LEFT JOIN order_items oi ON p.product_id = oi.product_id
LEFT JOIN orders o       ON oi.order_id = o.order_id
                         AND o.status = 'Completed'   -- ← ON 條件：只帶入 Completed 訂單，不符合的補 NULL
WHERE o.order_id IS NULL                              -- ← WHERE：篩出從未有 Completed 紀錄的產品
ORDER BY p.product_id;
```

> [!NOTE]
> **為什麼 `status = 'Completed'` 要放在 `ON` 裡，而不是 `WHERE`？**
>
> - 放在 `ON`：JOIN 時只帶入 Completed 的訂單，不符合的補 `NULL`（主表 products 的資料不消失）
> - 放在 `WHERE`：JOIN 完才過濾，會把整列刪掉，導致「有 Cancelled 訂單的產品」也消失，錯誤地被排除在滯銷名單之外

---

**寫法 2：使用子查詢 Derived Table（Month 02 語法・超出課綱）**

> ⚠️ 子查詢（`FROM (SELECT ...)`）屬於 **Month 02** 語法，Month 01 課綱不涵蓋此寫法，看得懂即可，不要求掌握。

```sql
SELECT 
    p.product_id, 
    p.product_name, 
    p.category, 
    p.unit_price
FROM products p
LEFT JOIN (
    SELECT DISTINCT oi.product_id
    FROM order_items oi
    INNER JOIN orders o ON oi.order_id = o.order_id
    WHERE o.status = 'Completed'
) sold ON p.product_id = sold.product_id
WHERE sold.product_id IS NULL;
```

---

**寫法 3：使用 `NOT EXISTS`（Month 02 進階語法・超出課綱）**

> ⚠️ `NOT EXISTS` 是相關子查詢（Correlated Subquery），屬於 Month 02 語法，效能最佳，但初學階段不要求掌握。

```sql
SELECT 
    p.product_id, 
    p.product_name, 
    p.category, 
    p.unit_price
FROM products p
WHERE NOT EXISTS (
    SELECT 1 
    FROM order_items oi
    INNER JOIN orders o ON oi.order_id = o.order_id
    WHERE oi.product_id = p.product_id AND o.status = 'Completed'
);
```

#### 📊 預期產出數據（共 2 項滯銷品）

| product_id | product_name | category | unit_price | 備註分析 |
| :---------: | :-------------------------- | :------- | :--------: | :--------------------------------- |
| **7** | Quantum Security Key Dongle | Security | 28000.00 | 從未被任何訂單採購過 |
| **8** | Legacy Tape Backup Unit | Hardware | 60000.00 | 僅出現在取消訂單中，無成功銷售紀錄 |

#### 💼 商業結論與行動建議（範例）

> 「產品 7（量子金鑰）自上架以來為零銷售紀錄，產品 8（磁帶備份機）唯一訂單遭客戶取消。建議將產品 8 進行出清折價或終止維護合約；產品 7 則應評估定價（2.8 萬）是否不符市場行情，或重新打包為軟硬體合購贈品促銷。」

---

## 🗣️ 第二部分：口試題參考擬答 (Interview Ready)

### Q1. WHERE 與 HAVING 的本質差異是什麼？

> **面試官提問**：「為什麼我寫 `WHERE SUM(total_amount) > 50000` 會噴錯？SQL 底層的運算順序到底是什麼？」
>
> **白話回答範本**：
> 「主管您好，這牽涉到 SQL 的底層執行生命週期。
> SQL 執行的順序是：**`FROM` ➜ `JOIN` ➜ `WHERE` ➜ `GROUP BY` ➜ `HAVING` ➜ `SELECT`**。
> `WHERE` 的工作是**在打包分組之前**，針對每一筆原始資料做過濾；但在執行 `WHERE` 時，資料庫根本還沒執行 `GROUP BY`，也還不知道總和 `SUM()` 是多少，因此在 `WHERE` 裡寫聚合函數必然會報錯。
> 如果我們要篩選『加總後的結果』，就必須使用在分組後才生效的 **`HAVING`** 子句。」

---

### Q2. JOIN 導致的資料膨脹（Fan-out trap）

> **面試官提問**：「如果有一張訂單表 `orders`（1 萬筆）與訂單明細表 `order_items`（5 萬筆），我想要算每個客戶的總消費金額。如果直接 JOIN 後再 GROUP BY，計算出來的金額會正確嗎？為什麼？應該怎麼避免？」
>
> **白話回答範本（Month 01 課綱版）**：
> 「不會正確，這是最典型的 **Fan-out（資料膨脹）** 陷阱。
> 當 `orders` JOIN `order_items` 時，因為一筆訂單對應多筆明細，每筆訂單會被複製展開成多行。如果訂單有 3 個品項，這張訂單就出現 3 次。
> 此時如果對 `o.total_amount` 做 `SUM()`，這筆訂單的金額就會被加總 **3 次**，讓報表數字遠大於實際營收，造成嚴重的財務虛增。
>
> **Month 01 的正確做法**：既然已經 JOIN 到 `order_items`，就**不要碰 `o.total_amount`**，改對明細表的 `oi.subtotal` 做 `SUM()`。每筆品項的 subtotal 天然只出現一次，完全不會重複加總，也不需要任何進階語法就能解決這個問題。」

---

### Q3. 三值邏輯與 NULL 陷阱

> **面試官提問**：「在 SQL 裡面，為什麼 `WHERE discount_rate <> 0.1` 無法抓出那些 `discount_rate IS NULL` 的資料？身為 Data Engineer，你在實務上會怎麼防呆？」
>
> **白話回答範本**：「這是因為 SQL 遵循『三值邏輯（Three-Valued Logic）』，也就是條件結果除了 `TRUE` 與 `FALSE` 之外，還有第三種叫 **`UNKNOWN`**。在 SQL 規範中，`NULL` 代表『未知』。任何數值與 `NULL` 進行比較（不管是等於、不等於或大於），結果都不會是 True，而是 `UNKNOWN`。而 `WHERE` 條件**只會放行結果為 `TRUE` 的資料**，因此 `UNKNOWN` 就被默默過濾掉了。實務防呆方式有兩種：
>
> 1. 明確加上空值判斷：`WHERE discount_rate <> 0.1 OR discount_rate IS NULL`
> 2. 使用預設值轉換：`WHERE COALESCE(discount_rate, 0) <> 0.1`」

---

## 🤖 第三部分：AI 陷阱除錯題 (Bug Hunting)

### 實習生提交的錯誤程式碼

```sql
SELECT 
    c.customer_id,
    c.company_name,
    SUM(o.total_amount) AS total_revenue,
    COUNT(oi.product_id) AS total_items_bought
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY c.customer_id, c.company_name;
```

### 1. 致命漏洞抓漏

> **Bug 分析**：
> 這段程式碼犯了典型的 **Fan-out（資料倍數膨脹）** 錯誤！
> 當 `orders` 與 `order_items` 進行 `LEFT JOIN` 時，如果某張訂單底下有 4 個購買品項，這張訂單就會被複製展開為 4 行。
> 此時再對 `o.total_amount` 進行 `SUM()`，**整張訂單的金額就會被重複加總 4 次**！計算出來的 `total_revenue` 會遠大於實際營收，造成嚴重的財務報表虛增！

### 2. 重構修復後的正確 SQL

---

#### 🌟解法 ：改用 oi.subtotal 加總

> 💡 **Month 01 核心思維**（對照 [06_JOIN陷阱與資料粒度問題.md](./06_JOIN陷阱與資料粒度問題.md) 陷阱 1 修正法）：
> 既然已經 JOIN 到 `order_items`，就**絕對不要碰會重複展開的 `o.total_amount`**，而是直接對明細表的 `oi.subtotal` 進行加總！每個品項的 subtotal 天然只會出現一次，完全不需子查詢或 CTE，純靠基礎語法就能完美避坑！

```sql
SELECT 
    c.customer_id,
    c.company_name,
    COALESCE(SUM(oi.subtotal), 0) AS total_revenue,
    COUNT(oi.item_id) AS total_items_bought
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id AND o.status = 'Completed'
LEFT JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY c.customer_id, c.company_name
ORDER BY total_revenue DESC;
```
