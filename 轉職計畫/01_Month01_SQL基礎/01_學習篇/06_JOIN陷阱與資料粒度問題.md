# 06 — JOIN 陷阱與資料粒度問題（Fan-out 深度防坑指南）

> 🎯 **這一節最重要的一件事（心智定位）**：
> 跨表 JOIN 是一對多（1:N）的維度展開；一旦在明細粒度上對主表金額執行 SUM，就會產生致命的 Fan-out 乘數膨脹！
>
> 💼 **為什麼非學不可（避坑痛點）**：
> 某家客戶實際只買了 25 萬，因為 JOIN 了訂單明細，金額瞬間虛胖變成 40.5 萬。如果你拿著膨脹的虛假業績報給總經理與財務長，就是嚴重的商業舞弊與誠信事故！

> [!IMPORTANT]
> 本篇範例均基於 **B2B Canonical 資料庫**（`data/b2b_m1_sample_v2.sql`）。
> **你不必先開 DBeaver 測試才能看懂**——本篇所有關鍵案例均提供**「直覺圖解」與「展開對照表」**，一眼就能看出數字為什麼爆炸；隨後附上可執行的 SQL 供你實機印證。

---

## 視覺第一步：30 秒秒懂什麼是「資料粒度（Grain）」？

在談 JOIN 之前，先建立一個最重要的直覺：**什麼是資料粒度（Grain）？**

> 💡 **一句話白話定義**：
> **「這張資料表裡，『每一列（Row）』到底代表什麼東西？」**

以電商與 B2B 系統為例：

```text
【客戶表 customers】    👉 粒度：1 列 = 1 位客戶
   │
   ▼ (1 位客戶可以下多筆訂單：1 對 N)
【訂單主表 orders】       👉 粒度：1 列 = 1 張訂單
   │
   ▼ (1 張訂單可以買多個商品：1 對 N)
【訂單明細 order_items】  👉 粒度：1 列 = 1 個商品明細
```

### 🚨 JOIN 的「影印機定律」

當你把「大粒度（訂單主表）」去 JOIN「小粒度（訂單明細）」時：

- **明細表有幾列，主表的那一列就會像被影印機影印一樣，被「複製貼上」幾次！**
- 如果一張訂單買了 3 樣商品，這張訂單的資料就會在結果中**被複製出現 3 次**！

---

## 震撼現場：為什麼 25 萬會瞬間變成 40.5 萬？

我們用資料庫裡的真實客戶 **BlueSky Cloud Ltd（customer_id = 2）** 做示範。
不用去背 SQL，直接看以下這張**「不用跑查詢也一眼看懂的真相展開圖」**！

### 1. 原始事實（兩張表的真實模樣）

**【訂單主表 orders】（這家客戶實際上只有這 2 筆已完成訂單，總額確實是 25 萬）**

|      order_id      | order_number | 訂單總額 (total_amount) | 買了幾樣東西？                  |
| :----------------: | :----------- | :---------------------: | :------------------------------ |
|    **2**    | ORD-2024-002 |    **155,000**    | 買了 2 樣商品（品項 2、品項 3） |
|    **10**    | ORD-2024-010 |    **95,000**    | 買了 1 樣商品（品項 13）        |
| **真實總額** |              |    **250,000**    | （155,000 + 95,000 = 250,000）  |

**【訂單明細 order_items】（實際品項明細與金額）**

|   order_id   | item_id | 購買品項                | 明細小計 (subtotal) |
| :----------: | :-----: | :---------------------- | :-----------------: |
| **2** |    2    | Enterprise Support Plan |       60,000       |
| **2** |    3    | Cloud Security Pack     |       95,000       |
| **10** |   13   | Cloud Security Pack     |       95,000       |

---

### 2. JOIN 之後發生了什麼？（影印機開始複製！）

當你寫下 `orders JOIN order_items ON o.order_id = oi.order_id` 時，
因為訂單 2 買了 2 個品項，資料庫為了把明細接上來，**把訂單 2 影印複製成了 2 列**：

|   order_id   | 訂單總額`o.total_amount` | item_id | 明細小計`oi.subtotal` | 發生了什麼事？                        |
| :----------: | :------------------------: | :-----: | :---------------------: | :------------------------------------ |
| **2** |     **155,000**     |    2    |         60,000         | 🖨️ 訂單 2 被影印第 1 次             |
| **2** |   **155,000** ⚠️   |    3    |         95,000         | 🖨️ 訂單 2 被影印第 2 次（重複了！） |
| **10** |      **95,000**      |   13   |         95,000         | 只有 1 個品項，沒被多印               |

---

### 3. 致命災難：這時候若對 `o.total_amount` 做 SUM()

```text
電腦執行 SUM(o.total_amount) 時，它只會由上往下機械式加總：
   155,000  (第 1 列的 total_amount)
+  155,000  (第 2 列的 total_amount，被重複加了！)
+   95,000  (第 3 列的 total_amount)
---------------------------------------------
=  405,000  ❌ 憑空虛胖了 155,000！（原本明明只有 250,000）
```

> 🎯 **一眼看穿的結論**：
> 電腦不知道 `total_amount` 是整張訂單的總額！
> 它只看到結果表有 3 列，就把那 3 列的數字全部加在一起！
> **這就是所謂的 Fan-out 乘數膨脹（JOIN Explosion）！**

---

### 實機 SQL 驗證對照

現在你看懂了原理，再看這兩段 SQL 就會更清楚：

```sql
-- ❌ 錯誤寫法：JOIN 明細後，卻 SUM 主表的 total_amount
SELECT
    c.company_name,
    SUM(o.total_amount) AS wrong_total     -- ⚠️ 155,000 被加了兩次！
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE c.company_name = 'BlueSky Cloud Ltd'
  AND o.status = 'COMPLETED'
GROUP BY c.company_name;
-- 查詢結果：405000.00 ❌ 虛胖！
```

```sql
-- ✅ 正確解法 1：不碰主表金額，直接加總明細小計 subtotal
-- （因為每個 item_id 在結果中都只有 1 列，天然不重複！）
SELECT
    c.company_name,
    SUM(oi.subtotal) AS correct_total      -- ✅ 60,000 + 95,000 + 95,000 = 250,000
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE c.company_name = 'BlueSky Cloud Ltd'
  AND o.status = 'COMPLETED'
GROUP BY c.company_name;
-- 查詢結果：250000.00 ✅ 完全正確！
```

```sql
-- ✅ (參考內容)正確解法 2（企業標準做法）：先用 CTE 把明細收合回「每筆訂單一列」，再 JOIN
WITH order_item_summary AS (
    -- 先在明細層把每筆訂單的金額算好（粒度收斂回：1 列 = 1 筆訂單）
    SELECT 
        order_id, 
        SUM(subtotal) AS line_total
    FROM order_items
    GROUP BY order_id
)
SELECT
    c.company_name,
    SUM(ois.line_total) AS correct_total
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_item_summary ois ON o.order_id = ois.order_id
WHERE c.company_name = 'BlueSky Cloud Ltd'
  AND o.status = 'COMPLETED'
GROUP BY c.company_name;
-- 查詢結果：250000.00 ✅ 完全正確！
```

---

## 四大常見 JOIN 陷阱全圖解

---

### 陷阱 1：一對多（1:N）導致主表度量 SUM 膨脹

- **發生情境**：主單 JOIN 明細清單（例如：訂單 JOIN 訂單商品、部門 JOIN 員工）。
- **現象**：主表的金額欄位（如訂單金額、預算金額）被放大了 `N` 倍。
- **直覺心法**：
  > 只要跨表 JOIN，先問自己：**「我現在 SUM 的這個欄位，是來自 1 的那一邊，還是 N 的那一邊？」**
  >
  > - 來自 **N（多）** 的那一邊（如 `oi.subtotal`）：可以安全加總。
  > - 來自 **1（單）** 的那一邊（如 `o.total_amount`）：**絕對不能直接加總！**
  >

---

### 陷阱 2：多對多（N:M）笛卡兒積互乘爆炸

當一張主表**同時關聯兩張「多」的子表**時，會產生毀滅性的乘數爆炸。

#### 想像這個場景

客戶 1 同時有 **3 個標籤（Tags）** 與 **2 筆訂單（Orders）**：

```text
客戶 1 的標籤 (3個)           客戶 1 的訂單 (2筆)
- VIP                      - ORD-101
- Cloud                    - ORD-102
- Enterprise
```

如果直接將兩張表透過 `customer_id` 一起 JOIN：

```text
VIP          × ORD-101  ──┐
VIP          × ORD-102  ──┼─ 標籤 VIP 配對 2 筆訂單
Cloud        × ORD-101  ──┤
Cloud        × ORD-102  ──┼─ 標籤 Cloud 配對 2 筆訂單
Enterprise   × ORD-101  ──┤
Enterprise   × ORD-102  ──┘─ 標籤 Enterprise 配對 2 筆訂單

👉 結果直接暴增成：3 × 2 = 6 列！
```

#### 視覺對比表

| customer_id | tag        | order_id |            此時 COUNT(order_id) 會算成？            |
| :---------: | :--------- | :------- | :-------------------------------------------------: |
|      1      | VIP        | ORD-101  |                          1                          |
|      1      | VIP        | ORD-102  |                          2                          |
|      1      | Cloud      | ORD-101  |                          3                          |
|      1      | Cloud      | ORD-102  |                          4                          |
|      1      | Enterprise | ORD-101  |                          5                          |
|      1      | Enterprise | ORD-102  | **6 ⚠️ 明明只有 2 筆訂單，卻被算成 6 筆！** |

#### 防坑解法

1. **聚合計數時加上 `DISTINCT`**：`COUNT(DISTINCT o.order_id)`，重複的 ORD-101 只計 1 次。
2. **絕不同時 JOIN 兩張獨立的明細表**：改用兩個獨立的 CTE 或子查詢各自算完，再分別與客戶表關聯。

---

### 陷阱 3：JOIN Key 不具唯一性（未預期的 N:M）

- **發生情境**：以為關聯鍵是一對一，但實際上鍵值存在重複資料（例如用 `company_name` 或未去重的非主鍵關聯）。
- **診斷習慣（寫 JOIN 前必先執行）**：

```sql
-- 檢查 orders 表中的 customer_id 到底是不是唯一的？
SELECT
    customer_id,
    COUNT(*) AS records_per_key
FROM orders
GROUP BY customer_id
HAVING COUNT(*) > 1
ORDER BY records_per_key DESC;
```

##### 📊 查詢結果（證明 customer_id 在 orders 中有重複，屬於 1:N 關係）

| customer_id |       records_per_key       |
| :---------: | :--------------------------: |
|      1      | 3（代表關聯時會展開成 3 列） |
|      4      |              2              |
|      2      |              2              |
|      8      |              2              |

---

### 陷阱 4：LEFT JOIN 後，`COUNT(*)` 與 `COUNT(欄位)` 的生死之差

這是面試與實務最常踩到的經典陷阱！

#### 真實場景

資料庫中有兩家潛在客戶：

- **`InnoVibe Studio`（customer_id = 9）**：從未下過訂單。
- **`Jovial Media Group`（customer_id = 10）**：從未下過訂單。

我們用 `LEFT JOIN orders` 查詢所有客戶的訂單數量：

#### 展開後的原始資料（一眼看出 NULL 的差別）

| customer_id | company_name                 |     o.order_id     | `COUNT(*)` 的視角（看「整列」）       | `COUNT(o.order_id)` 的視角（看「格子」）       |
| :----------: | :--------------------------- | :----------------: | :-------------------------------------- | :----------------------------------------------- |
|      1      | Apex Semi Tech               |         1         | 有這一列 👉 計為 1                      | 格子有值（1） 👉 計為 1                          |
|      1      | Apex Semi Tech               |         3         | 有這一列 👉 計為 1                      | 格子有值（3） 👉 計為 1                          |
|     ...     | ...                          |        ...        | ...                                     | ...                                              |
| **9** | **InnoVibe Studio**    | **`NULL`** | **有這一列！👉 計為 1 ❌ 錯誤！** | **格子是 NULL！👉 跳過，計為 0 ✅ 正確！** |
| **10** | **Jovial Media Group** | **`NULL`** | **有這一列！👉 計為 1 ❌ 錯誤！** | **格子是 NULL！👉 跳過，計為 0 ✅ 正確！** |

> [!CAUTION]
> 🚨 **鐵律記憶卡**：
>
> - `COUNT(*)`：**數列數（Row Count）**。只要這列存在（即使右邊全是 NULL），它就算 1！
> - `COUNT(欄位)`：**數該欄位「非 NULL（Not Null）」的值有幾個**。遇到 NULL 自動跳過算 0！
> - **結論：只要用了 LEFT JOIN，統計右表次數一律用 `COUNT(右表.鍵值)`，千萬不要寫 `COUNT(*)`！**

#### 實機 SQL 驗證

```sql
SELECT
    c.customer_id,
    c.company_name,
    COUNT(o.order_id) AS correct_order_count,  -- ✅ 遇到沒訂單的客戶顯示 0
    COUNT(*)          AS wrong_order_count     -- ⚠️ 遇到沒訂單的客戶誤標為 1
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.company_name
ORDER BY c.customer_id;
```

##### 📊 執行結果對照

| customer_id | company_name                 | correct_order_count ✅ | wrong_order_count ⚠️ |
| :----------: | :--------------------------- | :--------------------: | :---------------------: |
|      1      | Apex Semi Tech               |           3           |            3            |
|      2      | BlueSky Cloud Ltd            |           3           |            3            |
|     ...     | ...                          |          ...          |           ...           |
| **9** | **InnoVibe Studio**    |     **0** ✅     | **1** ❌ 錯誤膨脹 |
| **10** | **Jovial Media Group** |     **0** ✅     | **1** ❌ 錯誤膨脹 |

---

## 實務 SOP：3 秒防坑對帳檢查法

在交付任何涉及 JOIN 的財務或業務報表前，請務必按照以下步驟對帳：

### 第一步：比對 JOIN 前後的列數

```sql
-- 1. JOIN 前主表的筆數
SELECT COUNT(*) FROM orders;          -- 例如：13 筆

-- 2. JOIN 明細後的筆數
SELECT COUNT(*) FROM orders o 
JOIN order_items oi ON o.order_id = oi.order_id;  -- 變成了 18 筆！
-- 只要兩者數字不同，就代表發生了 1:N 展開，絕不能對主表金額做 SUM！
```

### 第二步：diff 逐筆對帳法（驗證資料一致性）

驗證主表記錄的 `total_amount` 與明細表加總出來的金額是否完全相符：

```sql
SELECT
    o.order_id,
    o.order_number,
    o.total_amount   AS 主表記錄金額,
    SUM(oi.subtotal) AS 明細加總金額,
    o.total_amount - SUM(oi.subtotal) AS diff -- 差額（正常情況必須全為 0）
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_id, o.order_number, o.total_amount
ORDER BY o.order_id;
```

##### 📊 預期對帳結果

| order_id | order_number | 主表記錄金額 | 明細加總金額 |       diff       |
| :------: | :----------- | :----------: | :----------: | :---------------: |
|    1    | ORD-2024-001 |  360000.00  |  360000.00  | **0.00** ✅ |
|    2    | ORD-2024-002 |  155000.00  |  155000.00  | **0.00** ✅ |
|    3    | ORD-2024-003 |  240000.00  |  240000.00  | **0.00** ✅ |
|   ...   | ...          |     ...     |     ...     | **0.00** ✅ |

---

## 粒度防坑心法總結卡

| 關聯類型            | 範例場景                    |     展開結果     | 聚合時的致命地雷                           | 安全解法                                          |
| :------------------ | :-------------------------- | :--------------: | :----------------------------------------- | :------------------------------------------------ |
| **1 : 1**     | 客戶 : 客戶詳細資料         |   1 列 → 1 列   | 通常安全                                   | 正常計算                                          |
| **1 : N**     | 訂單 : 訂單明細             |   1 列 → N 列   | **對主表度量做 SUM 會虛胖 N 倍**     | 1. 改 SUM 明細小計2. 用 CTE 先收合再 JOIN         |
| **N : M**     | 標籤 : 訂單（雙多）         | 1 列 → N×M 列 | **列數與計數指數級失真**             | 1.`COUNT(DISTINCT ...)`2. 分開兩個 CTE 各自聚合 |
| **LEFT JOIN** | 客戶 : 訂單（含無訂單客戶） | 無訂單補 NULL 列 | **用 `COUNT(*)` 把 0 筆算成 1 筆** | 一律改用`COUNT(右表欄位)`                       |

> 💡 **防坑口訣**：
> **主單串明細，粒度往下沉；主表金額重複印，加總明細才成真；**
> **遇上 LEFT JOIN 算次數，COUNT 帶欄位莫寫星。**

---

## ✋ 粒度防坑空白頁挑戰

> **業務主管提問**：
> 「請統計 **Apex Semi Tech（`customer_id = 1`）** 的已完成（`COMPLETED`）訂單總額。
> 請寫一段 SQL 同時輸出：
>
> 1. `orders_recorded`：由訂單主表呈現的訂單金額
> 2. `items_calculated`：由訂單明細 `order_items` 加總出的實際金額
> 3. `diff`：兩者的差額，確保沒有任何 Fan-out 重複計算或漏算。」

<details>
<summary>💡 需要思考提示嗎？（點擊展開）</summary>

直接對 `orders` JOIN `order_items`，並依據 `order_id` 進行 GROUP BY：

- `o.total_amount` 直接取主表數字
- `SUM(oi.subtotal)` 加總明細金額
- `o.total_amount - SUM(oi.subtotal)` 計算差值

</details>

<details>
<summary>✅ 寫完了？點擊查看標準對帳代碼</summary>

```sql
SELECT 
    o.order_id,
    o.order_number,
    o.total_amount AS orders_recorded,
    SUM(oi.subtotal) AS items_calculated,
    o.total_amount - SUM(oi.subtotal) AS diff
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.customer_id = 1 
  AND o.status = 'COMPLETED'
GROUP BY o.order_id, o.order_number, o.total_amount;
```

**解讀**：
只要每筆訂單的 `diff` 都是 0.00，就證明明細項與主表金額完全契合，數據無懈可擊！

</details>

---

## 自我測驗

試著用自己的話回答以下問題（不看內文）：

- [ ] 為什麼 `orders` JOIN `order_items` 後，對 `orders.total_amount` 做 SUM 會算出錯誤的虛胖數字？
- [ ] 為什麼 LEFT JOIN 後，沒下過單的客戶用 `COUNT(*)` 會顯示 1，而用 `COUNT(order_id)` 會顯示 0？
- [ ] 什麼是「影印機現象」？當 1 筆訂單對應 3 個明細時，主表的資料發生了什麼事？
- [ ] 如果同時要把客戶的「標籤」和「訂單」關聯起來統計，會發生什麼危險？最好的解決策略是什麼？

<details>
<summary>💡 點擊查看自我測驗參考答案與核心盲點解析</summary>

### 1. 為什麼 `orders` JOIN `order_items` 後，對 `orders.total_amount` 做 SUM 會算出錯誤的虛胖數字？

- **核心成因**：**1 對 N 的關聯基數（Cardinality）**，而非 JOIN 的類型（無論 `INNER JOIN` 還是 `LEFT JOIN` 都會發生）。
- **機制說明**：只要一張訂單對應多筆明細，主表（`orders`）的每一筆記錄都會為了與多筆明細對齊而被重複複製 $N$ 列。因此直接對主表的 `orders.total_amount` 做 `SUM()`，該訂單金額就會被乘上 $N$ 倍，產生虛胖。
- **正確做法**：改為加總明細金額 `SUM(order_items.subtotal)`，或者在關聯前先以 CTE / 子查詢將明細聚合至訂單粒度。

---

### 2. 為什麼 LEFT JOIN 後，沒下過單的客戶用 `COUNT(*)` 會顯示 1，而用 `COUNT(order_id)` 會顯示 0？

- **`COUNT(*)` 的行為**：計算的是**結果集的總列數（Rows）**。即使該列右表欄位全為 `NULL`，只要主表有這列客戶，結果集就存在 1 列，因此計算結果為 1。
- **`COUNT(欄位名)` 的行為**：會**自動忽略 NULL 值**。沒下過單的客戶經 LEFT JOIN 後，右表訂單欄位（如 `order_id`）皆為 `NULL`，因此計數結果為 0。

---

### 3. 什麼是「影印機現象」？當 1 筆訂單對應 3 個明細時，主表的資料發生了什麼事？

- **概念定義**：又稱 **Fan-out（笛卡爾倍增效應）**。指主表（1 的那方）為了對齊子表（N 的那方），整列資料被像影印機一樣複製了 $N$ 次。
- **資料狀態**：當 1 筆訂單對應 3 個明細時，該筆訂單在結果集中會被複製成 3 列。此時訂單的主表欄位（如訂單金額、運費）在計算視圖中都出現了 3 次，若未經處理直接對主表欄位執行 `SUM()` 或 `AVG()`，數值就會被放大 3 倍。

---

### 4. 如果同時要把客戶的「標籤」和「訂單」關聯起來統計，會發生什麼危險？最好的解決策略是什麼？

- **潛在危險（$N \times M$ 笛卡爾積爆炸）**：客戶與標籤（1 對 N）、客戶與訂單（1 對 M）屬於兩個彼此獨立的維度。若直接同時 JOIN，列數會暴增為 $N \times M$ 列（例如 5 個標籤 $\times$ 10 筆訂單 = 50 列），造成嚴重的計算失真與效能低下。
- **常見誤區陷阱**：
  - 使用 `DISTINCT` 只能解決 `COUNT(DISTINCT order_id)`。
  - **無法直接用 `SUM(DISTINCT total_amount)` 解決金額加總**！若客戶剛好有兩筆金額相同的合法訂單（例如都是 $500），`DISTINCT` 會誤刪合法金額，導致營收被低估。
- **最佳解決策略**：
  1. **分開聚合（Pre-aggregation，強烈推薦）**：先各自用獨立的 CTE 或子查詢將「標籤」與「訂單」聚合至客戶粒度（例如算出標籤數），最後再與客戶主表進行 1:1 JOIN。
  2. **維度收合 / 陣列化**：在子查詢中將標籤以 `STRING_AGG` 或 `ARRAY_AGG` 聚合成單一字串或陣列，保持客戶表粒度不被打散。

</details>

---

## 🔗 下一步與章節導航

- **前一篇**：[05_SQL除錯方法論.md](./05_SQL除錯方法論.md)（除錯自救心法）
- **下一篇（需求拆解）**：[07_SQL商業問題拆解框架.md](./07_SQL商業問題拆解框架.md)（5 步驟商業需求拆解思維模板）
- **實戰手寫題庫**：[09_30道B2B商業SQL實戰練習題.md](./09_30道B2B商業SQL實戰練習題.md)（特別推薦 Q21-Q30 跨表實戰與對帳）
- **結業考核**：[02_考試篇 結業考核](../02_考試篇/01_Exit_Exam_B2B商業數據偵探考題.md)（包含 AI JOIN 膨脹抓錯題）
- **回到目錄**：[Month 01 學習模組主導航](../README.md)
