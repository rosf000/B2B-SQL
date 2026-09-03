# 🏛️ B2B 企業級關聯式資料庫架構設計 (ER Modeling & DDL 實務里程碑)

> **成果定位**：Month 3 資料庫建模驗收成果。展示你如何從「業務需求溝通」轉化為「符合 3NF 正規化、高效能、防呆約束」的企業級 PostgreSQL 資料庫。

---

## 🏛️ 實體關聯架構 (Entity Relationship)

本架構涵蓋 B2B 核心業務六大實體：
1. **Salespeople (業務代表)**：管理區域、業績目標、階層管理。
2. **Customers (客戶主檔)**：管理統編唯一性、信用評等、負責業務。
3. **Products (產品主檔)**：管理硬體/軟體/服務分類、成本與售價。
4. **Orders (訂單主檔)**：記錄訂單狀態流轉 (Draft ➜ Confirmed ➜ Completed ➜ Cancelled)。
5. **Order_Items (訂單明細)**：中介關聯表，記錄交易單價快照 (Snapshot Pricing)。
6. **Invoices (發票/收款單)**：管理請款狀態與開立時間。

---

## 📂 檔案清單

- [er_diagram.mermaid](./er_diagram.mermaid)：可直接於 GitHub 或 Markdown 預覽的 Mermaid 關聯圖。
- [ddl_schema.sql](./ddl_schema.sql)：完整的 `CREATE TABLE`, 外鍵約束, Check 約束, 索引與觸發器。
- [seed_data.sql](./seed_data.sql)：初始測試資料腳本。
