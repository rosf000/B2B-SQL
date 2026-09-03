# 🎯 Project 2：企業級 Excel / CSV 至 PostgreSQL 自動化 ETL 管線

> **專案定位**：Month 5 成果驗收專案。模擬公司各部門每週上傳的混亂業務 Excel 檔，透過 Python 腳本完成「自動監控目錄 ➜ 資料清洗與驗證 ➜ UPSERT 寫入 PostgreSQL ➜ 產出執行摘要日誌」的完整端到端自動化管線。

---

## 🏗️ 管線架構設計

```text
[ incoming_excel/ ]  (業務部門上傳混亂檔案)
       │
       ▼
[ etl_pipeline.py ] ── 1. 讀取並檢驗欄位完整性
       │               2. 去除空值、校正統編與電話格式、轉換浮點數金額
       │               3. 異常資料隔離至 error_logs/
       ▼
[ PostgreSQL DB ]  ── 4. 透過 SQLAlchemy 以 Transaction + UPSERT 安全入庫
       │
       ▼
[ archive/ ]        ── 5. 將已處理檔案加蓋時間戳歸檔
```

---

## 🚀 快速啟動指南

1. 安裝依賴：
   ```bash
   pip install -r requirements.txt
   ```
2. 生成測試用混亂 Excel 檔：
   ```bash
   python sample_excel_generator.py
   ```
3. 執行 ETL 自動化管線：
   ```bash
   python etl_pipeline.py
   ```
