# 🚀 12 個月 IT 轉職實戰教材庫（B2B 領域經驗 ➜ 現代工程師）

> **「你的優勢不是 27 歲重新學 IT，而是把現在的 B2B 商業實務經驗，轉化為最有說服力的軟體工程實力。」**

歡迎來到專為 **非本科轉職 IT / 資料工程 / 後端工程師** 量身打造的 12 個月實戰教材體系。本專案包含完整的學習講義、高頻商業 SQL 題庫、Python 自動化工具代碼、FastAPI 後端應用、Docker 容器設定、AI 智慧數據查詢助理，以及四大可直接作為履歷亮點的 GitHub 專案。

---

## 🗺️ 12 個月學習地圖與專案里程碑

```mermaid
flowchart TD
    subgraph Phase1 [第一階段：SQL 與資料庫建模 (M1-M3)]
        M1["Month 01: SQL 基礎 (30道商業題庫)"] --> M2["Month 02: SQL 進階分析與 Window Functions"]
        M2 --> P1["🎯 Project 1: 銷售資料多維度分析專案"]
        P1 --> M3["Month 03: 資料庫設計、正規化與 ACID"]
    end

    subgraph Phase2 [第二階段：Python 與資料工程自動化 (M4-M6)]
        M3 --> M4["Month 04: Python 核心與 3 大自動化工具"]
        M4 --> M5["Month 05: Python × PostgreSQL 自動化 ETL"]
        M5 --> P2["🎯 Project 2: Excel 至 DB 自動化管線專案"]
        P2 --> M6["Month 06: Pandas 資料清理與 REST API 整合"]
    end

    subgraph Phase3 [第三階段：工程化與旗艦作品 (M7-M8)]
        M6 --> M7["Month 07: Git 工作流、Linux 伺服器素養"]
        M7 --> P3["🚀 Project 3 (旗艦): B2B 企業級客戶數據系統"]
    end

    subgraph Phase4 [第四階段：後端、容器化與 AI 賦能 (M9-M11)]
        P3 --> M9["Month 09: FastAPI 後端 API 架構與 CRUD"]
        M9 --> M10["Month 10: Docker 容器化與雲端部署實務"]
        M10 --> P4["🤖 Project 4: AI 智慧數據助理 (Text-to-SQL)"]
    end

    subgraph Phase5 [第五階段：求職衝刺 (M12)]
        P4 --> M12["Month 12: 中英文履歷、技術 50 題與面試通關"]
    end

    style P1 fill:#e1f5fe,stroke:#0288d1,stroke-width:2px
    style P2 fill:#e8f5e9,stroke:#388e3c,stroke-width:2px
    style P3 fill:#fff3e0,stroke:#f57c00,stroke-width:3px
    style P4 fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    style M12 fill:#ffebee,stroke:#d32f2f,stroke-width:3px
```

---

## 📂 教材目錄導航

| 月份模組 | 主題名稱 | 核心內容與實作成果 | 狀態 |
| :--- | :--- | :--- | :---: |
| **00 導讀** | [轉職戰略與導讀](./00_轉職戰略與導讀/README.md) | B2B 優勢定位、日常工作痛點記錄術、學習排程建議 | ✅ 完備 |
| **Month 01** | [SQL 基礎](./01_Month01_SQL基礎/README.md) | PostgreSQL 環境建置、SELECT 查詢語法、30 道商業情境題庫 | ✅ 完備 |
| **Month 02** | [SQL 進階與分析](./02_Month02_SQL進階與分析/README.md) | Subquery, CTE, Window Functions, **Project 1: 銷售分析專案** | ✅ 完備 |
| **Month 03** | [資料庫設計與建模](./03_Month03_資料庫設計與建模/README.md) | ER 圖設計、正規化、索引原理、ACID 交易、DDL/DML 實作 | ✅ 完備 |
| **Month 04** | [Python 基礎與工具](./04_Month04_Python基礎與實用工具/README.md) | 程式邏輯、3 款實用工具 (Excel 清洗、去重、批次命名) | ✅ 完備 |
| **Month 05** | [Python × 資料庫整合](./05_Month05_Python與資料庫整合自動化/README.md) | SQLAlchemy/psycopg2、**Project 2: 自動化 ETL 管線專案** | ✅ 完備 |
| **Month 06** | [Pandas 與 API](./06_Month06_Pandas與API資料處理/README.md) | Pandas 數據分析、REST API 請求、外部資料擷取入庫 | ✅ 完備 |
| **Month 07** | [工程素養 (Git/Linux)](./07_Month07_工程素養_Git與Linux/README.md) | Git Branch/Merge 規範、Linux 命令、專業 README 撰寫術 | ✅ 完備 |
| **Month 08** | [旗艦作品 (B2B 數據系統)](./08_Month08_旗艦主力專案_B2B客戶數據系統/README.md) | **Project 3: B2B 客戶數據管理與分析系統 (面試主力核心)** | ✅ 完備 |
| **Month 09** | [後端開發 (FastAPI)](./09_Month09_後端開發_FastAPI/README.md) | RESTful API 設計、Pydantic 驗證、Swagger UI 整合 | ✅ 完備 |
| **Month 10** | [容器化與部署 (Docker)](./10_Month10_容器化與部署_Docker/README.md) | Dockerfile, docker-compose.yml 一鍵啟動 (FastAPI + DB) | ✅ 完備 |
| **Month 11** | [AI 賦能 (智慧資料助理)](./11_Month11_AI賦能_智慧資料助理/README.md) | **Project 4: Text-to-SQL 自然語言商業數據助理** | ✅ 完備 |
| **Month 12** | [求職衝刺與面試寶典](./12_Month12_轉職衝刺與求職寶典/README.md) | 中英文工程師履歷範本、技術 50 題詳解、STAR 行為面試破局法 | ✅ 完備 |

---

## 🌟 GitHub 四大主力專案矩陣

面試時非本科最忌諱只有「Todo List」或「爬蟲抓天氣」這類罐頭作業。本教材為你打磨的四大專案皆具備**商業閉環與架構深度**：

```text
┌────────────────────────────────────────────────────────────────────────┐
│ 1. SQL Business Analysis (Month 2)                                     │
│    ➜ 10,000+ 筆銷售資料分析、Cohort 分析、RFM 客戶分群、CTE 與 Window 函數應用 │
├────────────────────────────────────────────────────────────────────────┤
│ 2. Automated Python ETL Pipeline (Month 5)                             │
│    ➜ Excel 匯入、資料格式清洗、異常偵測、自動寫入 PostgreSQL、日誌與監控 │
├────────────────────────────────────────────────────────────────────────┤
│ 3. B2B Customer Data System (Month 8 - 旗艦核心作品)                   │
│    ➜ 完整 B2B 資料庫設計、去重演算法、業務績效計算、端到端自動化與架構文檔     │
├────────────────────────────────────────────────────────────────────────┤
│ 4. AI Business Data Assistant (Month 9-11)                             │
│    ➜ FastAPI 後端 + Docker 容器化 + LLM Function Calling Text-to-SQL     │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 📋 年度自我追蹤 Checklist

你可以使用以下清單追蹤每週與每月的完成狀況：

- [ ] **Month 1: SQL 基礎** — 完成環境建置、搞懂 JOIN 與 GROUP BY、刷完 30 道題庫
- [ ] **Month 2: SQL 進階** — 搞懂 Window Functions、完成並開源 Project 1
- [ ] **Month 3: 資料庫設計** — 畫出 B2B ER 圖、理解 3NF 正規化與 ACID 交易
- [ ] **Month 4: Python 基礎** — 寫出 3 款自動化小工具、能獨立 Debug 30 分鐘以上
- [ ] **Month 5: Python + SQL** — 完成 Project 2 自動化 ETL 管線、寫出完整 README
- [ ] **Month 6: Pandas + API** — 串接外部 API、使用 Pandas 進行資料清洗並入庫
- [ ] **Month 7: Git + Linux** — 熟悉 Git Commit/Branch 規範、熟悉 Linux 基本指令
- [ ] **Month 8: 旗艦作品** — 完成 B2B 核心系統、繪製架構圖、完善 GitHub 專案
- [ ] **Month 9: FastAPI 後端** — 實作 RESTful CRUD API、整合 Swagger 文件
- [ ] **Month 10: Docker 部署** — 撰寫 Dockerfile 與 Compose、成功本機/雲端運行
- [ ] **Month 11: AI 智慧助理** — 完成 Text-to-SQL 自然語言查詢系統並錄製 Demo
- [ ] **Month 12: 履歷與面試** — 產出客製化中英文履歷、刷完 50 題技術面試題、開始投遞
