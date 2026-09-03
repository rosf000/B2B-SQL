# Month 06｜Pandas 與 REST API：處理真實世界的外部資料

> **本月核心目標**：掌握現代資料處理主流函式庫 Pandas，並學會使用 Python `requests` 串接外部 REST API（如政府公開資料、匯率、氣象或企業 SaaS API），完成「外部 API ➜ 資料清理轉換 ➜ PostgreSQL 儲存 ➜ 分析視覺化」完整流程。

---

## 🎯 本月技能檢核清單

- [ ] 掌握 Pandas 核心資料結構：`Series` 與 `DataFrame`
- [ ] 熟練資料讀取與輸出：`read_csv`, `read_excel`, `read_json`, `read_sql`
- [ ] 掌握缺失值 (`isna`, `fillna`, `dropna`) 與重複值 (`drop_duplicates`)
- [ ] 掌握資料型態轉換 (`astype`, `to_datetime`, `to_numeric`)
- [ ] 熟練分組聚合 `groupby().agg()` 與樞紐分析 `pivot_table()`
- [ ] 熟練多表合併 `pd.merge()` (Inner/Left/Right/Outer) 與 `pd.concat()`
- [ ] 理解 HTTP 協議基礎（GET, POST, Status Code 200/400/401/404/500）
- [ ] 掌握 Python `requests` 請求、Headers 設定與 JSON 解析
- [ ] 完成 **外部 API 資料擷取與分析存儲專案**

---

## 📂 本模組教材與專案導航

1. [01_Pandas數據清理與轉換完全手冊.md](./01_Pandas數據清理與轉換完全手冊.md)
   - DataFrame 必背操作、向量化運算 (Vectorization) 與效能最佳化。
2. [02_REST_API原理與Python_Requests.md](./02_REST_API原理與Python_Requests.md)
   - HTTP 核心概念、Requests 實戰、處理分頁 (Pagination) 與 Rate Limit 限制。
3. [Case_外部API資料擷取與分析存儲/](./Case_外部API資料擷取與分析存儲/README.md)
   - 端到端 API 資料擷取、清洗轉換並寫入 PostgreSQL 的可執行專案代碼。
