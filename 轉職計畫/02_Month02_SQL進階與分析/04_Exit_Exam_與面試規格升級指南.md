# 🎓 M2 Exit Exam 與 Project 1 面試規格升級指南

> **「面試官最怕看到千篇一律的『我寫了 RFM 分析』作業。能說出『如果資料變成 1 億筆我的 SQL 哪裡會慢、Index 該建在哪裡、為業務創造了什麼策略』的人，才是秒錄取的頂尖人才。」**

本章節分為兩大核心模組：
1. **M2 Exit Exam（進階 SQL 實力認證：80 分晉級門檻）**
2. **Project 1 面試化重構指南（從作業變成求職 Portfolio）**

---

## Part 1：🎓 M2 Exit Exam 進階考核

### 📋 測驗標準
- ⏱️ **時限**：120 分鐘
- 🎯 **晉級標準**：實作題通過率 >= 80%，且能流暢回答口頭性能與索引調優題。

### 💻 考核題目 (B2B 實戰數據集)
基於 B2B Sales Database（`customers`, `orders`, `order_items`, `products`, `sales_reps`）：

#### 實作題 1：營收 MoM（月增率）與動態滾動營收
- 使用 `DATE_TRUNC`、`SUM()` 與 Window Function `LAG()`，計算出 2023-2024 年每個月份的：
  - 該月完成訂單總額 `monthly_revenue`
  - 上月完成訂單總額 `prev_month_revenue`
  - 月成長率 `mom_growth_rate`（格式化為百分比，如 `+12.5%`，需防範除以 0 或 NULL）
  - 過去 3 個月的滾動平均營收 `rolling_3m_avg`

#### 實作題 2：RFM Segmentation 客戶價值分群 (Window Function 應用)
- 不准寫死數字閾值，改用 `NTILE(5)` 視窗函數計算每位客戶的：
  - **R (Recency)**：距基準日最後下單天數（天數越少分數越高 1~5）
  - **F (Frequency)**：累計完成訂單數（次數越多分數越高 1~5）
  - **M (Monetary)**：累計完成消費金額（金額越多分數越高 1~5）
- 透過 `CASE WHEN` 標註出 **「重要價值客戶（Champions: R>=4, F>=4, M>=4）」** 與 **「即將流失高潛力客戶（At Risk: R<=2, F>=4, M>=4）」**。

#### 實作題 3：各產業客單價第一名與佔比
- 使用 `DENSE_RANK()` 與 `SUM() OVER(PARTITION BY industry)`：
  - 找出各產業（`industry`）中消費總額排名前 3 名的客戶。
  - 計算該前 3 名客戶的消費額，佔該產業總營收的比例是多少（評估產業集中度風險）。

---

### 🗣️ 口頭技術與效能面試題 (Interview Ready)

請準備向面試官口述以下三題：

1. **大數據效能極限探討**：
   - 「如果 orders 表從目前的 1 萬筆，膨脹到 **1 億筆（100M rows）**，你在實作題 1 中寫的 `LAG()` 滾動計算與實作題 2 的 `NTILE()` 會在什麼地方遇到瓶頸？記憶體會爆掉嗎（Spill to disk）？該如何優化？」
2. **索引設計決策（Index Recommendation）**：
   - 「針對經常需要依據 `order_date` 做區間過濾，並以 `customer_id` 關聯客戶的查詢，你會建議在 `orders` 表上建什麼樣的 Index？為什麼是複合索引（Composite Index）？欄位順序該放 `(customer_id, order_date)` 還是 `(order_date, customer_id)`？理由是什麼？」
3. **Index 的隱形成本（Trade-off）**：
   - 「既然 Index 可以讓查詢從幾秒變幾毫秒，為什麼我們不把每個欄位都加上 Index？在 B2B 高頻寫入系統中會有什麼副作用？」

---

## Part 2：🚀 Project 1 面試化重構指南

絕不要把專案寫成教科書筆記！請將 `Project_01` 的 `README.md` 重構為 **面試官最愛看的 8 步標準商業敘事架構**：

```markdown
# 📊 B2B 企業百萬級銷售數據決策系統 (Multi-Dimensional Sales Analytics)

## 1. 商業背景與核心痛點 (Business Problem)
- 不是「我練習 SQL」，而是「企業高層發現客戶流失率上升 15%，且無法精確得知資源應集中於哪 20% 核心客戶」。

## 2. 資料集與架構規模 (Dataset & Schema)
- 10,000+ 筆交易紀錄，涵蓋客戶、業務代表、產品與訂單。
- 資料顆粒度（Grain）說明：以訂單明細為最小交易原子單位。

## 3. 核心商業問題清單 (Business Questions Answered)
- Q1: 哪些高價值客戶超過 90 天未回購，需要業務立刻啟動 VIP 拜訪？
- Q2: 哪些產品類別陷入「營收高但毛利萎縮」的健康度警訊？
- Q3: 業務代表的人均產值與月增長趨勢。

## 4. SQL 技術分析路徑 (SQL Approach & Methodologies)
- 使用 CTE 模組化拆解多層次關聯。
- 使用 Window Function (NTILE / LAG / DENSE_RANK) 進行動態切片，避免寫死寫入商業邏輯。

## 5. 核心商業洞察 (Key Business Findings)
- 發現 1：前 8% 的 Champions 客戶貢獻了公司 63% 的現金流。
- 發現 2：製造業客戶在 Q3 的客單價普遍較上半年衰退 22%。

## 6. 具體業務行動方案 (Actionable Recommendations)
- 提出給業務總監的「VIP 沉睡客戶專案追蹤清單」。
- 建議行銷團隊針對 At-Risk 客群發送高階產品升級專案優惠。

## 7. 技術挑戰與極限優化 (Technical Challenge & Optimization)
- 原始查詢在執行多表 JOIN 與無索引掃描時耗時過長。
- 透過 `EXPLAIN ANALYZE` 抓出 Seq Scan 瓶頸，在 `orders(customer_id, order_date)` 建立複合 B-Tree 索引，將查詢時間顯著縮短 70%+。

## 8. 未來可擴充性 (What I Would Improve)
- 資料量達到千萬級時，將導入物化視圖（Materialized View）定時刷新聚合報表。
- 規劃下一步串接 Python 自動化腳本（M5）實現每日排程產出 Excel 戰情報告。
```

---

## 🎯 通關檢核與升級成果

- [ ] 完成 M2 Exit Exam 實作題 1~3，SQL 正確產出指標
- [ ] 能以白話向面試官解釋 1 億筆資料下 Window Function 的記憶體溢出瓶頸與 Index 順序選型
- [ ] 按照面試版格式完成 `Project_01/README.md`，推上個人 GitHub

> 通過本章檢核，代表你已具備 **Level 3: Interview Ready** 的 SQL 分析師與 Junior Data Engineer 資料分析能力！
