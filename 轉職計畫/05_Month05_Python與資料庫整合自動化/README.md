# Month 05｜Python × 資料庫整合與自動化 ETL 管線

> **本月核心目標**：打通 Python 與 PostgreSQL 的雙向傳輸，掌握現代 ORM (SQLAlchemy) 與底層驅動 (psycopg2)，打造一套自動讀取 Excel、資料驗證清洗、寫入資料庫並產出日誌與警報的 **端到端自動化 ETL 管線專案 (Project 2)**。

---

## 🎯 本月技能檢核清單

- [ ] 理解資料庫連線池 (Connection Pool) 與 Engine 機制
- [ ] 掌握 psycopg2 原始 SQL 執行與參數化查詢（徹底防禦 SQL Injection）
- [ ] 掌握 SQLAlchemy 2.0 核心查詢與 ORM Declarative 映射
- [ ] 掌握交易交易控制 (`session.commit()`, `session.rollback()`)
- [ ] 理解 ETL (Extract ➜ Transform ➜ Load) 架構思維
- [ ] 建立具備日誌 (Logging)、例外重試、環境變數 (`.env`) 的穩定管線
- [ ] 完成 **Project 2：Excel 至 PostgreSQL 自動化 ETL 管線專案**

---

## 📂 本模組教材與專案導航

1. [01_SQLAlchemy與psycopg2實務.md](./01_SQLAlchemy與psycopg2實務.md)
   - 連線設定、參數綁定、ORM 映射與批次寫入效能對比。
2. [02_ETL自動化管線與日誌系統設計.md](./02_ETL自動化管線與日誌系統設計.md)
   - 資料清洗過濾器、重複鍵防呆處理 (UPSERT)、日誌輸出與錯誤告警。
3. [Project_02_Excel至PostgreSQL自動化ETL管線/](./Project_02_Excel至PostgreSQL自動化ETL管線/README.md)
   - 第二個開源作品：包含完整的 Python ETL 程式碼、設定檔、模擬 Excel 生成腳本與 GitHub README。
