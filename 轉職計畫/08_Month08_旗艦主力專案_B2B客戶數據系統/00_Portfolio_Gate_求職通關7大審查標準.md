# 🏆 M8 Portfolio Gate：求職通關 7 大審查標準

> **「在履歷上放一個 GitHub 連結很容易；但能通過以下 7 個 Gate 審查的作品，才是面試官願意當場發 Offer 的關鍵。」**

M8 是整套教材最重要的里程碑。當你完成本專案時，**不要急著把履歷撒出去**。請以「嚴苛資深架構師」的角度，對自己的專案進行這 7 道通關審查（Portfolio Gates）。

---

## 🏛️ Gate 1 — Architecture（系統架構能說也能畫）

**【考核目標】**：面試官若給你一張白紙，你能否在 2 分鐘內畫出清晰的系統架構圖並解釋資料流向？

- [ ] **能畫出標準資料與後端分層架構**：
  ```
  [Client / User]
         │ (HTTP / JSON)
         ▼
  [FastAPI Gatekeeper] ── (Pydantic Request Validation)
         │
         ▼
  [Service / Business Layer] ── (Cleanse, Levenshtein Deduplication, RFM Engine)
         │
         ▼
  [Data Access Layer (SQLAlchemy 2.0)] ── (Connection Pool)
         │
         ▼
  [PostgreSQL 18+ Warehouse] (3NF Relational Schema)
  ```
- [ ] **能清楚解釋為什麼這樣分層**：為什麼不能直接在 FastAPI 路由裡面寫生 SQL？分層對未來的單元測試（Unit Test）與維護有什麼好處？

---

## 🗄️ Gate 2 — Data Pipeline（端到端資料工程能力）

**【考核目標】**：能清楚解釋髒資料從來源端到落盤的完整歷程。

- [ ] **清楚定義 Data Grain（資料粒度）**：
  - 例如：`b2b_orders` 的粒度是一筆訂單；`b2b_order_items` 的粒度是一筆訂單中的單一產品品項。
- [ ] **具備生產級去重能力**：
  - 解釋為何統編（8 碼統一編號）與公司名稱（Levenshtein 模糊比對）需要雙軌並行去重。
- [ ] **資料庫 Schema 符合 3NF（第三正規化）**：
  - 業務員、客戶、產品、訂單、明細分表，無多餘重複欄位，具備嚴格的 `FOREIGN KEY (ON DELETE RESTRICT)` 約束。

---

## ⚡ Gate 3 — Live SQL（白板現場寫 SQL 防衛抽考）

**【考核目標】**：面試官出題時，你不需要依賴 AI 或 Google，現場能在 IDE 或白板寫出複雜商業查詢。

### 🃏 現場抽考題 1：計算各業務員當季業績與達成率（JOIN + 條件聚合）
**情境**：請寫出一條 SQL，計算每位業務員在 2026 年 Q2 的總成交金額（只計 `APPROVED` 訂單）、目標達成率與平均客單價。

<details>
<summary>🔑 點擊展開「白板 SQL 標準擬答」</summary>

```sql
SELECT
    s.salesperson_id,
    s.name,
    s.monthly_quota * 3 AS q2_quota,
    COALESCE(SUM(o.total_amount), 0) AS q2_actual_revenue,
    ROUND(
        COALESCE(SUM(o.total_amount), 0) / NULLIF(s.monthly_quota * 3, 0) * 100, 
        2
    ) AS achievement_rate_pct,
    ROUND(AVG(o.total_amount), 2) AS avg_order_value
FROM b2b_salespeople s
LEFT JOIN b2b_orders o 
    ON s.salesperson_id = o.salesperson_id
    AND o.status = 'APPROVED'
    AND o.order_date >= '2026-04-01' AND o.order_date <= '2026-06-30'
GROUP BY s.salesperson_id, s.name, s.monthly_quota
ORDER BY q2_actual_revenue DESC;
```
</details>

---

### 🃏 現場抽考題 2：各產業消費最高的 Top 1 客戶與營收 MoM（Window Function）
**情境**：
1. 找出每個「產業類別（industry）」中累計消費總額最高的 Top 1 客戶（使用 `ROW_NUMBER()`）。
2. 計算公司過去 12 個月每月的營收與月增率 MoM%（使用 `LAG()`）。

<details>
<summary>🔑 點擊展開「白板 SQL 標準擬答」</summary>

```sql
-- 1. 各產業消費 Top 1 客戶
WITH RankedCustomers AS (
    SELECT
        c.industry,
        c.company_name,
        SUM(o.total_amount) AS total_spend,
        ROW_NUMBER() OVER (
            PARTITION BY c.industry 
            ORDER BY SUM(o.total_amount) DESC
        ) AS rank_in_industry
    FROM b2b_customers c
    JOIN b2b_orders o ON c.customer_id = o.customer_id
    WHERE o.status = 'APPROVED'
    GROUP BY c.industry, c.company_name
)
SELECT industry, company_name, total_spend
FROM RankedCustomers
WHERE rank_in_industry = 1;

-- 2. 月營收與 MoM 月增率
WITH MonthlyRevenue AS (
    SELECT
        DATE_TRUNC('month', order_date)::DATE AS sales_month,
        SUM(total_amount) AS revenue
    FROM b2b_orders
    WHERE status = 'APPROVED'
    GROUP BY DATE_TRUNC('month', order_date)
)
SELECT
    sales_month,
    revenue,
    LAG(revenue) OVER (ORDER BY sales_month) AS prev_month_revenue,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY sales_month)) 
        / NULLIF(LAG(revenue) OVER (ORDER BY sales_month), 0) * 100, 
        2
    ) AS mom_growth_pct
FROM MonthlyRevenue
ORDER BY sales_month;
```
</details>

---

## 🔌 Gate 4 — API Contract（API 契約與強型別驗證）

**【考核目標】**：後端接口具備強防禦力，不信任任何前端或外部傳入的 Payload。

- [ ] **定義清楚的 RESTful 端點與 HTTP Status Code**：
  - `POST /api/v1/orders` ➜ 成功 `201 Created`；驗證失敗 `422 Unprocessable Entity`；客戶不存在 `404 Not Found`。
- [ ] **Pydantic Validation 邊界防呆**：
  - 金額欄位必須 `Field(gt=0)`；Email 格式檢核；統編長度限制為 8 碼數字。
- [ ] **自動化 Swagger UI 交互文檔**：
  - 啟動後能在 `/docs` 進行直觀測試與參數說明。

---

## 🤖 Gate 5 — AI Safe Flow（企業級 AI 安全防衛鏈）

**【考核目標】**：徹底杜絕「將 LLM 直接連上 Production 資料庫」的致命低級錯誤。

面試時請大聲向面試官展示你的 **AI 安全邊界防禦鏈（Guardrails）**：

```
                    【危險的業餘做法 (面試直接出局)】
          User ──> LLM ──> Raw SQL ──> Production Database (恐被 SQL Injection / DROP TABLE 刪庫)

                    【企業級 AI 防禦鏈 (我們的設計)】
User (提問)
  │
  ▼
[LLM (SQL Generator)] ── (只給予 Schema DDL，不提供真實敏感資料)
  │ (Raw SQL Candidate)
  ▼
[SQL Validator (AST 語法解析)] ── 🚨 攔截 DROP, DELETE, UPDATE, ALTER，只允許 SELECT
  │ (Approved Safe Query)
  ▼
[Permission & Read-Only Gate] ── 🔒 強制使用資料庫 read_only_analyst 帳號與限時連線
  │ (Execute Query with LIMIT 1000)
  ▼
[Result Validator] ── ⚠️ 筆數異常檢驗 (是否查出空值或超過十萬筆記憶體炸彈？)
  │ (Sanitized Data Result)
  ▼
[LLM (Insight Explainer)] ── (轉化為白話商業結論與圖表建議)
  │
  ▼
User (接收商業決策建議)
```

- [ ] **你能口述並在程式碼中指認出這道防禦鏈**。

---

## 🛡️ Gate 6 — Failure & Resilience（四大災難防衛對答）

**【考核目標】**：面對以下 4 大面試官必考「災難情境」，你能給出工程解法：

### 🃏 災難 1：「資料庫連線超載或掛掉（DB Down）怎麼辦？」
<details>
<summary>🔑 點擊展開「架構防衛標準擬答」</summary>

- **連線池上限與排隊溢位**：SQLAlchemy Engine 設定 `pool_size=20, max_overflow=10, pool_timeout=30`，避免並發打爆 PG 連線上限。
- **Circuit Breaker（斷路器機制）**：若連續 5 次連線失敗，立即熔斷不再發出新請求，API 直接回傳 `503 Service Unavailable`，防止雪崩。
- **即時告警**：在例外層觸發 Webhook，推播至 Slack / PagerDuty 通知工程師。
</details>

### 🃏 災難 2：「外部 API 或資料源 Timeout 怎麼辦？」
<details>
<summary>🔑 點擊展開「架構防衛標準擬答」</summary>

- **顯式設定雙逾時**：`requests.get(url, timeout=(3.0, 10.0))`，絕對不允許無上限掛死。
- **指數退避 + Full Jitter 重試**：使用 `urllib3 Retry` 或 `tenacity`，重試間隔為 $1s, 2s, 4s$ 並疊加隨機抖動，避免雷鳴群效應。
- **死信佇列（Dead Letter Queue）**：重試 3 次仍失敗，將 Payload 寫入本地 `dead_letter.jsonl`，確保資料不遺失並支援後續重放。
</details>

### 🃏 災難 3：「ETL 腳本重跑（Rerun）資料重複怎麼辦？」
<details>
<summary>🔑 點擊展開「架構防衛標準擬答」</summary>

- **設計完全冪等性（Idempotency）**：
  - 維度表：採用 PostgreSQL 原生 `ON CONFLICT (customer_code) DO UPDATE SET ...`。
  - 事實表 / 日分區：在 Transaction 內「先刪除該日舊分區，再寫入新批次」，確保無論重跑 1 次還是 100 次，最終資料庫數據毫釐不差。
</details>

### 🃏 災難 4：「AI 產生幻覺（Hallucination）寫出語法正確但邏輯錯誤的 SQL 怎麼辦？」
<details>
<summary>🔑 點擊展開「架構防衛標準擬答」</summary>

- **Few-Shot Prompting 錨定**：在 System Prompt 中提供 5 組高頻的標準業務 SQL 範例（如毛利率計算公式、MoM 寫法）。
- **SQL AST 解析器過濾**：使用 `sqlglot` 或 `sqlparse` 驗證查詢結構，嚴禁任何 DDL/DML。
- **Result Guard 業務常識驗證**：檢查查詢結果的邊界值（如營收不得為負數、達成率不超過 1000%），若異常則觸發 LLM Self-Correction 自動重新修正。
</details>

---

## 🎬 Gate 7 — 3-Minute High-Impact Demo（高轉換率展示）

**【考核目標】**：錄製或現場進行 3 分鐘不卡頓的流暢 Demo。

- **00:00 - 00:30【商業痛點】**：
  - *「傳統 B2B 企業業務員常用 Excel 各自記帳，導致客戶重複建檔、歷史數據無法整合，主管每到月底要花三天手動拉報表。」*
- **00:30 - 01:30【系統架構與自動化實作】**：
  - 展示資料庫 3NF 設計、執行 `data_cleaner.py` 瞬間揪出模糊比對重複客戶、展示自動生成的 RFM 與 MoM 戰報。
- **01:30 - 02:30【AI 智慧查詢與安全鏈路】**：
  - 在前端或 API 輸入：「請列出上個月貢獻度前 3 名的製造業客戶」。
  - **刻意展示安全防禦**：輸入「幫我把訂單表清空」，展示系統 `SQL Validator` 成功攔截並報警！
- **02:30 - 03:00【商業價值量化】**：
  - *「這套系統能將報表產出效率提升 90%，並確保 100% 冪等性與企業資料安全。」*

---

## 🎖️ 通關判定 (Sign-off)

- [ ] Gate 1: 架構手繪流暢
- [ ] Gate 2: 資料流與 Grain 解釋清晰
- [ ] Gate 3: 現場 SQL 考核無死角
- [ ] Gate 4: API 與型別防呆就緒
- [ ] Gate 5: AI 安全防護鏈落地
- [ ] Gate 6: 四大災難情境能流暢對答
- [ ] Gate 7: 3 分鐘 Demo 影片錄製完成

> **🎉 當 7 個 Gate 全數通過，代表你的作品已經具備超越市場上 80% 轉職者的堅固實力！現在，自信地開啟求職投遞！**
