# Month 02｜SQL 進階與分析：從「查資料」升級到「商業數據分析」

> **本月核心目標**：掌握進階 SQL 分析工具（CTE、Window Functions、日期函數與查詢效能優化），並完成生平第一個可放上 GitHub 的 **10,000+ 筆銷售數據多維度分析專案 (Project 1)**。

---

## 🎯 本月技能檢核清單

- [ ] 理解標量子查詢 (Scalar Subquery) 與相關子查詢 (Correlated Subquery)
- [ ] 熟練使用 CTE (Common Table Expression - `WITH ... AS`) 提升複雜查詢可讀性
- [ ] 徹底掌握排名 Window Functions：`ROW_NUMBER()`, `RANK()`, `DENSE_RANK()`
- [ ] 掌握趨勢比較 Window Functions：`LAG()`, `LEAD()`, `FIRST_VALUE()`
- [ ] 掌握累積計算：`SUM(...) OVER (PARTITION BY ... ORDER BY ...)`
- [ ] 熟練 PostgreSQL 日期處理：`DATE_TRUNC`, `AGE`, `INTERVAL`, `EXTRACT`
- [ ] 掌握字串清洗函數：`TRIM`, `SPLIT_PART`, `REPLACE`, `REGEXP_REPLACE`
- [ ] 認識 Index 索引原理（B-Tree 結構）與基礎 Query Optimization (`EXPLAIN ANALYZE`)
- [ ] 完成 **Project 1：銷售資料多維度分析專案** 並推上 GitHub

---

## 📂 本模組教材文件導航

1. [01_Subquery_CTE與進階JOIN.md](./01_Subquery_CTE與進階JOIN.md)
   - 子查詢的三種型態、CTE 模組化寫法、Self Join 與 Full Outer Join。
2. [02_Window_Functions全解析.md](./02_Window_Functions全解析.md)
   - 視窗函數原理（不壓縮列數的統計神器）、商業場景排名、月增率 (MoM)、同期年增率 (YoY)。
3. [03_日期字串處理與效能優化入門.md](./03_日期字串處理與效能優化入門.md)
   - 日期區間計算、字串正規化、EXPLAIN ANALYZE 讀懂執行計畫與索引避坑。
4. [Project_01_銷售資料多維度分析專案/](./Project_01_銷售資料多維度分析專案/README.md)
   - 第一個開源作品：包含資料庫建表腳本、萬筆資料生成、RFM 客戶分群分析、業務績效分佈與報告範本。
