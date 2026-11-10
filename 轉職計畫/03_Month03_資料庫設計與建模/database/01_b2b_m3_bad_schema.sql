-- ============================================================
--  01_b2b_m3_bad_schema.sql
--  【毒瘤 Schema 練習檔】
--
--  ⚠️  警告：這個 Schema 是刻意設計錯誤的！
--  它違反了資料庫正規化的多個原則（1NF / 2NF / 3NF），
--  並且缺少必要的約束（PK / FK / CHECK / 型別正確性）。
--
--  你的任務：
--    1. 閱讀這份 schema，找出所有的設計問題。
--    2. 嘗試自己動手重構成符合 3NF 的正確設計。
--    3. 完成後再對照 02_b2b_m3_refactored_schema.sql 看看差異。
--
--  提示：問題超過 15 個，慢慢找！
-- ============================================================


-- ============================================================
--  超級大寬表：把所有 B2B 業務資訊全部塞進來
--  客戶 + 業務員 + 產品 + 訂單 = 一張表搞定（大錯特錯）
-- ============================================================

CREATE TABLE m3_b2b_mega_table (

    -- 訂單資訊（沒有 PRIMARY KEY！）
    order_id            INTEGER,                   -- ❌ 沒有 PRIMARY KEY
    order_date          VARCHAR(50),               -- ❌ 日期用 VARCHAR 存
    order_status        VARCHAR(50),               -- ❌ 沒有 CHECK 約束，可填任意字串
    total_amount        VARCHAR(50),               -- ❌ 金額用 VARCHAR 存（應為 NUMERIC）

    -- 客戶資訊（與訂單混在一起，違反單一責任）
    customer_id         INTEGER,                   -- ❌ 沒有 UNIQUE / FK 約束
    company_name        VARCHAR(200),
    tax_id              VARCHAR(20),               -- ❌ 沒有 UNIQUE 約束
    industry            VARCHAR(100),
    city                VARCHAR(100),
    credit_limit        FLOAT,                     -- ❌ 金額用 FLOAT（浮點精度問題）

    -- 重複電話欄位（違反 1NF：應用子表儲存多值屬性）
    phone_1             VARCHAR(50),               -- ❌ 重複欄位，違反 1NF
    phone_2             VARCHAR(50),               -- ❌ 重複欄位，違反 1NF
    phone_3             VARCHAR(50),               -- ❌ 重複欄位，違反 1NF

    -- 業務員資訊（部分相依於 salesperson_id，違反 2NF）
    salesperson_id      INTEGER,
    salesperson_name    VARCHAR(100),              -- ❌ 相依於 salesperson_id，違反 2NF
    salesperson_email   VARCHAR(200),              -- ❌ 相依於 salesperson_id，違反 2NF
    sales_region        VARCHAR(50),               -- ❌ 透過 salesperson_id 間接相依，違反 3NF
    monthly_target      FLOAT,                     -- ❌ 金額用 FLOAT；相依於 salesperson_id，違反 2NF

    -- 產品重複群組（違反 1NF：應用子表儲存多值屬性）
    product_1_name      VARCHAR(200),              -- ❌ 重複群組，違反 1NF
    product_1_price     FLOAT,                     -- ❌ 重複群組 + FLOAT 精度問題，違反 1NF
    product_1_qty       INTEGER,
    product_2_name      VARCHAR(200),              -- ❌ 重複群組，違反 1NF
    product_2_price     FLOAT,                     -- ❌ 重複群組 + FLOAT 精度問題，違反 1NF
    product_2_qty       INTEGER,
    product_3_name      VARCHAR(200),              -- ❌ 重複群組，違反 1NF
    product_3_price     FLOAT,                     -- ❌ 重複群組 + FLOAT 精度問題，違反 1NF
    product_3_qty       INTEGER

    -- ❌ 沒有 created_at / updated_at
    -- ❌ 完全沒有任何 FOREIGN KEY
    -- ❌ 完全沒有任何 CHECK 約束
);


-- ============================================================
--  故意設計糟糕的測試資料
--  包含多種問題，練習識別真實世界的髒資料
-- ============================================================

INSERT INTO m3_b2b_mega_table VALUES
-- 正常的第一筆（但 total_amount 是字串含逗號）
(1001, '2024-01-15', 'Completed',
 '598,000',                          -- ❌ 金額存成帶逗號的字串
 101, '台灣科技股份有限公司', '12345678', 'IT', '台北', 5000000.0,
 '02-2345-6789', '0912-345-678', '', -- ❌ phone_3 是空字串而非 NULL
 1, '王大明', 'wang@example.com', '北區', 2000000.0,
 'NAS 儲存設備', 150000.0, 2,
 'UTM 防火牆', 220000.0, 1,
 NULL, NULL, NULL),

-- ❌ 重複的 order_id（無 PK 所以可以成功插入）
(1001, '2024-01-16', 'Done',         -- ❌ 與上一筆 order_id 相同
 '598000',
 101, '台灣科技股份有限公司', '12345678', 'IT', '台北', 5000000.0,
 '02-2345-6789', '', '',
 1, '王大明', 'wang@example.com', '北區', 2000000.0,
 'NAS 儲存設備', 150000.0, 2,
 'UTM 防火牆', 220000.0, 1,
 NULL, NULL, NULL),

-- ❌ order_status 使用不一致的格式
(1002, '2024-02-01', 'OK',           -- ❌ 應為 'COMPLETED'，但填了 'OK'
 '120000',
 102, '南方貿易有限公司', '87654321', '製造業', '高雄', 2000000.0,
 '07-333-4444', NULL, NULL,
 2, '陳小花', 'chen@example.com', '南區', 1500000.0,
 '工業路由器', 60000.0, 2,
 NULL, NULL, NULL,
 NULL, NULL, NULL),

-- ❌ 負數金額（沒有 CHECK 約束所以可插入）
(1003, '2024-02-10', 'Finished',     -- ❌ 'Finished' 不是標準狀態
 '-50000',                           -- ❌ 負數金額
 103, '東部建設開發', '11223344', '建設', '花蓮', 800000.0,
 '03-856-7890', '0933-111-222', '03-856-7891',
 3, '林志遠', 'lin@example.com', '東區', 1200000.0,
 '監控攝影機套組', 45000.0, 3,
 '門禁系統', 80000.0, 1,
 '網路線材批量', 25000.0, 10),

-- ❌ 同一客戶（customer_id=101）的業務員資訊和之前不一致（資料不一致性）
(1004, '2024-03-05', 'pending',      -- ❌ 大小寫不一致，應為 'PENDING'
 '300000',
 101, '台灣科技股份有限公司', '12345678', 'IT', '台北', 5000000.0,
 '02-2345-6789', '0912-345-678', '',
 2, '陳小花', 'chen@example.com', '南區', 1500000.0, -- ❌ 同一客戶換了業務員，業務員區域也不同
 '企業授權軟體', 180000.0, 5,
 NULL, NULL, NULL,
 NULL, NULL, NULL),

-- ❌ order_date 格式不一致（前面用 ISO，這裡用中文格式）
(1005, '113年04月20日', 'CONFIRMED', -- ❌ 日期格式不一致（民國年）
 '75000',
 104, '中部精密工業', '55667788', '製造業', '台中', 3000000.0,
 '04-2222-3333', NULL, NULL,
 1, '王大明', 'wang@example.com', '北區', 2000000.0,
 '工業平板電腦', 75000.0, 1,
 NULL, NULL, NULL,
 NULL, NULL, NULL),

-- ❌ 完全空的訂單（沒有任何約束所以可以插入）
(NULL, NULL, NULL, NULL,             -- ❌ 所有欄位都是 NULL
 NULL, NULL, NULL, NULL, NULL, NULL,
 NULL, NULL, NULL,
 NULL, NULL, NULL, NULL, NULL,
 NULL, NULL, NULL,
 NULL, NULL, NULL,
 NULL, NULL, NULL);


-- ============================================================
--  練習任務清單
--  完成以下任務，再對照 02_b2b_m3_refactored_schema.sql
-- ============================================================

/*
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  任務 1：找出所有違反 1NF 的欄位
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  第一正規化（1NF）要求：
    - 每個欄位只存一個原子值（Atomic Value）
    - 沒有重複欄位或重複群組

  問題：
    □ phone_1, phone_2, phone_3 是重複欄位
    □ product_1_*, product_2_*, product_3_* 是重複群組
    □ 應如何拆分？


  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  任務 2：找出所有違反 2NF 的相依關係
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  第二正規化（2NF）要求：
    - 在滿足 1NF 的前提下
    - 所有非鍵欄位必須「完全相依」於整個主鍵（無部分相依）

  問題：
    □ company_name, tax_id, industry, city, credit_limit 相依於 customer_id
      而非完整訂單 PK → 部分相依
    □ salesperson_name, salesperson_email, monthly_target 相依於 salesperson_id
      而非完整訂單 PK → 部分相依
    □ 應拆分成幾張表？


  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  任務 3：找出所有違反 3NF 的遞移相依
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  第三正規化（3NF）要求：
    - 在滿足 2NF 的前提下
    - 非鍵欄位不可透過另一個非鍵欄位間接相依於主鍵（無遞移相依）

  問題：
    □ sales_region 相依於 salesperson_id（非鍵欄位）
      而非直接相依於訂單主鍵 → 遞移相依
      訂單 PK → salesperson_id → sales_region
    □ 若業務員調區，所有歷史訂單的 sales_region 都要更新 → 更新異常


  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  任務 4：列出所有缺少的約束（PK / FK / CHECK / 型別）
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  缺少的約束：
    □ 無 PRIMARY KEY → 允許完全重複的列（見 order_id=1001 的兩筆）
    □ 無任何 FOREIGN KEY → 無法保證參照完整性
    □ 無 UNIQUE 約束 → tax_id 可重複
    □ order_status 無 CHECK → 'Done', 'Finished', 'OK', 'pending' 都可插入
    □ total_amount 用 VARCHAR → 無法做數值計算
    □ 金額欄位用 FLOAT → 浮點數精度問題（金融計算用 NUMERIC）
    □ order_date 用 VARCHAR → 無法做日期比較或排序
    □ 無 NOT NULL 約束 → 整列可全為 NULL
    □ 無 created_at / updated_at → 無法追蹤資料異動時間
    □ credit_limit / monthly_target 無 CHECK >= 0 → 可存負數


  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  任務 5：在 02_b2b_m3_refactored_schema.sql 中寫出重構後的正確設計
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  建議重構步驟：
    1. 先畫出 ER Diagram，確認實體與關係
    2. 拆分出獨立的表（至少 5 張）
    3. 為每張表定義 PK、FK、CHECK、UNIQUE
    4. 選擇正確的資料型別
    5. 加入 created_at / updated_at
    6. 建立索引提升查詢效能
    7. 插入乾淨的種子資料驗證設計

  完成後對照 02_b2b_m3_refactored_schema.sql 比較差異！
*/
