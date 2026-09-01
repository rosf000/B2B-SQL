# 02 Index 索引原理與 ACID 交易安全機制

## 一、Index 索引核心概念

資料庫中的索引就如同書籍的「目錄」。沒有索引時，資料庫必須執行 **Full Table Scan (全表掃描)**；建立索引後，資料庫透過 **B-Tree (Balanced Tree)** 資料結構，能在 $O(\log N)$ 時間複雜度內精確鎖定資料列。

### 常用索引型態
1. **B-Tree 索引 (預設)**：適用於 `=`, `<`, `>`, `BETWEEN`, `IN`, `ORDER BY` 等操作。
2. **唯一索引 (Unique Index)**：強制資料欄位的唯一性（主鍵與 Unique 約束底層自動建立）。
3. **複合索引 (Composite Index)**：涵蓋多個欄位（如 `(customer_id, order_date)`），需符合**最左前綴原則 (Leftmost Prefix Rule)**。

---

## 二、ACID 交易特性（面試必考熱點）

交易 (Transaction) 是一組不可分割的 SQL 操作單元，必須滿足 ACID 四大特性：

```text
┌─────────────────────────┬────────────────────────────────────────────────────────┐
│ ACID 特性               │ 核心意義與保護機制                                     │
├─────────────────────────┼────────────────────────────────────────────────────────┤
│ A - Atomicity (不可分割)│ 交易內的所有 SQL 要麼全部成功提交，要麼全部失敗回滾。  │
├─────────────────────────┼────────────────────────────────────────────────────────┤
│ C - Consistency (一致性)│ 交易前後資料庫必須滿足所有完整性約束 (外鍵、Check 等)。│
├─────────────────────────┼────────────────────────────────────────────────────────┤
│ I - Isolation (隔離性)  │ 多個併發交易互相隔離，避免髒讀 (Dirty Read) 或不可重複讀│
├─────────────────────────┼────────────────────────────────────────────────────────┤
│ D - Durability (持久性) │ 交易一旦 COMMIT 成功，即使伺服器瞬間斷電，資料永不遺失 │
└─────────────────────────┴────────────────────────────────────────────────────────┘
```

---

## 三、交易實務代碼：訂單成立扣減庫存

```sql
-- 模擬下單扣減庫存與產生訂單的原子性交易
BEGIN;

-- 步驟 1: 檢查庫存並鎖定該列 (FOR UPDATE 悲觀鎖，防止併發超賣)
SELECT product_id, stock_quantity 
FROM products 
WHERE product_id = 1 
FOR UPDATE;

-- 步驟 2: 扣減產品庫存
UPDATE products 
SET stock_quantity = stock_quantity - 2 
WHERE product_id = 1;

-- 步驟 3: 建立訂單主檔
INSERT INTO orders (order_number, customer_id, salesperson_id, order_date, total_amount)
VALUES ('ORD-2024-999', 1, 1, CURRENT_DATE, 240000);

-- 步驟 4: 建立訂單明細
INSERT INTO order_items (order_id, product_id, quantity, unit_price, subtotal)
VALUES (currval('orders_order_id_seq'), 1, 2, 120000, 240000);

-- 步驟 5: 成功提交交易 (若中途任一步出錯，則執行 ROLLBACK;)
COMMIT;
```
