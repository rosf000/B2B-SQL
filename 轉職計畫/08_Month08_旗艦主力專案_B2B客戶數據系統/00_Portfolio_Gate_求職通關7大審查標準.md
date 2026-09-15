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

## ⚡ Gate 3 — Live SQL（白板現場寫 SQL 不手軟）

**【考核目標】**：面試官出題時，你不需要依賴 AI 或 Google，現場能在 IDE 或白板寫出複雜查詢。

- [ ] **現場寫出 JOIN + 條件聚合**：
  - 快速計算各業務員當季已完成訂單的總銷售額、達成率與客單價。
- [ ] **現場寫出 CTE + Window Functions**：
  - 現場寫出 `ROW_NUMBER()` 取得各產業消費最高的 Top 1 客戶。
  - 現場寫出 `LAG()` 計算企業月營收增長率（MoM）。

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

## 🛡️ Gate 6 — Failure & Resilience（系統容錯與災難防禦）

**【考核目標】**：面對以下 4 大面試官必考「災難情境」，你能給出工程解法：

1. **「資料庫連線超載或掛掉（DB Down）怎麼辦？」**
   - *回答要點*：連線池（Connection Pool）上限限制、Circuit Breaker（斷路器機制）、API 端回傳 `503 Service Unavailable` 並觸發 Slack 監控警報。
2. **「外部 API 或資料源 Timeout 怎麼辦？」**
   - *回答要點*：設定顯式逾時時間（`timeout=5.0`）、結合 Tenacity 實現「指數退避重試（Exponential Backoff Retry）」、落盤暫存重試佇列。
3. **「ETL 腳本重跑（Rerun）資料重複怎麼辦？」**
   - *回答要點*：實作冪等性（Idempotency），透過 PostgreSQL `ON CONFLICT DO UPDATE` 或 Staging 表交易替換。
4. **「AI 產生幻覺（Hallucination）寫出語法正確但邏輯錯誤的 SQL 怎麼辦？」**
   - *回答要點*：在 Prompt 中注入 Few-Shot 業務標準 SQL 範例；在結果層加入業務常理檢核（如：營收不可能為負數）。

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
