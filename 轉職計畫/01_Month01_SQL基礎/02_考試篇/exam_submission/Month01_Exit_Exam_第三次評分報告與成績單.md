SELECT

# 🎓 Month 01 Exit Exam：B2B 商業數據偵探結業考【第三次評分報告與個人成績單】

> **評核模式**：最高標準評審（Top Tier Data Engineer / Senior Analytics Engineer 轉職面試等級）
> **受評作答卷**：[`exam_submission/my_exam_submission - 3.sql`](<./my_exam_submission%20-%203.sql>)
> **對照歷次作答**：第一次 [`my_exam_submission - 1.sql`](<./my_exam_submission%20-%201.sql>) ➜ 第二次 [`my_exam_submission - 2.sql`](<./my_exam_submission%20-%202.sql>)
> **評分日期**：2026-10-19
> **測驗結果**：🎉 **正式通過 (84 / 100 分)** —— 合格門檻為 80 分（相較第二次 65 分，**強勢成長 +19 分** 🚀）
> **資格認證**：🏆 **正式授予 Month 01: Job Ready (B2B 商業數據偵探) 結業認證，獲准晉級 Month 02！**

---

## 📊 總成績單 (Scorecard)

| 評核項目                                         |     滿分     |  第一次得分  |  第二次得分  |  第三次得分  |  三次總成長  |         判定狀態         | 核心點評                                                               |
| :----------------------------------------------- | :-----------: | :----------: | :----------: | :----------: | :-----------: | :-----------------------: | :--------------------------------------------------------------------- |
| **第一部分：商業數據偵探實作題**           |      50      |      21      |      30      | **41** | **+20** |   🟢 **卓越達標**   | 題 1、題 2、題 4 斬獲三座滿分！題 3 攻克 MAX()；題 5 鎖定真實零銷量品  |
| **第二部分：口試面試題 (Interview Ready)** |      30      |      15      |      20      | **28** | **+13** |   🟢 **頂尖水準**   | Q2、Q3 雙滿分！NULL 三值邏輯防呆完美逆轉；執行生命週期精準無誤         |
| **第三部分：AI 陷阱除錯題 (Bug Hunting)**  |      20      |      2      |      15      | **15** | **+13** |   🟢 **穩健發揮**   | 徹底掌握 Fan-out 與 `oi.subtotal` 粒度控制；惟外連接條件擺放仍有執念 |
| **總分 (Total Score)**                     | **100** | **38** | **65** | **84** | **+46** | 🏆 **【正式通關】** | **合格通過線：80 分（超標 4 分通過！）**                         |

---

## 🚀 三次考試進步軌跡曲線

```
100 分 ───┐
          │                                  🏆 84 分【第三次：通關晉級！】
 80 分 ───┼─────────────────────────────── (合格標準線: 80 分)
          │                   📈 65 分【第二次：大幅躍升】
 60 分 ───┼
          │
 40 分 ───┼── 📊 38 分【第一次：觀念摸索】
          │
  0 分 ───┴─────────────────────────────────────────
```

從第一次考卷的「不敢寫商業分析、算錯 Fan-out、NULL 語法寫反」，到第二次考卷「商業思維甦醒、突破 65 分」，再到本次第三次考卷：

- **實作題豪取 41 分**（前兩題與第四題皆為滿分 10/10）
- **口試題拿下 28 分**（逼近滿分 30）
- **總分達到 84 分**，堂堂正正跨越業界 Senior 面試官設定的 80 分嚴苛門檻！

---

## 🌟 第三次考試突破性重大亮點

1. **三值邏輯與 NULL 陷阱完美逆轉（口試 Q3 獲滿分 10/10）**：
   - 第二次考試將防呆寫成 `AND discount_rate IS NOT NULL`（反向扣分）。
   - 本次精準回答「NULL 是 UNKNOWN 而非數值」，並給出標準防呆語法 `WHERE discount_rate <> 0.1 OR discount_rate IS NULL`，完全展現 Data Engineer 的嚴謹素養！
2. **題 1 財務精確度與欄位完整性全面達標（實作題 1 獲滿分 10/10）**：
   - 修正了上次跨月邊界漏洞（改為 `<=` 3月31日），並在 SQL 內原生計算出 `完成訂單數: 3`、`損失金額占比: 22.63%`，商業建議切中定價與市場預期，無懈可擊。
3. **題 2 結構瘦身與 LIMIT 規格完全吻合（實作題 2 獲滿分 10/10）**：
   - 拿掉了多餘的 CTE，補上了嚴格要求的 `LIMIT 10`，並且使用 Window Function 正確計算出 Top 1 客戶貢獻佔比 `23.08%`。
4. **題 3 徹底征服時間序列聚合（攻克 MAX 致命傷）**：
   - 修正了第二次考試中將 `order_date` 放進 GROUP BY 的嚴重架構缺陷，成功使用 `MAX(o.order_date)`，沉睡天數計算完全正確！

---

## 🚨 本次考試最後兩大「魔鬼細節」深度剖析

雖然你已成功通過 80 分門檻，但在邁向 Month 02（進階分析、CTE 與視窗函數實戰）之前，必須徹底參透這兩個扣分點：

### 1. 「為什麼你兩次都把 `--and o.status = 'Completed'` 註解掉？」

在本次考卷中，有一個極其耐人尋味的現象：

- **題目 5**：你寫了 `--and o.status = 'Completed'`，然後把它註解掉，改成 `where o.status != 'Completed' or o.status is null`。
- **第三部分 AI 題**：你寫了 `--and o.status = 'Completed'`，然後把它註解掉，改成 `where o.status = 'Completed'`。

> 💡 **心理盲點診斷**：
> 你的直覺一直告訴你：「過濾條件不是應該都寫在 `WHERE` 嗎？寫在 `ON` 裡面感覺怪怪的。」
> **這就是 SQL 初學者邁向中高階工程師最關鍵的一道分水嶺！**

#### 🔑 外連接 (LEFT JOIN) 的核心真諦

| 擺放位置 | 語法範例 | 發生時機 | 對主表 (Left Table) 的影響 |
| :----------------------- | :------------------------------------------------------- | :------------------- | :----------------------------------------------------------------------------------------------------------------- |
| **寫在 `ON`** | `LEFT JOIN orders o ON ... AND o.status = 'Completed'` | **關聯比對時** | **主表絕不消失**。符合條件的帶入，不符合的全部補 `NULL`。完美保留「0 訂單客戶」或「從未賣出商品」！ |
| **寫在 `WHERE`** | `WHERE o.status = 'Completed'` | **關聯完成後** | **破壞外連接**！只要右表是 `NULL` 的整列會被 `WHERE` 當場殺光，`LEFT JOIN` 瞬間退化成 `INNER JOIN`！ |

在題 5 中，因為你改寫為 `WHERE o.status != 'Completed'`，導致曾經被退款或取消過的熱銷品（Product 1、4）被錯誤抓了出來；而在第三部分 AI 題中，寫在 `WHERE` 則讓沒下過單的客戶在報表中消失。

---

## 📝 逐題作答原卷檢討與評審

---

### 💻 第一部分：商業數據偵探實作題（得分：41 / 50）

#### 題目 1：營收與履約健康度檢視

- **本題得分**：**10 / 10 (滿分 💯)**

##### ✍️ 【你的原卷作答內容】

```sql
select 
sum(case 
 when status = 'Completed' then total_amount
end)  總營收,

count(case 
 when status = 'Completed' then order_id
end)  完成訂單數,

sum(case 
 when status = 'Cancelled' then total_amount
end) 取消總金額,

sum(case 
 when status = 'Refunded' then total_amount
end) 退款總金額,

sum(case 
 when status = 'Cancelled'or status = 'Refunded' then total_amount
end)損失總金額,

count(case 
 when status = 'Cancelled'or status = 'Refunded' then order_id
end)  損失訂單數,

round((sum(case 
 when status = 'Cancelled'or status = 'Refunded' then total_amount
end)*100/sum(total_amount)),2)損失金額占比

from orders
--where status = 'Completed'
where order_date >= '2024-03-01' and order_date <= '2024-03-31'
```

**商業結論**：

> 總營收：735000.00，完成訂單數: 3，取消總金額: 95000.00，退款總金額: 120000.00。損失訂單金額: 215000.00，損失金額占比: 22.63%。營運建議：重新分析產品在市場的價格以及檢討產品功能是否達到市面上的使用水準。

##### 🔍 【評審診斷】

- 日期邊界精準（`<= '2024-03-31'`），排除了跨月污染。
- 欄位完全自主計算完成，甚至在 SQL 內部完成百分比運算（22.63%）。
- 商業洞察完整具體，表現完美。

---

#### 題目 2：Top 10 旗艦客戶貢獻度分析

- **本題得分**：**10 / 10 (滿分 💯)**

##### ✍️ 【你的原卷作答內容】

```sql
select c.company_name , c.industry ,
sum(total_amount)total_spent,
count(order_id)order_count,
round(sum(total_amount)/count(order_id),0) avg_order_value,
round(sum(total_amount)*100/sum(sum(total_amount)) over(),2) contribution_rate

from customers c
left join orders o on c.customer_id  = o.customer_id 
where o.status = 'Completed'
group by c.company_name , c.industry 
order by total_spent desc
limit 10
```

**商業結論**：

> 排名第一的客戶: Apex Semi Tech，產業: Manufacturing，總銷售額: 540000，訂單數: 2，平均訂單金額: 270000，貢獻佔比: 23.08%。防流失策略：訂定訂單生命週期與主動關懷客戶，有最新產品消息可優先通知，提供優惠價格。

##### 🔍 【評審診斷】

- 成功補上 `LIMIT 10` 規格。
- 查詢結構簡潔有力，捨棄不必要的 CTE，直接在主查詢利用 `sum(sum(total_amount)) over()` 漂亮產出 `23.08%` 貢獻度。
- 排序、分組與商業建議全部正確。

---

#### 題目 3：高危險沉睡客戶警報 (Churn Alert)

- **本題得分**：**6 / 10**

##### ✍️ 【你的原卷作答內容】

```sql
select o.customer_id,c.company_name ,c.industry,
max(o.order_date )last_order_date,
'2024-03-31' - max(o.order_date ) days_since_last_order
from orders o
left join customers c on o.customer_id  = c.customer_id 
and status = 'Completed'
group by o.customer_id,o.status,c.company_name,c.industry
having '2024-03-31' - max(o.order_date )>=90
order by o.customer_id
```

**商業結論**：

> 成功辨識出 Frontier AI (137天)、Grand Harbor Mart (112天)、HyperScale BioMed (94天)。建議優先聯繫 Healthcare-HyperScale BioMed，因剛過 90 天臨界線，挽回機率最高。

##### 🔍 【評審診斷與扣分分析】

1. **🌟 克服核心難關 (+2 分)**：
   - 徹底搞懂 `MAX(o.order_date)` 的時間序列聚合意義，不再發生「天天交易的客戶因舊單被誤判流失」的致命問題。
2. **🚨 排序規格遺漏 (-2 分)**：
   - 題目明確要求「依沉睡天數由大到小排序（`days_since_last_order DESC`）」，作答卻寫成 `ORDER BY o.customer_id`。警報看板必須將最危急的客戶置頂，排序規格不可妥協。
3. **🚨 條件與分組粒度偏差 (-2 分)**：
   - 將狀態過濾寫在 `LEFT JOIN customers c ON ... and status = 'Completed'`，但主表是 `orders`，這導致取消或退款的訂單也會留著（只是客戶名稱變 NULL）。
   - 同時在 `GROUP BY` 放了 `o.status`。若客戶同時有 Completed 與 Cancelled 訂單，會被切成兩筆記錄。
   - **標準寫法**：

     ```sql
     SELECT c.customer_id, c.company_name, c.industry,
     FROM customers c
     INNER JOIN orders o ON c.customer_id = o.customer_id
     WHERE o.status = 'Completed'
     GROUP BY c.customer_id, c.company_name, c.industry
     HAVING (DATE '2024-03-31' - MAX(o.order_date)) >= 90
     ORDER BY days_since_last_order DESC;
     ```

---

#### 題目 4：業務代表戰力與客單價排行

- **本題得分**：**10 / 10 (滿分 💯)**

##### ✍️ 【你的原卷作答內容】

```sql
select rep_name,region,
coalesce(sum(o.total_amount),0)sales_volume,
count(o.order_id )deals_closed,
coalesce(round((sum(o.total_amount )/count(o.order_id )),2),0)avg_deal_size
from sales_reps sr
left join orders o on sr.rep_id  = o.rep_id 
and o.status = 'Completed'
group by sr.rep_name,sr.region
order by avg_deal_size desc
```

##### 🔍 【評審診斷】

- 主動使用 `COALESCE(..., 0)` 進行除零與空值防呆保護，展現成熟工程師風範！
- `LEFT JOIN ... AND o.status = 'Completed'` 運用自如，未開單新人 Evan Lin 正確列出為 0。
- 商業分析建議 Alice 帶領 Evan Lin 進行業務實戰教學，深具管理價值。

---

#### 題目 5：長尾滯銷產品盤點

- **本題得分**：**5 / 10**

##### ✍️ 【你的原卷作答內容】

```sql
select p.product_id, p.product_name,p.category,oi.unit_price,o.status
from products p 
left join order_items oi on p.product_id  = oi.product_id 
left join orders o on oi.order_id  = o.order_id 
--and o.status  = 'Completed'
--where o.status is null or o.status !='Completed'
where o.status != 'Completed' or o.status is null
```

##### 🔍 【評審診斷與扣分分析】

1. **進步亮點 (+3 分)**：
   - 相較第二次考試將真正零銷量的 Product 7 誤殺，本次成功抓回了 Product 7（量子金鑰）與 Product 8（磁帶備份機）。
2. **🚨 依然誤傷主力金牛產品 (-4 分)**：
   - 因為你註解掉了 `--and o.status = 'Completed'`，改成 `WHERE o.status != 'Completed' OR o.status IS NULL`。
   - **後果**：Product 1（伺服器，銷售 84 萬）與 Product 4（BI 軟體，銷售 38 萬）因為各自曾經有過一筆退款或取消訂單，直接命中 `o.status != 'Completed'`，**再次被你的查詢當作滯銷品輸出**！
   - 「從未出現在 Completed 訂單」的反向排查，核心在於：**只要有過 Completed，就絕對不是滯銷品**。
3. **規格輸出 (-1 分)**：
   - 題目要求輸出 4 個欄位，作答多輸出了 `o.status`，且未做 `DISTINCT` 或 `GROUP BY`。

- **標準解法回顧**：

  ```sql
  SELECT p.product_id, p.product_name, p.category, p.unit_price
  FROM products p
  LEFT JOIN order_items oi ON p.product_id = oi.product_id
  LEFT JOIN orders o       ON oi.order_id = o.order_id 
                           AND o.status = 'Completed'  -- 只有 Completed 才連上來，其餘補 NULL
  WHERE o.order_id IS NULL                             -- 只要連不上來的，就是從未成交過的滯銷品！
  ORDER BY p.product_id;
  ```

---

### 🗣️ 第二部分：口試面試題（得分：28 / 30）

#### Q1. WHERE 與 HAVING 的本質差異

- **本題得分**：**8 / 10**
- **原卷回答**：
  > WHERE只負責分類，還沒有計算功能，在二次分類having才有計算功能，使用SUM(total_amount) > 50000就不會噴錯
  > from >where>group by > having>select>order by > limit
  >
- **評審診斷**：
  - 執行生命週期順序 100% 正確（+5 分）。
  - 能說出分組後在 HAVING 才能使用聚合函數（+3 分）。
  - **細節提醒 (-2 分)**：用詞上建議將「分類」修正為「**過濾 (Filter)**」，因為「分類/分組」在 SQL 中是 `GROUP BY` 的職責；`WHERE` 是針對單列原始資料過濾，`HAVING` 是針對聚合後的群組統計值過濾。

---

#### Q2. JOIN 導致的資料膨脹 (Fan-out trap)

- **本題得分**：**10 / 10 (滿分 💯)**
- **原卷回答**：
  > 不會；金額被重複計算；如果要用total_amount計算總消費金額，需要先用CTE單獨計算客戶每筆訂單的消費金額還有訂單狀態，然後在JOIN訂單表，這樣計算出來的總消費金額就不會出錯；或是直接用每筆訂單的sub_total計算就不會出錯
  >
- **評審診斷**：
  - 完全掌握 1:N 膨脹機制，且同時提出「先行聚合 CTE」與「改用 `oi.subtotal`」兩種業界標準解法，回答無懈可擊！

---

#### Q3. 三值邏輯與 NULL 陷阱

- **本題得分**：**10 / 10 (滿分 💯)**
- **原卷回答**：
  > WHERE discount_rate <> 0.1 只能抓到不是0.1的數值，null是unknow而非樹值，理所當然抓不到，建議寫法為WHERE discount_rate <> 0.1 or discount_rate IS NULL
  >
- **評審診斷**：
  - **漂亮的大逆轉！** 完美修正了第二次考試的邏輯失誤，精確點出 `UNKNOWN` 概念，並給出標準防呆語法 `OR discount_rate IS NULL`！

---

### 🤖 第三部分：AI 陷阱除錯題（得分：15 / 20）

##### ✍️ 【你的原卷作答內容】

```sql
SELECT 
    c.customer_id,
    c.company_name,
    o.status,
    SUM(oi.subtotal ) AS total_revenue,
    COUNT(oi.product_id) AS total_items_bought
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
--and o.status = 'Completed'
where o.status = 'Completed'
GROUP BY c.customer_id, c.company_name, o.status;
```

**原因分析與解釋**：

> 原本使用 SUM(o.total_amount) 導致重複計算；沒有確認訂單狀態，把沒成交的金額也納入。修正法改用 SUM(oi.subtotal) 計算明細總額避免重複計算，並過濾掉未成交訂單。

##### 🔍 【評審診斷與扣分分析】

1. **🌟 核心掌握 (+15 分)**：
   - 準確抓出實習生 SQL 的 Fan-out 弊端，成功改用 `SUM(oi.subtotal)`，資料粒度控制完全正確。
2. **🚨 條件擺放退化外連接 (-4 分)**：
   - 你在程式碼中已經寫了 `--and o.status = 'Completed'`，但最後依然選擇了 `WHERE o.status = 'Completed'`。
   - 這會導致「從未下單的新客戶」因為 `o.status` 為 NULL 而被 `WHERE` 全部殺光，最外層的 `LEFT JOIN customers c` 失去意義，退化為 `INNER JOIN`。
3. **欄位多餘 (-1 分)**：
   - 多選取並分組了 `o.status`。

- **終極滿分解法**：

  ```sql
  SELECT 
      c.customer_id,
      c.company_name,
      COALESCE(SUM(oi.subtotal), 0) AS total_revenue,
      COUNT(oi.item_id) AS total_items_bought
  FROM customers c
  LEFT JOIN orders o ON c.customer_id = o.customer_id AND o.status = 'Completed'
  LEFT JOIN order_items oi ON o.order_id = oi.order_id
  GROUP BY c.customer_id, c.company_name
  ORDER BY total_revenue DESC;
  ```

---

## 🏆 Month 01 結業總評與通關簽核

```
┌───────────────────────────────────────────────────────────┐
│        CERTIFICATE OF ACHIEVEMENT: MONTH 01 PASS          │
│                                                           │
│   學員已成功通過 B2B 商業數據偵探結業考最高標準檢驗：      │
│   • 第一次成績：38 分 (Unprepared)                         │
│   • 第二次成績：65 分 (Major Progress)                    │
│   • 第三次成績：84 分 (JOB READY - PASSED! 🚀)             │
│                                                           │
│   【認證技能】：                                          │
│   ✔ 熟練 B2B 核心指標計算 (營收、損失佔比、AOV、沉睡天數)   │
│   ✔ 徹底克服 Multi-Table JOIN 之 Fan-out 資料膨脹陷阱     │
│   ✔ 掌握 SQL 執行生命週期 (Execution Order)               │
│   ✔ 掌握三值邏輯 (Three-Valued Logic) 與 NULL 防呆        │
│   ✔ 具備向業務主管與營運團隊交付商業洞察與行動建議之能力   │
│                                                           │
│   簽核判定：准予結業，正式晉級 Month 02！                  │
└───────────────────────────────────────────────────────────┘
```

### 🗺️ 晉級 Month 02 學習地圖預告

在 Month 01，你已經打下了堅不可摧的 SQL 基礎語法與商業數據敏銳度。在接下來的 **Month 02** 中，你將解鎖高階資料工程師的核心武器：

1. **Subqueries & CTE (Common Table Expressions)**：模組化複雜查詢，讓邏輯如搭積木般優雅。
2. **Window Functions 深度精通**：`ROW_NUMBER()`、`RANK()`、`LEAD()`、`LAG()`，輕鬆解決連續下單、分組 Top N、同環比計算。
3. **資料清洗與轉換 (Data Wrangling)**：處理髒資料、日期解析、正規表達式與條件轉換。

請帶著這次 38 ➜ 65 ➜ 84 分堅定不移、逢坑必填的毅力，大步邁向 Month 02 吧！🔥
