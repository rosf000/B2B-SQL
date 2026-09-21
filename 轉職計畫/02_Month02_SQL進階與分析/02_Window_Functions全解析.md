# 02 Window Functions 視窗函數全解析

> **寫在前面：視窗函數是資料分析師最強的武器**
> 在日常業務分析中，有三類問題幾乎天天會遇到：
> 1. **排名**：「上個月誰是業績第一？各區業績前三名是誰？」
> 2. **同比 / 環比**：「相比上個月，這個月業績成長了幾趴？」
> 3. **累積**：「截至今天，本季的累積業績達標了嗎？」
>
> 這三類問題都能用視窗函數優雅解決——不需要複雜的自關聯，不需要子查詢，一行函數搞定。
>
> 📌 **環境準備（必做！升級真實大數據）**：
> 視窗函數的威力在於「**從數百數千筆高頻交易中，跨列與分組即時運算**」。先前的基礎資料庫僅 13 筆訂單，容易導致業務員每人每月只有 1 筆單，造成「CTE 聚合前是一筆、聚合後還是一筆，結果看起來都一樣」的無感狀況，且 2023 年無資料導致 YoY 出現 NULL。
> 
> 請先在 DBeaver 開啟並執行 Month 02 專用擴充資料庫腳本：
> 📁 **腳本路徑**：[b2b_m2_window_seed.sql](./data/b2b_m2_window_seed.sql)
> 內含 **2023～2024 年整整 24 個月、1,200+ 筆訂單、3,000+ 筆明細**，並特別埋設了「業務同分驗證」、「連續2月下滑預警」、「黑馬逆襲大躍進」等真實商業分析特徵點，邊讀邊跑保證刀刀見血！

---

## 🗺️ 視窗函數家族地圖

```
視窗函數（Window Functions）
  │
  ├── 排名函數
  │   ├── ROW_NUMBER()     — 連續唯一序號
  │   ├── RANK()           — 允許跳號的排名
  │   ├── DENSE_RANK()     — 不跳號的排名
  │   └── NTILE(n)         — 分組切割（四分位、百分位）
  │
  ├── 位移函數
  │   ├── LAG(col, n)      — 往前取第 n 列的值（環比分析）
  │   └── LEAD(col, n)     — 往後取第 n 列的值（預測/比較）
  │
  ├── 首尾值函數
  │   ├── FIRST_VALUE(col) — 視窗內的第一個值
  │   └── LAST_VALUE(col)  — 視窗內的最後一個值
  │
  └── 彙總型視窗函數
      ├── SUM() OVER ()    — 累積加總 / 分組加總
      ├── AVG() OVER ()    — 滑動平均
      ├── COUNT() OVER ()  — 分組計數
      └── MAX/MIN() OVER() — 分組最大最小值
```

---

## 一、視窗函數基礎語法

### 1.1 基本概念：什麼是「視窗」？

> 🎯 **心智定位（最重要的一件事）**：
> 視窗函數的本質，是在「不折疊原始資料列」的前提下，為每筆資料開一扇窗，讓它得以「旁觀」整個群體的統計值，同時保留自身明細。
>
> 💼 **為什麼非學不可（痛點場景）**：
> 主管要看「每筆訂單佔該客戶總消費的比例」或「連續兩月業績下滑預警」——若只用傳統 GROUP BY，資料列數會被強制壓縮，你只能硬啃多層自關聯（Self-Join），程式冗長且執行緩慢！

### 1.2 語法骨架

所有視窗函數都共享相同的語法結構：

```sql
函數名稱() OVER (
    PARTITION BY 分組欄位    -- 可選：類似 GROUP BY，但不會折疊列數
    ORDER BY 排序欄位        -- 可選：視窗內的資料排序
    ROWS/RANGE BETWEEN ...  -- 可選：定義視窗框架範圍
)
```

**和 GROUP BY 的關鍵差異**：

| 特性 | GROUP BY | OVER (視窗函數) |
|------|----------|----------------|
| 資料列數 | **折疊**：5 列 → 1 列 | **保留**：5 列還是 5 列 |
| 用途 | 聚合計算 | 計算後保留明細 |
| 可否同時看明細和彙總 | 否 | **是** |

---

### 1.3 💡 深度解密：視窗函數在 SQL 執行順序中的真正位置

許多學習者會疑惑：「視窗函數算是獨立的執行階段嗎？為什麼它不能直接寫在 `WHERE` 裡過濾？」

> 📌 **核心本質**：
> **視窗函數並不是獨立的頂層子句，它在語法上附屬於 `SELECT` 清單中；而在資料庫的底層邏輯執行順序中，它是 `SELECT` 階段內部「投影前先完成」的第一道計算。**

回顧 SQL 的經典邏輯執行順序（Logical Query Processing）：

```text
1. FROM & JOIN     — 抓取基表與關聯
2. WHERE           — 單筆資料列過濾
3. GROUP BY        — 分組折疊
4. HAVING          — 分組後聚合篩選
═════════════════════════════════════════════════════════════
5. SELECT 階段（內部包含 3 個微步驟 Micro-steps）：
   ├─ Step 5.1【視窗計算 (Window Evaluation)】
   │           資料庫在此時依據 PARTITION BY 切割視窗、
   │           依據 ORDER BY 排序，並計算出 RANK、LAG、SUM OVER 等數值。
   ├─ Step 5.2【欄位投影 (Projection) & 別名賦予】
   │           選取最終要呈現的欄位，將剛算好的視窗數值賦予別名。
   └─ Step 5.3【去重 (DISTINCT)】
               若有 DISTINCT，是在視窗函數算完之後才進行資料去重。
═════════════════════════════════════════════════════════════
6. ORDER BY        — 最終結果排序
7. LIMIT / OFFSET  — 截取特定筆數
```

#### 🧠 透過這個底層順序，可以解答 3 個實務大疑惑：

1. **疑惑一：為什麼視窗函數絕對不能寫在 `WHERE` 裡面？**
   * 因為 `WHERE`（Step 2）在 `SELECT`（Step 5）之前就執行完了！資料庫在過濾每一列時，視窗函數根本**還沒開始計算**，所以引擎會直接報錯：`ERROR: window functions are not allowed in WHERE`。
2. **疑惑二：為什麼視窗函數內部可以包含聚合函數？**
   * 例如 `RANK() OVER (ORDER BY SUM(total_amount) DESC)`。因為 `GROUP BY` 與聚合計算（Step 3 & 4）早在進入 `SELECT` 之前就已經完成，所以視窗函數計算時，能順利取到聚合後的 `SUM()` 數值！
3. **疑惑三：為什麼一定要用 CTE（或子查詢）才能做 Top N 篩選？**
   * 因為同一層查詢的 `WHERE` 無法讀取同一層 `SELECT` 產出的視窗結果。**唯一的解法就是透過 CTE，把算好視窗值的 `SELECT` 封裝成一張「下游虛擬表」**，外層的 `WHERE` 才能順理成章地把它當成普通欄位進行過濾！

---

## 二、排名函數

### 2.1 ROW_NUMBER、RANK、DENSE_RANK 三者比較

這三個函數最容易混淆，用一個例子徹底釐清：

```sql
-- 情境：業務員本月業績排名（假設有同分情況）
SELECT
    s.name                       AS 業務姓名,
    SUM(o.total_amount)          AS 月業績,

    -- 每人都有唯一序號，同分也不會有相同號碼（跳號）
    ROW_NUMBER() OVER (ORDER BY SUM(o.total_amount) DESC)  AS row_number,

    -- 同分者得相同名次，但下一名「跳號」
    -- 例：第 1 名有兩人，下一個是第 3 名（不是第 2 名）
    RANK()       OVER (ORDER BY SUM(o.total_amount) DESC)  AS rank,

    -- 同分者得相同名次，下一名「不跳號」
    -- 例：第 1 名有兩人，下一個是第 2 名
    DENSE_RANK() OVER (ORDER BY SUM(o.total_amount) DESC)  AS dense_rank

FROM salespeople s
JOIN orders o ON s.salesperson_id = o.salesperson_id
WHERE o.status = 'COMPLETED'
  -- 以 2024 年 11 月為例驗證同分場景（使用 Month 01 學過的標準日期範圍過濾）
  AND o.order_date >= '2024-11-01' AND o.order_date < '2024-12-01'
GROUP BY s.salesperson_id, s.name
ORDER BY 月業績 DESC;
```

**預期輸出示意**：

| 業務姓名 | 月業績 | ROW_NUMBER | RANK | DENSE_RANK |
|---------|--------|-----------|------|-----------|
| 王小明 | 1,200,000 | 1 | 1 | 1 |
| 李大華 | 1,200,000 | 2 | **1** | **1** |
| 張美玲 | 980,000 | 3 | **3** | **2** |
| 陳建國 | 750,000 | 4 | 4 | 3 |

> 💡 **選哪個？**
> - **ROW_NUMBER**：用於分頁、取 Top N 不想要同分並列（如：每人只能得一個獎）
> - **RANK**：體育競賽式排名，同分並列、有缺號
> - **DENSE_RANK**：客戶分級、RFM 分層，同分並列、無缺號

---

### 2.2 用 ROW_NUMBER 取每組 Top N

#### 🎯 核心痛點：為什麼一定要用 CTE？
很多初學者學到這裡會想偷懶，直接這樣寫：
```sql
-- ❌ 語法錯誤！PostgreSQL 會直接報錯：
-- ERROR: window functions are not allowed in WHERE
SELECT name, region, ROW_NUMBER() OVER (...) AS 排名
FROM salespeople
WHERE ROW_NUMBER() OVER (...) <= 3; -- 絕對不行！
```
> ⚠️ **關鍵原理（SQL 執行順序）**：
> 如 1.2 節所解密，SQL 執行順序是：`FROM` → `JOIN` → `WHERE` → `GROUP BY` → `HAVING` → **`SELECT（內含：視窗計算 ➜ 欄位投影）`** → `ORDER BY`。
> 因為 `WHERE` 遠比 `SELECT` 內部的視窗函數更早執行，資料庫在過濾每一列時「視窗名次根本還沒算出來」！
> **這正是為什麼一定要用 CTE（或子查詢）**：先在 CTE 內把排名算好（封裝成欄位），外層查詢才能在它自己的 `WHERE` 階段用 `WHERE 區內排名 <= 3` 來過濾！

---

#### 💼 實戰範例：每個地區（PARTITION BY）取業績前 3 名

在擴充資料庫中，全公司共有 18 位業務員（北中南各 6 位）：
* **CTE 內層**：計算 18 位業務員各自在該區的排名（1 ~ 6 名，共 18 列）。
* **外層篩選**：`WHERE 區內排名 <= 3`，各區 4、5、6 名**確實被過濾淘汰（淘汰 9 人）**，最終只精準產出 9 列！

```sql
WITH ranked_sales AS (
    -- 【CTE 內層】：完成聚合並計算分區排名（共 18 列，北中南各 6 名）
    SELECT
        s.region                                                 AS 地區,
        s.name                                                   AS 業務姓名,
        SUM(o.total_amount)                                      AS 總業績,
        ROW_NUMBER() OVER (
            PARTITION BY s.region              -- 按地區獨立分組
            ORDER BY SUM(o.total_amount) DESC  -- 各區內依業績由高到低排名
        )                                                        AS 區內排名
    FROM salespeople s
    LEFT JOIN orders o
        ON s.salesperson_id = o.salesperson_id
        AND o.status = 'COMPLETED'
    GROUP BY s.salesperson_id, s.name, s.region
)
-- 【CTE 外層】：過濾淘汰後半段（各區只留 Top 3，4~6名全數被篩除）
SELECT
    地區,
    區內排名,
    業務姓名,
    總業績
FROM ranked_sales
WHERE 區內排名 <= 3    -- 核心過濾：精確篩掉 9 人，只留 9 人
ORDER BY 地區, 區內排名;
```

**📊 預期輸出（CTE 前後對比立竿見影）：**

| 地區 | 區內排名 | 業務姓名 | 總業績 (約) | 狀態說明 |
|:---|:---:|:---|:---|:---|
| **Central** | 1 | Charlie Wang | $4,820,000 | 晉級 Top 3 |
| Central | 2 | Frank Liu | $3,950,000 | 晉級 Top 3 |
| Central | 3 | Leo Huang | $3,210,000 | 晉級 Top 3 |
| *(Central)* | *(4~6)* | *(Mandy, Nathan, Oscar)* | *($2M以下)* | **❌ 被 WHERE 篩除** |
| **North** | 1 | Alex Chen | $5,600,000 | 晉級 Top 3 |
| North | 2 | Betty Lin | $5,240,000 | 晉級 Top 3 |
| North | 3 | Grace Wu | $3,800,000 | 晉級 Top 3 |
| *(North)* | *(4~6)* | *(Ian, Judy, Kevin)* | *($2M以下)* | **❌ 被 WHERE 篩除** |
| **South** | 1 | David Ho | $4,980,000 | 晉級 Top 3 |
| South | 2 | Eva Chang | $3,760,000 | 晉級 Top 3 |
| South | 3 | Henry Kao | $3,450,000 | 晉級 Top 3 |
| *(South)* | *(4~6)* | *(Olivia, Peter, Queenie)*| *($2M以下)* | **❌ 被 WHERE 篩除** |

> 💡 **自我檢驗**：
> 試著把外層的 `WHERE 區內排名 <= 3` 註解掉，跑一次看看（會跑出 18 列）；再把條件加上（只剩 9 列）。
> 這一拿一放之間，你就能深刻體會到 **CTE 封裝視窗欄位 + 外層條件過濾** 的標準架構！

---

### 2.3 NTILE — 客戶消費分層

`NTILE(n)` 將資料均分為 n 個區段（bucket），常見應用場景包括：
- 四分位分析（`NTILE(4)`）
- 客戶消費分級（黃金 / 白銀 / 銅牌 / 一般）
- RFM 評分前置分層計算

```sql
WITH customer_total AS (
    SELECT
        c.customer_id,
        c.company_name,
        c.industry,
        COALESCE(SUM(o.total_amount), 0) AS total_spent
    FROM customers c
    LEFT JOIN orders o
        ON c.customer_id = o.customer_id
        AND o.status = 'COMPLETED'
    WHERE c.status = 'ACTIVE'
    GROUP BY c.customer_id, c.company_name, c.industry
)
SELECT
    company_name,
    industry,
    total_spent,
    -- 切為 4 個分位（1=最低消費, 4=最高消費）
    NTILE(4) OVER (ORDER BY total_spent ASC)    AS spending_quartile,
    CASE NTILE(4) OVER (ORDER BY total_spent ASC)
        WHEN 4 THEN '🏆 黃金客戶 (Top 25%)'
        WHEN 3 THEN '💎 白銀客戶 (25-50%)'
        WHEN 2 THEN '🥉 銅牌客戶 (50-75%)'
        WHEN 1 THEN '📋 一般客戶 (Bottom 25%)'
    END                                         AS 客戶等級
FROM customer_total
ORDER BY total_spent DESC;
```

> 💡 **排名函數核心收斂**：
> `ROW_NUMBER` 唯一不重複；`RANK` 同分跳號佔位；`DENSE_RANK` 緊密不跳號；**Top N 篩選必須透過 CTE 封裝才能在外層 `WHERE` 過濾！**

---

## 三、位移函數：LAG / LEAD

### 3.1 LAG — 環比分析（與上一期比較）

`LAG(column, n, default)` 取**前 n 列**的值，最常用於計算環比成長率（Month-over-Month, MoM）。

> 💡 **語法先備小補帖：為什麼這裡出現了 `DATE_TRUNC`？**  
> 在真實商業情境中，訂單是「每天」零散產生的。在計算「月度環比」前，我們必須先將每天的訂單「按月份歸納成一筆」：  
> - **`DATE_TRUNC('month', order_date)`**：PostgreSQL 的日期截斷函數，它會把時間無條件「截斷到該月 1 號」（例如 `2024-11-25` 與 `2024-11-03` 都會被歸納為 `2024-11-01`），這樣就能用 `GROUP BY` 按月分組加總。  
> - **`::date`**：PostgreSQL 的強制型別轉換符號，將截斷後的完整時間戳（Timestamp）轉為乾淨的純日期格式。  
> 📌 *免驚！下週 [03_日期字串處理與效能優化入門.md](./03_日期字串處理與效能優化入門.md) 會對日期函數做地毯式深度解析；本章我們先把它當作「按月歸納」的現成工具，將學習焦點集中在視窗函數 `LAG()` 與 `LEAD()` 上！*

```sql
WITH monthly_revenue AS (
    SELECT
        -- DATE_TRUNC('month', ...) 將訂單日期統一歸入該月 1 號，以便按月聚合
        DATE_TRUNC('month', order_date)::date  AS month,
        SUM(total_amount)                       AS revenue
    FROM orders
    WHERE status = 'COMPLETED'
    GROUP BY DATE_TRUNC('month', order_date)
)
SELECT
    month                                           AS 月份,
    revenue                                         AS 當月業績,
    -- LAG 取上個月的業績（若無上一月，預設為 NULL）
    LAG(revenue, 1) OVER (ORDER BY month)           AS 上月業績,
    -- 環比成長率
    CASE
        WHEN LAG(revenue, 1) OVER (ORDER BY month) IS NULL THEN NULL
        ELSE ROUND(
            (revenue - LAG(revenue, 1) OVER (ORDER BY month))
            / LAG(revenue, 1) OVER (ORDER BY month) * 100,
            1
        )
    END                                             AS 環比成長率_百分比
FROM monthly_revenue
ORDER BY month;
```

---

### 3.2 LAG 搭配 PARTITION BY — 各業務環比分析

#### ① 先說這一段最重要的事（核心結論）
> **當計算對象包含「多個業務員、多家分店或多種產品」時，視窗函數中必須加上 `PARTITION BY` 做分區隔離。**  
> 漏掉 `PARTITION BY` 時，在「第一位業務員」內部看似完全正常，但一跨到「第二位業務員的首月」就會發生嚴重的**跨人資料污染（上一人的尾月業績偷渡為下一人的上月業績）**！

---

#### ② 告訴學生為什麼重要（踩坑實錄：為什麼你實作時會覺得「根本沒差」？）

很多同學在 DBeaver 照著範例實作拿掉 `PARTITION BY` 測試時，常會產生兩個巨大的困惑：
> ❓ **困惑 1**：「老師，我在外層把 `PARTITION BY salesperson_id` 拿掉，為什麼前幾十列算出來的環比成長率**真的一模一樣、完全沒差**？」  
> ❓ **困惑 2**：「為什麼有時候我改了 `上月業績` 那行，執行結果的 `上月業績` 明明變了，但後面的 `環比成長率` 卻**依然紋風不動**？」

這背後隱藏了兩個極易迷惑工程師的**「視覺盲點」**與**「語法陷阱」**：

1. **視覺盲點（第一位業務員 Alex Chen 的假象）**：  
   在我們的資料庫中，按 `salesperson_id, month` 排序時，前 24 筆資料全部都是 `Alex Chen`（2023-01 至 2024-12）。  
   在 `Alex Chen` 個人內部，2 月的上月本來就是 1 月、3 月的上月本來就是 2 月。因此，無論你有沒有寫 `PARTITION BY`，**Alex Chen 內部 24 個月的環比成長率確實 100% 完全一模一樣**！  
   💥 **真正的重大災難，只發生在交接點：第 25 列（Alex Chen 結束，Betty Lin 剛開始的第 1 個月）！**
2. **語法陷阱（重複寫 3 次 OVER 導致修改脫鉤）**：  
   如果你在同一個 `SELECT` 裡面寫了 3 次 `LAG(...) OVER (...)`：
   - 1 次給 `上月業績`
   - 1 次給 `環比成長率` 的分子 `(revenue - LAG(...))`
   - 1 次給 `環比成長率` 的分母 `NULLIF(LAG(...), 0)`  
   當你做實驗想拿掉 `PARTITION BY` 時，往往只隨手改了第 1 個 `上月業績`，**卻漏改了分子與分母**！這就是為什麼你會看到「上月業績變了，成長率卻沒變」——因為分子分母依然偷偷在跑原本的 `PARTITION BY`！

---

#### ③ 解釋原理：兩層 CTE 職責分離（最佳工程實務）

為了徹底根除「重複複製 3 次視窗代碼」與「改了分子漏了分母」的軟體工程大忌，實務上**強烈推薦拆分兩層 CTE**：
- **第一層 CTE (`sp_monthly`)**：負責聚合（`GROUP BY`），把每天零散的訂單壓縮為「每人每月一筆」。
- **第二層 CTE (`sp_with_lag`)**：專門開窗位移，全查詢**只寫唯一一次** `LAG(revenue) OVER (PARTITION BY salesperson_id ORDER BY month)`，產出 `prev_revenue`。
- **第三層 主查詢 (`SELECT`)**：專心做數學除法 `(revenue - prev_revenue) / prev_revenue * 100`。

> 🌟 **好處**：全查詢只有一個 `prev_revenue` 變數，分子分母直接引用，乾淨俐落，絕不可能發生脫鉤！

---

#### ④ 給例子：完整示範代碼（精準鎖定交接點驗證）

為了讓你在 DBeaver 螢幕上不用翻 24 列就能親眼見證「交接點車禍」，我們在第一層 CTE 篩選 **Alex Chen (id: 1)** 與 **Betty Lin (id: 2)** 在 2023 年前 3 個月的業績：

```sql
-- 第一層：按業務與月份彙總當月業績（篩選 Alex 與 Betty 驗證交接點）
WITH sp_monthly AS (
    SELECT
        s.salesperson_id,
        s.name                                  AS 業務姓名,
        s.region                                AS 地區,
        DATE_TRUNC('month', o.order_date)::date AS month,
        SUM(o.total_amount)                     AS revenue
    FROM salespeople s
    JOIN orders o ON s.salesperson_id = o.salesperson_id
    WHERE o.status = 'COMPLETED'
      AND s.salesperson_id IN (1, 2)
      AND o.order_date >= '2023-01-01' AND o.order_date < '2023-04-01'
    GROUP BY s.salesperson_id, s.name, s.region, DATE_TRUNC('month', o.order_date)
),
-- 第二層：只寫一次 LAG，為每位業務建立獨立隔離視窗
sp_with_lag AS (
    SELECT
        salesperson_id,
        業務姓名,
        地區,
        month,
        revenue,
        LAG(revenue) OVER (
            PARTITION BY salesperson_id    -- 關鍵：換業務時強制清空重置為 NULL
            ORDER BY month
        ) AS prev_revenue
    FROM sp_monthly
)
-- 第三層：直接引用 prev_revenue 算成長率，零重複、不脫鉤！
SELECT
    業務姓名,
    地區,
    month                                                         AS 月份,
    revenue                                                       AS 當月業績,
    prev_revenue                                                  AS 上月業績,
    ROUND(
        (revenue - prev_revenue) / NULLIF(prev_revenue, 0) * 100,
        1
    )                                                             AS 環比成長率_百分比
FROM sp_with_lag
ORDER BY salesperson_id, month;
```

> 💡 **進階技巧：PostgreSQL 命名視窗語法 (`WINDOW w AS (...)`)**  
> 若不想多寫一層 CTE，可使用 SQL 標準的 `WINDOW` 關鍵字將視窗命名固化，避免重複複製：
> ```sql
> SELECT
>     業務姓名,
>     month,
>     revenue,
>     LAG(revenue) OVER w AS 上月業績,
>     ROUND((revenue - LAG(revenue) OVER w) / NULLIF(LAG(revenue) OVER w, 0) * 100, 1) AS 環比成長率
> FROM sp_monthly
> WINDOW w AS (PARTITION BY salesperson_id ORDER BY month)
> ORDER BY salesperson_id, month;
> ```

---

#### 📊 現場實驗：拿掉 `PARTITION BY` 會發生什麼事？

請在 DBeaver 中將第二層 CTE 的 `PARTITION BY salesperson_id` 拿掉，直接對比兩者在「業務交界處」的輸出結果：

**✅ 正確輸出：有 `PARTITION BY salesperson_id`（各自獨立包廂）**

| salesperson_id | 業務姓名 | 月份 | 當月業績 | 上月業績 (`prev_revenue`) | 環比成長率 | 說明 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | **Alex Chen** | 2023-01-01 | 850,000 | `NULL` | `NULL` | Alex 首月，無歷史數據 |
| 1 | **Alex Chen** | 2023-02-01 | 1,120,000 | 850,000 | +31.8% | 正常計算 |
| 1 | **Alex Chen** | 2023-03-01 | 980,000 | 1,120,000 | -12.5% | 正常計算 |
| 2 | **Betty Lin** | 2023-01-01 | 920,000 | **`NULL`** | **`NULL`** | ✅ **獨立包廂！Betty 首月乾淨為 NULL** |
| 2 | **Betty Lin** | 2023-02-01 | 1,050,000 | 920,000 | +14.1% | 正常計算 |

---

**❌ 錯誤輸出：拿掉 `PARTITION BY`，只寫 `OVER (ORDER BY salesperson_id, month)`**

| salesperson_id | 業務姓名 | 月份 | 當月業績 | 上月業績 (`prev_revenue`) | 環比成長率 | 說明 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | **Alex Chen** | 2023-01-01 | 850,000 | `NULL` | `NULL` | Alex 完全不受影響 |
| 1 | **Alex Chen** | 2023-02-01 | 1,120,000 | 850,000 | +31.8% | Alex 依然完全不受影響 |
| 1 | **Alex Chen** | 2023-03-01 | 980,000 | 1,120,000 | -12.5% | Alex 依然完全不受影響（**這就是你覺得沒差的原因！**） |
| 2 | **Betty Lin** | 2023-01-01 | 920,000 | **980,000** | **-6.1%** | 💥 **重大車禍！Betty 1 月竟然吃到 Alex 3 月的業績！** |
| 2 | **Betty Lin** | 2023-02-01 | 1,050,000 | 920,000 | +14.1% | 正常計算 |

> [!CAUTION]
> ### 💣 結論：CTE 裡的 `GROUP BY` 與視窗函數的 `PARTITION BY` 職責完全不同！
> 1. **CTE 裡的 `GROUP BY`**：負責把「每天」的多筆訂單**聚合壓縮成每人每月一筆**，產出的是一張包含全公司所有業務的大平表。
> 2. **外層的 `PARTITION BY`**：負責在大平表裡為每位業務**拉起獨立隔離的計算視窗**。若沒有它，SQL 的視窗就是整張大平表，當指針從「Alex Chen」交棒到「Betty Lin」時，`LAG()` 就會直接盲目抓取上一行——把 Alex Chen 的業績當作 Betty Lin 的上期業績！

---

#### ⑤ 讓學生自己做（課堂即時思考驗證）

<details>
<summary>🎯 思考題：如果拿掉 PARTITION BY 時，視窗排序只寫 <code>OVER (ORDER BY month)</code>（漏掉了 salesperson_id），結果又會發生什麼更詭異的現象？（點擊展開分析）</summary>

**分析**：  
如果只依 `month` 排序，那麼在 2023-01 這個月份裡，Alex Chen 和 Betty Lin 會排在一起！  
- Alex Chen (2023-01): `prev_revenue = NULL`
- Betty Lin (2023-01): `prev_revenue` 竟然直接抓到 **Alex Chen 同一個月份 (2023-01)** 的業績！  
這代表 Betty 1 月的環比成長率，竟然是拿自己的 1 月跟 Alex 的 1 月比，完全失去時間軸環比（MoM）的意義！  
👉 **結論：多實體計算位移時，`PARTITION BY` 絕對不能省！**
</details>

---

#### ⑥ 最後再次收斂成一句話
> 💡 **業務環比核心金句**：  
> **GROUP BY 壓平明細，PARTITION BY 隔離個體；二層 CTE 抽離 LAG，從此告別脫鉤與漏改！**

---

### 3.3 LEAD — 往後預覽

`LEAD(column, n)` 取**後 n 列**的值，常見應用場景：
- 計算每次購買後「距下次購買」的間隔天數
- 預覽下一個業務事件或價格變動

```sql
-- 情境：計算每位客戶每次購買後，距離下次購買的間隔天數
SELECT
    c.company_name               AS 客戶名稱,
    o.order_date                 AS 本次購買日,
    o.total_amount               AS 本次金額,
    LEAD(o.order_date) OVER (
        PARTITION BY o.customer_id
        ORDER BY o.order_date
    )                            AS 下次購買日,
    (
        LEAD(o.order_date) OVER (
            PARTITION BY o.customer_id
            ORDER BY o.order_date
        ) - o.order_date
    )                            AS 距下次購買天數
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.status = 'COMPLETED'
ORDER BY c.company_name, o.order_date;
```

> 💡 **位移函數核心收斂**：
> `LAG` 往前偷看做環比，`LEAD` 往後預覽下一期；首期缺失自動為 `NULL`，必要時用 `COALESCE` 補預設值。

---

## 四、首尾值函數：FIRST_VALUE / LAST_VALUE

### 4.1 FIRST_VALUE — 比較首期基準

**情境**：計算每月業績相對於「該年 1 月」的成長幅度（年初基準比較）

```sql
WITH monthly_revenue AS (
    SELECT
        EXTRACT(YEAR FROM order_date)::int   AS year,
        EXTRACT(MONTH FROM order_date)::int  AS month,
        SUM(total_amount)                    AS revenue
    FROM orders
    WHERE status = 'COMPLETED'
    GROUP BY EXTRACT(YEAR FROM order_date), EXTRACT(MONTH FROM order_date)
)
SELECT
    year                    AS 年份,
    month                   AS 月份,
    revenue                 AS 當月業績,
    FIRST_VALUE(revenue) OVER (
        PARTITION BY year
        ORDER BY month
    )                       AS 一月基準業績,
    ROUND(
        (revenue - FIRST_VALUE(revenue) OVER (PARTITION BY year ORDER BY month))
        / FIRST_VALUE(revenue) OVER (PARTITION BY year ORDER BY month) * 100,
        1
    )                       AS 相對一月成長率_百分比
FROM monthly_revenue
ORDER BY year, month;
```

> [!IMPORTANT]
> #### 為什麼視窗一定要寫 `PARTITION BY year ORDER BY month`？
>
> `monthly_revenue` 是一張**跨年度的平表**（2023 全年 + 2024 全年混在一起）。若省略 `PARTITION BY year`，視窗就會橫跨所有年份，`FIRST_VALUE` 只會抓到「全表 month 最小的那一筆」，導致 2024 年全年都拿 2023-01 做基準，完全失去「年初基準比較」的商業意義。
>
> | 視窗寫法 | `FIRST_VALUE` 抓到的 | 結果 |
> |:---|:---|:---:|
> | `PARTITION BY year ORDER BY month` | **各年自己的 1 月** | ✅ 正確 |
> | `ORDER BY year, month`（無 PARTITION BY） | 永遠是 2023-01 | ❌ 2024 基準錯誤 |
> | `ORDER BY month`（只按月排） | 2023 與 2024 同月混排，結果不穩定 | 💥 不可預期 |
>
> **`PARTITION BY year` 的作用是「每年重新歸零」**——讓視窗在跨過年份邊界時強制重置，`FIRST_VALUE` 才能各自抓到「那一年的 1 月」。這與 LAG 使用 `PARTITION BY salesperson_id` 防止跨人污染的道理完全相同：**不加 PARTITION BY，視窗就是整張大平表；加了，才能按商業邏輯分組隔離。**

---

### 4.2 LAST_VALUE 的陷阱與視窗框架（Frame）

#### ① 為什麼會有這個陷阱？（預設行為的隱形坑）
`FIRST_VALUE` 和 `LAST_VALUE` 看似是對稱的雙胞胎，但實際執行時大家會發現：**`FIRST_VALUE` 怎麼寫都對，`LAST_VALUE` 卻常常失靈**！

這是因為當你在 `OVER ()` 裡面寫了 `ORDER BY` 時，SQL 標準底層會**偷偷幫你加上一段預設的視窗框架（Window Frame）**：
> 預設框架：`RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`  
> （白話文：**從分組的第一列，一直算到「當前這整列」為止**）

* 對 `FIRST_VALUE` 來說：第一列永遠在視窗的第一個位置，所以不管算到哪一列，抓「第一個」都是正確的！
* 對 `LAST_VALUE` 來說：因為視窗只看到**當前列**，它眼中的「最後一列」永遠就是**當前自己這一列**！這導致算出來的最後值跟當前值一模一樣，完全沒有意義。

---

#### ② 語法拆解：`ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`
為了讓 `LAST_VALUE` 能夠看到「整組真正的最後一筆」，我們必須手動打破預設限制，把視窗框架直接拉滿到整組的最底端：

```text
ROWS BETWEEN   UNBOUNDED PRECEDING    AND    UNBOUNDED FOLLOWING
────┬─────    ──────────┬────────           ──────────┬────────
    │                   │                             │
 指定依實體列     起點：無上限往前（第一列）         終點：無上限往後（最後一列）
```

* **`ROWS`**：指定以「資料列（Row）」為計算單位。
* **`BETWEEN <起點> AND <終點>`**：定義視窗的搜尋範圍區間。
* **`UNBOUNDED PRECEDING`**：起點為「最頂端第一列」（無邊界無上限往前）。
* **`UNBOUNDED FOLLOWING`**：終點為「最底端最後一列」（無邊界無上限往後）。

> 💡 **白話翻譯**：「請幫我把視窗打開到最大——從最上面第一列，一直看到最下面最後一列！」

---

#### ③ 實戰對比：寫與不寫的差別

```sql
-- ❌ 錯誤寫法：未指定框架，預設只看到當前列
SELECT
    month,
    revenue,
    LAST_VALUE(revenue) OVER (
        ORDER BY month
    ) AS 錯誤的最後值  -- 結果永遠等於當月 revenue！
FROM monthly_revenue;

-- ✅ 正確寫法：手動將框架擴展至「全組最後一列」
SELECT
    month,
    revenue,
    LAST_VALUE(revenue) OVER (
        ORDER BY month
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS 正確的最後值  -- 每一列都能看到 12 月的業績！
FROM monthly_revenue;
```

**📊 執行結果對比示意**：

| month | revenue | 錯誤的最後值 (預設到當前列) | 正確的最後值 (展開到整組末尾) |
|:---:|---:|---:|---:|
| 1 月 | 100 萬 | **100 萬** (只看到 1 月) | **300 萬** (整組最後是 12 月) |
| 2 月 | 120 萬 | **120 萬** (只看到 2 月) | **300 萬** |
| 3 月 | 150 萬 | **150 萬** (只看到 3 月) | **300 萬** |
| … | … | … | **300 萬** |
| 12 月 | 300 萬 | **300 萬** | **300 萬** |

> 📌 **觀念總結**：
> `FIRST_VALUE` 不需要特別指定框架，因為起點預設本來就是第一列；但只要用到 **`LAST_VALUE`**，就必須牢記加上 `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`，否則它永遠只會回傳自己！
> （在接下來的 **第五節**，我們會更深入介紹視窗框架如何用來做「累積加總」與「滑動平均」。）

---

## 五、彙總型視窗函數與視窗框架

### 5.1 累積加總（Running Total）

```sql
-- 情境：計算全年業績的累積加總，即時掌握年度目標達成進度
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', order_date)::date AS month,
        SUM(total_amount)                      AS revenue
    FROM orders
    WHERE status = 'COMPLETED'
      -- 篩選 2024 全年度訂單（標準日期範圍過濾）
      AND order_date >= '2024-01-01' AND order_date < '2025-01-01'
    GROUP BY DATE_TRUNC('month', order_date)
)
SELECT
    month,
    revenue                               AS 當月業績,
    SUM(revenue) OVER (
        ORDER BY month
        ROWS BETWEEN UNBOUNDED PRECEDING   -- 從第一列
        AND CURRENT ROW                    -- 到當前列
    )                                     AS 累積業績,
    -- 假設年度目標為 5,000萬
    ROUND(
        SUM(revenue) OVER (ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
        / 50000000 * 100, 1
    )                                     AS 年度目標達成率
FROM monthly_revenue
ORDER BY month;
```

---

### 5.2 滑動平均（Moving Average）

消除月份的季節性波動，看出業績的長期趨勢：

```sql
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', order_date)::date AS month,
        SUM(total_amount)                      AS revenue
    FROM orders
    WHERE status = 'COMPLETED'
    GROUP BY DATE_TRUNC('month', order_date)
)
SELECT
    month,
    revenue                                              AS 當月業績,
    -- 3 個月滑動平均（當月 + 前 2 個月）
    ROUND(
        AVG(revenue) OVER (
            ORDER BY month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ),
        0
    )                                                    AS 三個月滑動均值,
    -- 6 個月滑動平均
    ROUND(
        AVG(revenue) OVER (
            ORDER BY month
            ROWS BETWEEN 5 PRECEDING AND CURRENT ROW
        ),
        0
    )                                                    AS 六個月滑動均值
FROM monthly_revenue
ORDER BY month;
```

---

### 5.3 視窗框架語法速查

```sql
ROWS BETWEEN ... AND ...
-- 常用框架組合：

UNBOUNDED PRECEDING AND CURRENT ROW     -- 從頭到當前列（累積用）
UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING  -- 整個分組（用於 FIRST/LAST VALUE）
1 PRECEDING AND 1 FOLLOWING             -- 當前列的前後各 1 列（3列滑動）
2 PRECEDING AND CURRENT ROW             -- 前 2 列到當前列（3列累積均值）
CURRENT ROW AND UNBOUNDED FOLLOWING     -- 當前列到最後（逆向累積）
```

---

### 5.4 分組佔比計算

**情境**：計算每位業務的業績佔所在地區的百分比

```sql
WITH sp_sales AS (
    SELECT
        s.salesperson_id,
        s.name                               AS 業務姓名,
        s.region                             AS 地區,
        COALESCE(SUM(o.total_amount), 0)     AS 個人業績
    FROM salespeople s
    LEFT JOIN orders o
        ON s.salesperson_id = o.salesperson_id
        AND o.status = 'COMPLETED'
    GROUP BY s.salesperson_id, s.name, s.region
)
SELECT
    地區,
    業務姓名,
    個人業績,
    -- 地區總業績（PARTITION BY region，OVER 整個分組）
    SUM(個人業績) OVER (PARTITION BY 地區)    AS 地區總業績,
    -- 個人佔地區的百分比
    ROUND(
        個人業績 * 100.0
        / NULLIF(SUM(個人業績) OVER (PARTITION BY 地區), 0),
        1
    )                                         AS 地區佔比_百分比,
    -- 在地區內的排名
    RANK() OVER (PARTITION BY 地區 ORDER BY 個人業績 DESC) AS 地區排名
FROM sp_sales
ORDER BY 地區, 地區排名;
```

> 💡 **視窗框架核心收斂**：
> 省略框架時，`ORDER BY` 預設累積到當前列；加上 `UNBOUNDED FOLLOWING` 才能涵蓋整個分組；`ROWS` 限定實體列數，是做滑動均值、消除季節波動的關鍵利器。

---

## 六、同比分析（Year-over-Year）

同比 = 跟去年同期比，是財務報表中最常見的分析維度。

```sql
WITH monthly_by_year AS (
    SELECT
        EXTRACT(YEAR FROM order_date)::int    AS year,
        EXTRACT(MONTH FROM order_date)::int   AS month,
        SUM(total_amount)                     AS revenue
    FROM orders
    WHERE status = 'COMPLETED'
    GROUP BY EXTRACT(YEAR FROM order_date), EXTRACT(MONTH FROM order_date)
)
SELECT
    m1.year                                          AS 年份,
    m1.month                                         AS 月份,
    m1.revenue                                       AS 本年業績,
    m2.revenue                                       AS 去年同期業績,
    ROUND(
        (m1.revenue - COALESCE(m2.revenue, 0))
        / NULLIF(m2.revenue, 0) * 100, 1
    )                                                AS 同比成長率_百分比,
    CASE
        WHEN m2.revenue IS NULL       THEN '📊 去年無資料'
        WHEN m1.revenue > m2.revenue  THEN '📈 成長'
        WHEN m1.revenue < m2.revenue  THEN '📉 衰退'
        ELSE                               '➡️  持平'
    END                                              AS 同比趨勢
FROM monthly_by_year m1
LEFT JOIN monthly_by_year m2
    ON m1.month = m2.month                     -- 同月份
    AND m1.year = m2.year + 1                  -- 本年 vs 去年
ORDER BY m1.year, m1.month;
```

---

## 七、商業情境練習題（8 題・主動回想與防暴雷版）

> ⚠️ **刻意練習指引**：
> 視窗函數是面試現場白板題的重災區。請務必在 DBeaver 空白頁先自己寫出查詢，跑出結果後再點開解答對照！

---

### 題目 1：業務員月業績排名（含並列處理）

**需求**：產出每個月的業務員業績排名，同分時並列，不跳號。顯示：月份、業務姓名、月業績、月排名。

<details>
<summary>💡 需要思考提示嗎？（點擊展開提示）</summary>

1. 先用 CTE 按月份（`DATE_TRUNC('month', order_date)`）與業務員分組加總業績。
2. 同分並列且「不跳號」應使用 `DENSE_RANK()`。
3. 視窗分區依據為月份（`PARTITION BY month`），排序為業績降冪（`ORDER BY revenue DESC`）。
</details>

<details>
<summary>✅ 寫完了？點擊查看參考解答與詳解</summary>

```sql
WITH monthly_sp AS (
    SELECT
        DATE_TRUNC('month', o.order_date)::date AS month,
        s.name                                  AS 業務姓名,
        SUM(o.total_amount)                     AS 月業績
    FROM salespeople s
    JOIN orders o ON s.salesperson_id = o.salesperson_id
    WHERE o.status = 'COMPLETED'
    GROUP BY DATE_TRUNC('month', o.order_date), s.salesperson_id, s.name
)
SELECT
    month,
    業務姓名,
    月業績,
    DENSE_RANK() OVER (PARTITION BY month ORDER BY 月業績 DESC) AS 月排名
FROM monthly_sp
ORDER BY month, 月排名;
```
</details>

---

### 題目 2：找出業績連續下滑 2 個月以上的業務員

**需求**：找出「連續 2 個月業績下滑」的業務員，提供主管早期預警。

<details>
<summary>💡 需要思考提示嗎？（點擊展開提示）</summary>

1. 第一層 CTE 計算每人每月業績。
2. 第二層 CTE 使用 `LAG(revenue, 1)` 取上月業績，`LAG(revenue, 2)` 取上上月業績（皆按 `salesperson_id` 分區）。
3. 主查詢過濾：`當月 < 上月 AND 上月 < 上上月`，注意排除包含 NULL 的前兩月。
</details>

<details>
<summary>✅ 寫完了？點擊查看參考解答與詳解</summary>

```sql
WITH monthly_sp AS (
    SELECT
        s.salesperson_id,
        s.name,
        DATE_TRUNC('month', o.order_date)::date AS month,
        SUM(o.total_amount)                     AS revenue
    FROM salespeople s
    JOIN orders o ON s.salesperson_id = o.salesperson_id
    WHERE o.status = 'COMPLETED'
    GROUP BY s.salesperson_id, s.name, DATE_TRUNC('month', o.order_date)
),
with_lag AS (
    SELECT
        salesperson_id,
        name,
        month,
        revenue,
        LAG(revenue, 1) OVER (PARTITION BY salesperson_id ORDER BY month) AS prev1,
        LAG(revenue, 2) OVER (PARTITION BY salesperson_id ORDER BY month) AS prev2
    FROM monthly_sp
)
SELECT DISTINCT name AS 業務姓名, month AS 連續下滑截止月份
FROM with_lag
WHERE revenue < prev1
  AND prev1 < prev2
  AND prev1 IS NOT NULL
  AND prev2 IS NOT NULL
ORDER BY month DESC, name;
```
</details>

---

### 題目 3：客戶消費四分位分析

**需求**：將所有 ACTIVE 客戶按照年度消費額切為四等份，輸出每個客戶的等級與評分。

<details>
<summary>💡 需要思考提示嗎？（點擊展開提示）</summary>

1. 第一段 CTE 聚合每家客戶 2024 年度的累計消費額。
2. 使用 `NTILE(4) OVER (ORDER BY annual_spending DESC)` 將客戶分成 4 等份。
3. 搭配 `CASE WHEN` 賦予商業標籤（黃金、白銀、銅牌、一般）。
</details>

<details>
<summary>✅ 寫完了？點擊查看參考解答與詳解</summary>

```sql
WITH customer_annual AS (
    SELECT
        c.customer_id,
        c.company_name,
        c.industry,
        COALESCE(SUM(o.total_amount), 0) AS annual_spending
    FROM customers c
    LEFT JOIN orders o
        ON c.customer_id = o.customer_id
        AND o.status = 'COMPLETED'
        AND EXTRACT(YEAR FROM o.order_date) = 2024
    WHERE c.status = 'ACTIVE'
    GROUP BY c.customer_id, c.company_name, c.industry
)
SELECT
    company_name,
    industry,
    annual_spending,
    NTILE(4) OVER (ORDER BY annual_spending DESC) AS 分位等級,
    CASE NTILE(4) OVER (ORDER BY annual_spending DESC)
        WHEN 1 THEN '🏆 黃金 (Top 25%)'
        WHEN 2 THEN '💎 白銀 (25-50%)'
        WHEN 3 THEN '🥉 銅牌 (50-75%)'
        WHEN 4 THEN '📋 一般 (Bottom 25%)'
    END AS 客戶等級
FROM customer_annual
ORDER BY annual_spending DESC;
```
</details>

---

### 題目 4：計算每月累積業績與年度目標達成率

**需求**：假設年度目標為 6,000 萬，顯示 2024 年每月的累積業績與達成率。

<details>
<summary>💡 需要思考提示嗎？（點擊展開提示）</summary>

1. 先用 CTE 計算每月的業績總和。
2. 累積業績使用 `SUM(revenue) OVER (ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)`。
3. 達成率為 `累積業績 / 60,000,000.0 * 100`。
</details>

<details>
<summary>✅ 寫完了？點擊查看參考解答與詳解</summary>

```sql
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', order_date)::date AS month,
        SUM(total_amount)                     AS revenue
    FROM orders
    WHERE status = 'COMPLETED'
      AND EXTRACT(YEAR FROM order_date) = 2024
    GROUP BY DATE_TRUNC('month', order_date)
)
SELECT
    TO_CHAR(month, 'YYYY-MM')                                AS 月份,
    revenue                                                  AS 當月業績,
    SUM(revenue) OVER (ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                                                             AS 累積業績,
    ROUND(
        SUM(revenue) OVER (ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
        / 60000000.0 * 100, 1
    )                                                        AS 年度達成率
FROM monthly
ORDER BY month;
```
</details>

---

### 題目 5：產品類別的 3 個月滑動平均銷售額

**需求**：消除季節性波動，計算各產品類別的 3 個月滑動平均銷售額。

<details>
<summary>💡 需要思考提示嗎？（點擊展開提示）</summary>

1. CTE 先計算各產品類別按月彙總的銷售額。
2. 3 個月滑動平均使用：`AVG(revenue) OVER (PARTITION BY category ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)`。
</details>

<details>
<summary>✅ 寫完了？點擊查看參考解答與詳解</summary>

```sql
WITH monthly_cat AS (
    SELECT
        p.category,
        DATE_TRUNC('month', o.order_date)::date AS month,
        SUM(oi.quantity * oi.unit_price)         AS category_revenue
    FROM order_items oi
    JOIN products p  ON oi.product_id = p.product_id
    JOIN orders o    ON oi.order_id = o.order_id
    WHERE o.status = 'COMPLETED'
    GROUP BY p.category, DATE_TRUNC('month', o.order_date)
)
SELECT
    category                                                AS 類別,
    month                                                   AS 月份,
    category_revenue                                        AS 當月銷售額,
    ROUND(
        AVG(category_revenue) OVER (
            PARTITION BY category
            ORDER BY month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ), 0
    )                                                       AS 三個月滑動均值
FROM monthly_cat
ORDER BY category, month;
```
</details>

---

### 題目 6：找出每個客戶最高單筆訂單及其佔該客戶總消費的比例

**需求**：識別哪些客戶的消費高度集中在單筆大訂單（風險：大客戶可能因一筆訂單取消而損失慘重）。

<details>
<summary>💡 需要思考提示嗎？（點擊展開提示）</summary>

1. 不需要 GROUP BY 折疊列！直接在每筆訂單上開窗。
2. `SUM(total_amount) OVER (PARTITION BY customer_id)` 取得該客戶總消費。
3. `MAX(total_amount) OVER (PARTITION BY customer_id)` 取得該客戶最高單筆。
4. 單筆金額除以總消費，搭配 `NULLIF(..., 0)` 計算佔比。
</details>

<details>
<summary>✅ 寫完了？點擊查看參考解答與詳解</summary>

```sql
SELECT
    c.company_name,
    o.order_number,
    o.order_date,
    o.total_amount                                              AS 單筆金額,
    SUM(o.total_amount) OVER (PARTITION BY o.customer_id)      AS 客戶總消費,
    MAX(o.total_amount) OVER (PARTITION BY o.customer_id)      AS 最高單筆,
    ROUND(
        o.total_amount * 100.0
        / NULLIF(SUM(o.total_amount) OVER (PARTITION BY o.customer_id), 0),
        1
    )                                                          AS 佔總消費比例,
    o.total_amount = MAX(o.total_amount) OVER (PARTITION BY o.customer_id)
                                                               AS 是否為最大單
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.status = 'COMPLETED'
ORDER BY 佔總消費比例 DESC;
```
</details>

---

### 題目 7：同比成長率分析（各月 vs 去年同期）

**需求**：產出 2024 年每個月的業績與 2023 年同期的比較，並標示成長或衰退。

<details>
<summary>💡 需要思考提示嗎？（點擊展開提示）</summary>

1. 先按年份（yr）與月份（mo）分組計算月度營收。
2. 自關聯（LEFT JOIN）前一年的同月份：`curr.mo = prev.mo AND curr.yr = prev.yr + 1`。
3. 計算成長率 `(本期 - 上期) / 上期 * 100`，配合 CASE WHEN 標註趨勢。
</details>

<details>
<summary>✅ 寫完了？點擊查看參考解答與詳解</summary>

```sql
WITH yearly_monthly AS (
    SELECT
        EXTRACT(YEAR FROM order_date)::int    AS yr,
        EXTRACT(MONTH FROM order_date)::int   AS mo,
        SUM(total_amount)                     AS revenue
    FROM orders
    WHERE status = 'COMPLETED'
      AND EXTRACT(YEAR FROM order_date) IN (2023, 2024)
    GROUP BY yr, mo
)
SELECT
    curr.mo                                     AS 月份,
    curr.revenue                                AS Y2024業績,
    prev.revenue                                AS Y2023業績,
    ROUND(
        (curr.revenue - COALESCE(prev.revenue, 0))
        / NULLIF(prev.revenue, 0) * 100, 1
    )                                           AS 同比成長率,
    CASE
        WHEN curr.revenue > COALESCE(prev.revenue, 0) THEN '📈 成長'
        WHEN curr.revenue < prev.revenue             THEN '📉 衰退'
        ELSE '➡️ 持平'
    END                                         AS 同比趨勢
FROM yearly_monthly curr
LEFT JOIN yearly_monthly prev
    ON curr.mo = prev.mo AND curr.yr = prev.yr + 1
WHERE curr.yr = 2024
ORDER BY curr.mo;
```
</details>

---

### 題目 8：用視窗函數找出每個地區的「業績黑馬」

**需求**：在每個地區中，找出「本月業績排名比上月排名進步最多」的業務員。

<details>
<summary>💡 需要思考提示嗎？（點擊展開提示）</summary>

1. 第一層 CTE 計算每人每月業績，並用 `DENSE_RANK() OVER (PARTITION BY region, month ...)` 算當月排名。
2. 第二層 CTE 用 `LAG(monthly_rank)` 取上月排名，並計算 `上月排名 - 本月排名`（正數代表名次進步）。
3. 主查詢找出各地區當月進步幅度等於最大值（`MAX()`）的人選。
</details>

<details>
<summary>✅ 寫完了？點擊查看參考解答與詳解</summary>

```sql
WITH monthly_ranked AS (
    SELECT
        s.salesperson_id,
        s.name,
        s.region,
        DATE_TRUNC('month', o.order_date)::date AS month,
        SUM(o.total_amount)                     AS revenue,
        DENSE_RANK() OVER (
            PARTITION BY s.region, DATE_TRUNC('month', o.order_date)
            ORDER BY SUM(o.total_amount) DESC
        )                                       AS monthly_rank
    FROM salespeople s
    JOIN orders o ON s.salesperson_id = o.salesperson_id
    WHERE o.status = 'COMPLETED'
    GROUP BY s.salesperson_id, s.name, s.region, DATE_TRUNC('month', o.order_date)
),
with_rank_change AS (
    SELECT
        *,
        LAG(monthly_rank) OVER (PARTITION BY salesperson_id ORDER BY month) AS last_rank,
        LAG(monthly_rank) OVER (PARTITION BY salesperson_id ORDER BY month) - monthly_rank
            AS rank_improvement   -- 正數 = 排名進步（數字變小）
    FROM monthly_ranked
)
SELECT
    region                AS 地區,
    name                  AS 業務黑馬,
    month                 AS 月份,
    monthly_rank          AS 本月排名,
    last_rank             AS 上月排名,
    rank_improvement      AS 進步幾名
FROM with_rank_change
WHERE rank_improvement = (
    -- 找出各地區當月進步最多的
    SELECT MAX(w2.rank_improvement)
    FROM with_rank_change w2
    WHERE w2.region = with_rank_change.region
      AND w2.month = with_rank_change.month
      AND w2.rank_improvement > 0
)
ORDER BY month DESC, region;
```
</details>

> 💡 **視窗函數綜合實戰核心收斂**：
> 明細保留不壓縮，開窗計算旁觀群體；排名、位移、框架三組工具各司其職，複雜分析一次到位。

---

## 八、本章重點彙整

### 排名函數

| 函數 | 同分處理 | 典型用途 |
|:---|:---|:---|
| `ROW_NUMBER()` | 強制唯一，無並列 | 分頁、取 Top N（每人一名） |
| `RANK()` | 並列後跳號 | 體育競賽、有缺號的公開排行 |
| `DENSE_RANK()` | 並列後不跳號 | 客戶等級分層、RFM 評分 |
| `NTILE(n)` | 均分為 n 個區段 | 四分位分析、百分位切割 |

### 位移函數

| 函數 | 方向 | 典型用途 |
|:---|:---|:---|
| `LAG(col, n)` | 往前取第 n 列 | 環比（MoM）、同比前置計算 |
| `LEAD(col, n)` | 往後取第 n 列 | 購買間隔天數、下一事件預覽 |

### 彙總型視窗函數

| 寫法 | 效果 |
|:---|:---|
| `SUM() OVER (ORDER BY … ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)` | 累積加總（Running Total） |
| `AVG() OVER (ROWS BETWEEN n PRECEDING AND CURRENT ROW)` | 滑動平均（Moving Average） |
| `SUM() OVER (PARTITION BY …)` | 分組佔比分母計算 |

### 視窗框架速查

| 框架語法 | 意涵 |
|:---|:---|
| `UNBOUNDED PRECEDING AND CURRENT ROW` | 從頭累積到當前列（最常用） |
| `n PRECEDING AND CURRENT ROW` | 固定 n+1 列的滑動視窗 |
| `UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` | 涵蓋整個分組（配合 LAST_VALUE） |
| `CURRENT ROW AND UNBOUNDED FOLLOWING` | 當前列至末尾（逆向累積） |

---

*下一篇：[03 日期、字串處理與效能優化入門](./03_日期字串處理與效能優化入門.md)*
