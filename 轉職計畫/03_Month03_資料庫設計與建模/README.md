# Month 03｜資料庫設計與建模：不只會查資料，更懂如何設計架構

> **本月核心目標**：從單純寫 SQL 查詢進階為「架構設計師思維」，掌握實體關聯圖 (ER Diagram)、資料庫三大正規化 (1NF/2NF/3NF)、ACID 交易安全機制，並親手設計一套生產級 B2B 資料庫架構。

---

## 🎯 本月技能檢核清單

- [ ] 理解主鍵 (Primary Key)、外鍵 (Foreign Key)、唯一約束 (Unique Key) 的本質
- [ ] 掌握一對一 (1:1)、一對多 (1:N)、多對多 (M:N) 關聯設計與中介關聯表 (Junction Table)
- [ ] 掌握 1NF（原子性）、2NF（完全依賴主鍵）、3NF（消除傳遞依賴）
- [ ] 深刻理解交易四要素 ACID（Atomicity, Consistency, Isolation, Durability）
- [ ] 掌握交易控制語句：`BEGIN`, `COMMIT`, `ROLLBACK`, `SAVEPOINT`
- [ ] 掌握 View 檢視表與 Materialized View 物化檢視表的使用時機
- [ ] 掌握 PostgreSQL 備份 (`pg_dump`) 與還原 (`pg_restore` / `psql`) 指令
- [ ] 完成 **B2B 企業級關聯資料庫設計與 ER 圖實作 (Milestone)**

---

## 📂 本模組教材文件導航

1. [01_關聯式資料庫設計規範與正規化.md](./01_關聯式資料庫設計規範與正規化.md)
   - 實體辨識、正規化三步驟實例、反正規化 (Denormalization) 的時機與權衡。
2. [02_Index索引原理與ACID交易機制.md](./02_Index索引原理與ACID交易機制.md)
   - B-Tree 索引結構、死鎖 (Deadlock)、隔離級別 (Isolation Levels)、金流/庫存扣減交易範例。
3. [03_PostgreSQL_DDL_DML與管理實務.md](./03_PostgreSQL_DDL_DML與管理實務.md)
   - `ALTER TABLE`, `CHECK Constraint`, `CASCADE` 串聯刪除/更新、備份還原實務。
4. [Milestone_B2B關聯式資料庫設計/](./Milestone_B2B關聯式資料庫設計/README.md)
   - 包含 Customers, Products, Orders, Order_Items, Salespeople, Invoices 的完整 Mermaid ER 圖與生產級 DDL 腳本。
