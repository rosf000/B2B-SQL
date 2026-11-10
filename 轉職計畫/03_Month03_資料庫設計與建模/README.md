# Month 03｜資料庫設計與建模：從「查詢資料」升級為「設計架構」

> **🔗 承接 M01/M02**：你在 M01 一直查詢的 `customers`、`orders`、`order_items`，以及 M02 用 Window Functions 跑業績分析的那個 B2B 資料庫 — 是**有人刻意設計過**的。那個設計背後有正規化原則、索引策略和 ACID 保護。
>
> **M03 核心目標**：從「用別人設計好的 schema 查資料」，升級為「自己設計生產級 schema」。本月結束後，你會懂得為什麼 M02 的某些查詢走 Seq Scan 而不是 Index Scan、以及如何讓你的 M02 分析 SQL 固化成 Materialized View 讓同事直接用。

---

## 🗺️ Month 03 四步架構師修煉旅程（Roadmap）

```mermaid
flowchart TD
    S1["第 1 週：ER 建模 ＋ 三大正規化<br/>閱讀 01 講義 ➜ 消除資料冗餘 ➜ 掌握 1NF/2NF/3NF 與反正規化權衡"]
    S2["第 2 週：索引底層 ＋ ACID 交易安全<br/>閱讀 02 講義 ➜ 深入 B-Tree 結構 ➜ 掌握事務控制與 4 大隔離層級"]
    S3["第 3 週：DDL/DML 約束防呆 ＋ 運維備份<br/>閱讀 03 講義 ➜ 設置 CHECK 與外鍵防線 ➜ View 物化視圖 ➜ pg_dump 備份演練"]
    S4["第 4 週：Milestone 專案 ＋ 審查考核<br/>繪製生產級 ER 圖 ➜ 產出 DDL 腳本 ➜ 通過 Exit Exam 抓出 AI 6 大設計漏洞！"]

    S1 --> S2 --> S3 --> S4
```

---

## 📂 本模組教材文件導航

| 序號 | 篇章名稱 | 核心目標與學習內容 | 推薦時機 |
| :---: | :--- | :--- | :---: |
| **00** | [00_學習計畫與總覽.md](./00_學習計畫與總覽.md) | 📅 **4 週 28 天每日學習排程**、從 M01/M02 銜接橋樑、Git Commit 規範與晉級標準 | 開學第一天必讀 |
| **01** | [01_關聯式資料庫設計規範與正規化.md](./01_關聯式資料庫設計規範與正規化.md) | 資料異常三種類型、1NF/2NF/3NF 函數相依實例、多對多中介表、反正規化 (Denormalization) 的時機與權衡 | 第 1 週 |
| **02** | [02_Index索引原理與ACID交易機制.md](./02_Index索引原理與ACID交易機制.md) | B-Tree 索引結構、最左前綴原則、索引失效陷阱、ACID 四大特性、隔離等級與 MVCC、FOR UPDATE 防超賣 | 第 2 週 |
| **03** | [03_PostgreSQL_DDL_DML與管理實務.md](./03_PostgreSQL_DDL_DML與管理實務.md) | `CREATE TABLE` 完整語法、`ALTER TABLE` 安全遷移、`CHECK`/`FK ON DELETE` 約束、View vs Materialized View、Trigger 自動化、UPSERT | 第 3 週 |
| **04** | [04_Exit_Exam_Schema_Review_Challenge.md](./04_Exit_Exam_Schema_Review_Challenge.md) | 🎓 **本月結業測驗**：審查 AI 設計的「毒瘤」Schema，抓出 6 大地雷、重構 3NF DDL 並執行 Constraint 破壞性測試 | 第 4 週 |
| **DB** | [database/](./database/) | 🛠️ **練習資料庫**：`01_b2b_m3_bad_schema.sql`（刻意設計錯誤的 schema，練習識別問題）、`02_b2b_m3_refactored_schema.sql`（標準重構版，作為參考解答） | 第 1 週起動手用 |
| **專案** | [Milestone_B2B關聯式資料庫設計/](./Milestone_B2B關聯式資料庫設計/README.md) | 🏆 **生產級架構里程碑**：包含 Customers, Products, Orders, Order_Items, Salespeople, Invoices 的完整 Mermaid ER 圖與生產級 DDL 腳本 | 第 4 週 |

---

## 🎯 本月三層完成度標準 (Three-Tier Mastery)

- 🟢 **Level 1 — Survival (必做及格線)**：
  - [ ] 理解 Primary Key、Foreign Key、Unique Key 與 NULL 約束。
  - [ ] 能看懂 ER 圖並寫出簡單的 `CREATE TABLE` 與 `ALTER TABLE`。
  - [ ] 理解 Transaction 基本指令（`BEGIN`, `COMMIT`, `ROLLBACK`）。
- 🔵 **Level 2 — Job Ready (標準求職線，80分晉級)**：
  - [ ] 掌握 1NF / 2NF / 3NF 正規化原則，能獨立設計一對多與多對多中介表。
  - [ ] 掌握 `CHECK Constraint` 與 `NUMERIC` 精度防呆，避免髒資料入庫。
  - [ ] 完成 **Milestone: B2B 關聯式資料庫架構設計**。
  - [ ] 通過 **[04_Exit_Exam_Schema_Review_Challenge.md](./04_Exit_Exam_Schema_Review_Challenge.md)**（抓出 AI 6 大設計漏洞並重構）。
- 🔴 **Level 3 — Bonus (面試溢價線)**：
  - [ ] 掌握 View vs Materialized View 定期刷新 Trade-off。
  - [ ] 深入理解 ACID 中 Isolation Level（4大隔離層級）與死鎖 (Deadlock) 排錯。
  - [ ] 掌握 `pg_dump` 備份與還原災難復原實務。
