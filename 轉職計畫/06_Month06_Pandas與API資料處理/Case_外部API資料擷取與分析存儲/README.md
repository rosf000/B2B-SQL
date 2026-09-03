# 🎯 外部 API 資料擷取與分析存儲管線 (API to PostgreSQL Pipeline)

> **專案定位**：Month 6 成果專案。示範如何從公開 REST API 批次擷取資料、使用 Pandas 進行資料清洗轉換、計算統計指標並持久化儲存至 PostgreSQL。

---

## 🛠️ 管線步驟

1. **API Ingestion**：從 API 批次拉取結構化 JSON 資料。
2. **Data Transformation (Pandas)**：
   - 扁平化巢狀 JSON 結構 (JSON Normalization)
   - 轉換時間欄位為標準 ISO 8601 時間戳
   - 處理缺漏值與格式異常
3. **Database Loading**：
   - 使用 SQLAlchemy 自動對齊 Schema 並寫入 PostgreSQL 資料表。
