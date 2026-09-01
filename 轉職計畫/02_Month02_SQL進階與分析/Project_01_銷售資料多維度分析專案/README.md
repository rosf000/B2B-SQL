# 🎯 Project 1：B2B 企業銷售數據多維度分析專案 (SQL Business Intelligence)

> **專案定位**：Month 2 成果驗收專案。模擬一間年營收數千萬的 B2B 科技硬體與軟體代理商，針對 **10,000+ 筆真實業務交易數據** 進行深度數據洞察。

---

## 📊 專案分析指標與商業價值

本專案運用進階 SQL (CTE, Window Functions, 聚合統計) 解決以下關鍵商業問題：

1. **RFM 客戶價值模型分群 (Recency, Frequency, Monetary)**
   - 將客戶精準劃分為：重要價值客戶 (VIP)、重要挽留客戶、潛力客戶、沉睡流失客戶。
2. **客戶留存率與同梯次 Cohort 分析**
   - 觀察不同月份首次合作客戶在後續 3, 6, 12 個月的複購留存表現。
3. **業務代表銷售效率與配額達成率 (Sales Rep Benchmark)**
   - 評估業務員在各地區的平均客單價 (AOV)、成交週期長度與業績達標率。
4. **產品 ABC 分類法（帕雷托 80/20 法則）**
   - 識別貢獻公司 80% 營收的核心 A 類主力商品。

---

## 🛠️ 專案檔案結構

- [schema.sql](./schema.sql)：資料庫建表與自動生成 10,000+ 筆交易測試數據腳本。
- [analysis_queries.sql](./analysis_queries.sql)：四大核心商業主題的完整進階分析 SQL。
- [report_template.md](./report_template.md)：向管理層報告的專業商業洞察報告模板。

---

## 🚀 如何在 GitHub 上展示此專案？

1. 在個人 GitHub 新增 Repo：`sql-b2b-sales-analytics`。
2. 將本資料夾內的腳本推上倉庫，並附上 `report_template.md` 改寫後的分析報告圖表。
3. 在履歷或 LinkedIn 描述：「**設計並執行 10,000+ 筆 B2B 銷售交易分析，運用 CTE 與視窗函數完成 RFM 客戶分群與 Cohort 留存分析，成功識別出佔比 23% 的高流失風險 VIP 客戶名單。**」
