# 🚀 12 個月 IT 轉職實戰教材庫（B2B × AI-Native Data Engineer）

> **「你的核心競爭力不是『我會 Python』，而是『我懂 B2B 商業問題，能用 AI + 技術解決它』。」**

歡迎來到專為 **非本科轉職 Data/Automation Engineer** 量身打造的 12 個月實戰教材體系。本計畫以 **B2B 商業領域知識** 為底座，整合 SQL、Database、Python ETL、FastAPI、Docker、Airflow 與 AI Agent，打造一個真正有商業辨識度的工程師作品集。

---

## 🎯 職涯定位

```
一般轉職者：「我會 Python / SQL / Docker」
你：「我懂 B2B 商業問題 + SQL + Database + Python ETL + AI Agent + Automation」
```

**目標職稱：** Data Engineer ／ Data Automation Engineer ／ B2B Data Platform Engineer

---

## 🗺️ 12 個月學習地圖（AI-Native 版）

```mermaid
flowchart TD
    subgraph Phase1 [第一階段：SQL + Database + Git (M1-M3)]
        M1["Month 01: SQL 基礎\n+ Git/GitHub 第一天就建立"] --> M2["Month 02: SQL 進階分析\nWindow Functions / CTE"]
        M2 --> P1["🎯 Project 1: 銷售資料多維度分析"]
        P1 --> M3["Month 03: 資料庫設計與建模\n+ AI 生成 Schema → 你 Review"]
    end

    subgraph Phase2 [第二階段：Python + ETL (M4-M6)]
        M3 --> M4["Month 04: Python（目標導向）\n只學 B2B 工作需要的"]
        M4 --> M5["Month 05: Python × ETL × Database\nLogging / Config / Error Handling"]
        M5 --> P2["🎯 Project 2: 自動化 ETL Pipeline"]
        P2 --> M6["Month 06: Pandas + API\n+ AI Code Review 習慣建立"]
    end

    subgraph Phase3 [第三階段：工程素養 (M7)]
        M6 --> M7["Month 07: Linux + Docker + AI Workflow\nAI Coding 工作流正式建立"]
    end

    subgraph Phase4 [第四階段：旗艦作品 (M8-M9)]
        M7 --> P3["🔥 Project 3 (旗艦): AI-Augmented B2B Data Platform\nM8 完成 → 開始投履歷"]
        P3 --> M9["Month 09: FastAPI API 化\nCRUD + Swagger + 基礎 Auth"]
    end

    subgraph Phase5 [第五階段：部署 + 深化 (M10-M11)]
        M9 --> M10["Month 10: Docker 部署 + 雲端\n一鍵啟動、可 Demo 的 URL"]
        M10 --> M11["Month 11: Airflow 排程\n+ AI Agent 多角色系統"]
        M11 --> P4["🤖 Project 4: Data Pipeline / AI Agent System"]
    end

    subgraph Phase6 [求職持續推進 (M8 起)]
        P3 -.->|M8 開始投| JOB["M12: 求職衝刺\n根據 JD 補強、面試 50 題、持續投遞"]
    end

    style P1 fill:#e1f5fe,stroke:#0288d1,stroke-width:2px
    style P2 fill:#e8f5e9,stroke:#388e3c,stroke-width:2px
    style P3 fill:#fff3e0,stroke:#f57c00,stroke-width:3px
    style P4 fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    style JOB fill:#ffebee,stroke:#d32f2f,stroke-width:3px
```

---

## 📂 教材目錄導航

| 月份模組 | 主題名稱 | 核心內容與實作成果 | 狀態 |
| :--- | :--- | :--- | :---: |
| **00 導讀** | [轉職戰略與導讀](./00_轉職戰略與導讀/README.md) | B2B 優勢定位、AI-Native 學習方法論、學習排程建議 | ✅ |
| **Month 01** | [SQL 基礎 + Git 起手](./01_Month01_SQL基礎/README.md) | PostgreSQL、SELECT/JOIN/GROUP BY、**Git 第一天就 commit** | ✅ |
| **Month 02** | [SQL 進階與分析](./02_Month02_SQL進階與分析/README.md) | Subquery、CTE、Window Functions、**Project 1: 銷售分析** | ✅ |
| **Month 03** | [資料庫設計與建模](./03_Month03_資料庫設計與建模/README.md) | ERD、正規化、Index、ACID、**AI 生成 Schema → 你找問題** | ✅ |
| **Month 04** | [Python（目標導向）](./04_Month04_Python基礎與實用工具/README.md) | 只學解決 B2B 問題所需，3 款實用工具，不背語法全集 | ✅ |
| **Month 05** | [Python × ETL × Database](./05_Month05_Python與資料庫整合自動化/README.md) | SQLAlchemy、Logging、Config、Retry、**Project 2: ETL Pipeline** | ✅ |
| **Month 06** | [Pandas + API 資料處理](./06_Month06_Pandas與API資料處理/README.md) | 資料清洗、REST API 入庫、建立 **AI Code Review 習慣** | ✅ |
| **Month 07** | [Linux + Docker + AI Workflow](./07_Month07_工程素養_Git與Linux/README.md) | Linux 基礎、Docker Compose、**AI Coding 工作流建立** | ✅ |
| **Month 08** | [🔥 旗艦：AI-Augmented B2B Data Platform](./08_Month08_旗艦主力專案_B2B客戶數據系統/README.md) | B2B 系統 + ETL + AI Agent、架構文件完整、**M8 起開始投履歷** | ✅ |
| **Month 09** | [FastAPI API 化](./09_Month09_後端開發_FastAPI/README.md) | 旗艦專案 API 化、CRUD、Swagger UI、基礎 Auth | ✅ |
| **Month 10** | [Docker 部署 + 雲端](./10_Month10_容器化與部署_Docker/README.md) | docker-compose 一鍵啟動、雲端部署、可公開 Demo 的 URL | ✅ |
| **Month 11** | [Airflow + AI Agent](./11_Month11_AI賦能_智慧資料助理/README.md) | **Data Pipeline 排程（Airflow）+ AI Agent 多角色架構** | ✅ |
| **Month 12** | [求職衝刺](./12_Month12_轉職衝刺與求職寶典/README.md) | 根據面試回饋補強、履歷精修、技術 50 題、持續投遞 | ✅ |

---

## 🔥 四大主力作品

```
┌─────────────────────────────────────────────────────────────────────┐
│ Project 1：SQL Business Analysis (Month 2)                          │
│   ➜ 10,000+ 筆銷售資料、Cohort 分析、RFM 客戶分群、Window Functions │
├─────────────────────────────────────────────────────────────────────┤
│ Project 2：Automated ETL Pipeline (Month 5)                         │
│   ➜ Excel → Python 清洗驗證 → PostgreSQL，含 Logging / Config / Retry│
├─────────────────────────────────────────────────────────────────────┤
│ Project 3：AI-Augmented B2B Data Platform (Month 8–10) 🏆 旗艦      │
│   ➜ B2B 資料庫設計 + ETL + FastAPI + Docker + AI Agent              │
│   ➜ 使用者：「找出三個月沒下單但消費超過 50 萬的客戶」               │
│   ➜ AI 生成 SQL → 驗證 → 查詢 → 自然語言報告                        │
├─────────────────────────────────────────────────────────────────────┤
│ Project 4：Data Pipeline Orchestration (Month 11)                   │
│   ➜ Airflow 定時排程 ETL、資料品質監控、告警通知                    │
│   ➜ 或：AI Agent 多角色系統（SQL生成→驗證→分析→報告）               │
└─────────────────────────────────────────────────────────────────────┘
```

---

## ⚡ AI-Native 學習原則

> 學習不是「背技術」，而是「能設計方案、能驗證 AI 產出、能對結果負責」。

```
每個主題的學習循環：

自己先想 → 自己先寫 → AI 比較差異 → 理解為什麼 → 改進

❌ 不是：AI 生成 → 複製貼上 → 完成
```

---

## 📋 年度自我追蹤 Checklist

- [ ] **Month 1**：SQL 基礎 + **Git/GitHub 第一天就建立**，開始 commit 學習軌跡
- [ ] **Month 2**：搞懂 Window Functions，完成並開源 Project 1
- [ ] **Month 3**：設計 B2B ER 圖，練習「AI 生成 Schema → 自己找問題」
- [ ] **Month 4**：Python 聚焦 B2B 工具，3 款小工具完成
- [ ] **Month 5**：Project 2 ETL Pipeline 完成，有 Logging / Config / Error Handling
- [ ] **Month 6**：API 資料入庫，建立 AI 協助 Code Review 的日常習慣
- [ ] **Month 7**：Linux 基礎 + Docker Compose 可用，AI Coding 工作流定型
- [ ] **Month 8**：旗艦作品完成，架構圖 + Demo + README 完整 → **開始投履歷**
- [ ] **Month 9**：B2B 系統 API 化，Swagger 文件完整，Postman 可測試
- [ ] **Month 10**：docker-compose 一鍵啟動，部署到雲端有可存取 URL
- [ ] **Month 11**：Airflow 排程 ETL 或 AI Agent 多角色系統，Project 4 完成
- [ ] **Month 12**：根據面試回饋補強，每週追蹤投遞結果，持續迭代

---

## 📌 求職策略（不等 M12 才開始）

```
M1–M3   → 建立 GitHub，開始整理工作中遇到的資料問題
M4–M6   → 開始研究目標職缺的 JD，調整學習重心
M7      → 整理初版履歷
M8      → 旗艦作品完成 → 開始投遞
M9–M12  → 邊面試邊補強，根據 JD 回饋調整方向
```

**你的最終定位：**

> ~~「我沒有本科學歷，但我對 IT 很有興趣。」~~
>
> **「我有 B2B 工作經驗，懂企業資料問題，熟悉 SQL / Database，能做 ETL 自動化，能建 API、部署服務，並且有 AI Agent + B2B 系統的完整旗艦作品。」**
