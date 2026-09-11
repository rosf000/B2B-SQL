# A2｜學習驗收 Checkpoints：每月三維度自我驗收標準

> 每個月完成後填寫。未達標請勿進入下一個月。

## 用途

這不是學習清單，而是**驗收標準**。

每個 Checkpoint 涵蓋三個維度：
1. **Skills** — 技術概念是否理解
2. **Project** — 實作成果是否存在
3. **Explain** — 能不能講給別人聽（面試關鍵）

---

## Month 01 Checkpoint

**完成日期：**＿＿＿＿

### Skills

- [ ] 能建立 PostgreSQL Database 並 import CSV 資料
- [ ] 能寫 SELECT / WHERE / ORDER BY / LIMIT / DISTINCT
- [ ] 能寫 COUNT / SUM / AVG / MAX / MIN
- [ ] 能寫 GROUP BY / HAVING
- [ ] 能寫 CASE WHEN
- [ ] 能正確使用 INNER JOIN / LEFT JOIN
- [ ] **能 Debug SQL（看到錯誤能找到原因並修正）**
- [ ] Git init / add / commit / push 操作熟練
- [ ] GitHub 有 README

### Project

- [ ] GitHub Repository 已建立
- [ ] 至少 10 條 commit 歷史（不是一次全推）
- [ ] 30 道商業 SQL 題完成 20 道以上
- [ ] SQL 筆記整理完成

### Explain（能用自己的話說清楚）

- [ ] INNER JOIN 和 LEFT JOIN 的差別是什麼？
- [ ] GROUP BY 和 WHERE 的差別是什麼？
- [ ] HAVING 什麼時候用？
- [ ] 為什麼這條 SQL 跑很慢？（Index 初步概念）

---

## Month 02 Checkpoint

**完成日期：**＿＿＿＿

### Skills

- [ ] Subquery 能獨立寫出
- [ ] CTE（WITH 語句）能熟練使用
- [ ] ROW_NUMBER / RANK / DENSE_RANK 差別清楚
- [ ] LAG / LEAD 能用在時序分析
- [ ] 日期處理（DATE_TRUNC / EXTRACT）
- [ ] 字串處理（CONCAT / TRIM / SPLIT_PART）

### Project

- [ ] Project 1 銷售分析完成並上傳 GitHub
- [ ] README 有結果截圖 / 分析說明
- [ ] 至少包含：月趨勢、客戶分群、業務績效三個分析

### Explain

- [ ] CTE 和 Subquery 什麼時候用哪個？
- [ ] Window Function 和 GROUP BY 的差別？
- [ ] Cohort 分析的邏輯是什麼？

---

## Month 03 Checkpoint

**完成日期：**＿＿＿＿

### Skills

- [ ] 能設計 B2B ER Diagram（含關聯）
- [ ] 知道 1NF / 2NF / 3NF 各是什麼
- [ ] Index 的用途和使用時機
- [ ] Transaction / ACID 各字母能解釋
- [ ] 理解 Migration 概念（Schema 是會變的）

### Project

- [ ] B2B Database Schema 設計完成
- [ ] ER Diagram 圖檔存入 GitHub
- [ ] 能說明為什麼這樣設計

### Explain

- [ ] 為什麼 Customer 和 Order 是一對多？
- [ ] Index 加了一定變快嗎？什麼情況反而變慢？
- [ ] 如果客戶表要新增一個欄位，怎麼 Migration？

---

## Month 04 Checkpoint

**完成日期：**＿＿＿＿

### Skills

- [ ] Function / Exception / File I/O / JSON / datetime 都能用
- [ ] requests 能呼叫 API 並處理回應
- [ ] Virtual Environment 能建立，requirements.txt 能產生
- [ ] **Type Hint 開始在 function 使用**

### Project

- [ ] Excel 整理工具完成
- [ ] 重複資料檢查工具完成
- [ ] 批次命名工具完成
- [ ] 三個工具都在 GitHub，有 README

### Explain

- [ ] 為什麼 Python 要用 Virtual Environment？
- [ ] Exception 怎麼設計才不會把錯誤吞掉？
- [ ] Type Hint 的目的是什麼？

---

## Month 05 Checkpoint

**完成日期：**＿＿＿＿

### Skills

- [ ] SQLAlchemy 能連 PostgreSQL 並執行 CRUD
- [ ] Logging 有設定（不是只用 print）
- [ ] .env 設定 credential，不 commit 到 Git
- [ ] Config 集中管理（不是 hardcode）
- [ ] Retry 機制能處理連線失敗

### Project

- [ ] ETL Pipeline 能完整跑通（Excel → 清洗 → PostgreSQL）
- [ ] 有 logs/ 目錄，執行後自動產生 log 檔
- [ ] **有 tests/ 目錄，至少三個測試可以跑**
- [ ] README 有別人能跟著跑的說明

### Explain

- [ ] 為什麼 ETL 要分成 extract / transform / load 三個步驟？
- [ ] Logging 和 print 有什麼差別？
- [ ] 什麼是 Transaction？如果 load 到一半失敗怎麼辦？

---

## Month 06 Checkpoint

**完成日期：**＿＿＿＿

### Skills

- [ ] Pandas merge / groupby / pivot_table 能用
- [ ] fillna / dropna / astype 能處理資料品質問題
- [ ] requests 能處理 Pagination 和 Authentication
- [ ] **Data Quality 函數能獨立寫（validate_email / check_duplicate / check_null）**

### Project

- [ ] API → Pandas 清洗 → PostgreSQL 管線完成
- [ ] Data Quality 模組建立（data_quality/ 資料夾）
- [ ] AI Code Review 紀錄至少一次

### Explain

- [ ] 什麼是資料完整性（Completeness）？
- [ ] Pandas apply 和 vectorization 的效能差別？
- [ ] 你的 Data Quality 模組解決了哪個真實問題？

---

## Month 07 Checkpoint

**完成日期：**＿＿＿＿

### Skills

- [ ] Linux 基本指令熟練（ls / grep / chmod / ssh / tail）
- [ ] docker-compose up 能啟動 PostgreSQL + App
- [ ] .gitignore 正確設定（.env 不在 Git 裡）
- [ ] Commit message 有規範（feat / fix / docs）
- [ ] **AI Coding 工作流正式建立（有書面 SOP，存於 `A1_AI協作工作流SOP/` 目錄）**

### Project

- [ ] docker-compose.yml 啟動 PostgreSQL + PgAdmin 成功
- [ ] `A1_AI協作工作流SOP/` 資料夾有至少一篇 AI 協作工作記錄

### Explain

- [ ] Docker Image 和 Container 的差別？
- [ ] 為什麼 .env 不能 commit 到 GitHub？
- [ ] 你的 AI Coding Workflow 是怎麼運作的？

---

## Month 08 Checkpoint（旗艦作品）

**完成日期：**＿＿＿＿

### Skills

- [ ] B2B 旗艦系統架構能畫出來（從 ETL 到 API 到 AI）
- [ ] 系統跑通（V1 至少：ETL → PostgreSQL → Analytics）
- [ ] 能解釋每個元件為什麼存在

### Project

- [ ] GitHub 旗艦 Repository 有完整 README
- [ ] Architecture Diagram 存在
- [ ] ER Diagram 存在
- [ ] Demo（截圖或影片）存在
- [ ] **已開始投履歷（至少投出 5 間）**

### Explain

- [ ] 你的旗艦系統解決了什麼 B2B 問題？
- [ ] 你的 ETL 遇到資料品質問題怎麼處理？
- [ ] 如果 AI Agent 生成了一條錯誤的 SQL，你的系統怎麼防止它執行？

---

## Month 09–12 Checkpoint（簡化版）

**M9 FastAPI**
- [ ] 旗艦系統有完整 CRUD API
- [ ] Swagger UI 文件完整
- [ ] Postman 可測試所有 Endpoint

**M10 Docker 部署**
- [ ] docker-compose 一鍵啟動成功
- [ ] 雲端有可公開的 Demo URL
- [ ] GitHub README 有 Demo 連結

**M11 Airflow / AI Agent**
- [ ] Airflow DAG 能定時跑 ETL，失敗會 Alert
- [ ] 或：AI Agent 多角色能完整跑通一個查詢
- [ ] Project 4 上傳 GitHub

**M12 求職**
- [ ] 至少投遞 30 間
- [ ] 面試筆記完整（被問到什麼 / 哪裡答不好）
- [ ] 根據面試回饋更新技能
