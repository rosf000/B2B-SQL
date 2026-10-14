# 🎓 Month 01 Exit Exam：B2B 商業數據偵探結業考【個人作答檢討報告與成績單】

> **評核模式**：最高標準評審（Top Tier Data Engineer / Senior Analytics Engineer 轉職面試等級）  
> **受評作答卷**：[`exam_submission/my_exam_submission.sql`](./my_exam_submission.sql)  
> **評分日期**：2026-10-14  
> **測驗結果**：❌ **未通過 (Fail / Retake Needed)** —— 總分門檻為 80 分

---

## 📊 總成績單 (Scorecard)

| 評核項目 | 滿分 | 實得分數 | 判定狀態 | 核心點評 |
| :--- | :---: | :---: | :---: | :--- |
| **第一部分：商業數據偵探實作題** | 50 | **21** | ❌ 需加強 | 出現嚴重的 Fan-out 資料膨脹、主表選錯、漏篩 Completed 狀態 |
| **第二部分：口試面試題 (Interview Ready)** | 30 | **15** | ⚠️ 部分掌握 | 對資料膨脹認知顛倒；生命週期順序與 NULL 概念方向正確 |
| **第三部分：AI 陷阱除錯題 (Bug Hunting)** | 20 | **2** | ❌ 未達標 | 完全未識破 AI 的資料膨脹陷阱，重構後的 SQL 粒度失真 |
| **總分 (Total Score)** | **100** | **38** | **【未通過・需重新閉門修煉】** | **合格通過線：80 分** |

---

## 🚨 考生三大核心盲點深度診斷

1. **資料膨脹（Fan-out）與資料粒度缺乏警覺**：
   - 題 2、口試 Q2、第三部分 AI 除錯題全部在此失分。未意識到多表關聯（1 對多）展開時，對主表金額重複做 `SUM()` 會使營收數字倍數虛增。
2. **商業洞察與行動建議棄守**：
   - 在考卷中出現多次「只有統計，沒有說明原因，不易分析」、「沒有額外分析，不知道怎麼說」、「多打電話連繫客戶」，缺乏商業數據分析的核心價值。
3. **主表選擇與集合思維（題 5）**：
   - 要找「從未賣出過的產品」，卻以「銷售明細表 `order_items`」當主表，導致從未有訂單的產品在第一步就直接被漏掉。

---

## 📝 逐題作答原卷檢討與評審

---

### 💻 第一部分：商業數據偵探實作題（得分：21 / 50）

#### 題目 1：營收與履約健康度檢視
- **本題得分**：**6 / 10**

##### ✍️ 【你的原卷作答內容】：
```sql
-- [我的 SQL 作答]：
select 

sum(case 
	when status = 'Completed' 
	then total_amount
end
) 完成訂單總營收,
count(case 
	when status = 'Completed' 
	then 1
end
)完成訂單總數,
sum(case 
	when status = 'Cancelled' 
	then total_amount
end
)取消金額損失,
sum(case 
	when status = 'Refunded' 
	then total_amount
end
)退款金額損失


from orders 
where order_date between '2024-03-01' and '2024-04-01'

-- [商業結論與行動建議]：
-- 1. 2024 年 3 月的實收營收為：
735000
-- 2. 訂單損失情況與營運建議：
只有統計，沒有說明原因，不易分析
```

##### 🔍 【最高標準檢討與扣分分析】：
1. **邊界條件 Bug (-2 分)**：
   - 你在第 44 行寫了 `where order_date between '2024-03-01' and '2024-04-01'`。
   - **`BETWEEN` 在 SQL 中是兩端包含（Inclusive）**，這表示若 2024-04-01 當天有任何訂單，會被你誤算進 3 月份營收！
   - 嚴謹的寫法應為：`order_date >= '2024-03-01' AND order_date <= '2024-03-31'` 或 `< '2024-04-01'`。
2. **商業結論棄守 (-2 分)**：
   - 你的第 54 行回答：「只有統計，沒有說明原因，不易分析」。
   - 題目已要求計算損失金額（取消與退款損失共 21.5 萬元，佔全月潛在交易的 22.6%）。在商業現場，不能只丟出 735,000，必須指出損失佔比超過兩成，建議排查特定異常訂單。

---

#### 題目 2：Top 10 旗艦客戶貢獻度分析
- **本題得分**：**2 / 10**

##### ✍️ 【你的原卷作答內容】：
```sql
-- [我的 SQL 作答]：
with top_analysis as (

select company_name,industry,
sum(o.total_amount) total_spent,
count(o.order_id) order_count,
round(sum(o.total_amount)/count(o.order_id),2) avg_order_value

from customers c
left join orders o  on c.customer_id = o.customer_id 
left join order_items oi on o.order_id  = oi.order_id 
where status = 'Completed'
group by  company_name, industry
order by total_spent desc
limit 10
)

select *,

round(total_spent*100/sum(total_spent) over(),2) contribution_ratio

from top_analysis

-- [商業結論與 Top 1 客戶維護建議]：
-- 1. 排名第一的客戶與貢獻佔比：
26.12%
-- 2. 針對該客戶的防流失策略：
沒有額外分析，不知道怎麼說
```

##### 🔍 【最高標準檢討與扣分分析】：
1. 🚨 **致命錯誤：無謂的 JOIN order_items 導致資料膨脹（Fan-out）(-5 分)**：
   - 看你的第 73 行：`left join order_items oi on o.order_id = oi.order_id`。
   - 本題只需要客戶與訂單的總金額，**完全不需要品項明細，為何要 JOIN `order_items`？**
   - 一旦 JOIN 到明細表，一張訂單若包含 3 個品項，該訂單就會被複製展開為 3 列！
   - 此時你的 `sum(o.total_amount)` 就會把整張訂單金額重複加總 3 次，`count(o.order_id)` 也會變成商品項數而非訂單數，導致算出虛假的膨脹數字！
2. **商業結論放棄思考 (-3 分)**：
   - 你的第 97 行回答：「沒有額外分析，不知道怎麼說」，且第 95 行只寫了 26.12%，連榜首客戶是誰（半導體製造業 Apex Semi Tech）都沒說出來。

---

#### 題目 3：高危險沉睡客戶警報 (Churn Alert)
- **本題得分**：**8 / 10**

##### ✍️ 【你的原卷作答內容】：
```sql
-- [我的 SQL 作答]：
select c.customer_id, c.company_name,c.industry,
MAX(o.order_date)last_order_date,
DATE '2024-03-31'-MAX(o.order_date)  days_since_last_order
from orders o
left join customers c on o.customer_id  = c.customer_id 
where o.status = 'Completed'
group by c.customer_id, c.company_name
having(DATE '2024-03-31'-MAX(o.order_date) >90 ) 
order by days_since_last_order desc

-- [商業結論與業務挽回建議]：
-- 1. 目前處於流失警報的高危險客戶清單分析：
Frontier AI Studio	最後交易日:2023-11-15	流失天數:137
Grand Harbor Mart	最後交易日:2023-12-10	流失天數:112
HyperScale BioMed	最後交易日:2023-12-28	流失天數:94
-- 2. 業務團隊應優先聯繫哪類產業客戶：
SaaS
```

##### 🔍 【最高標準檢討與扣分分析】：
- **優點**：SQL 邏輯正確！成功運用 `MAX(o.order_date)` 與 `HAVING` 抓出正確的 3 家客戶名單，天數計算完全正確。
- **扣分項目 (-2 分)**：
  - 你的第 129 行僅填寫單詞「SaaS」。
  - **商業邏輯盲點**：Frontier AI Studio（SaaS）已沉睡 137 天（近 5 個月），挽回機率極低；反而是 **剛過 90 天臨界線的 HyperScale BioMed（94 天，生醫業）** 關係尚未完全冰凍，此時介入拜訪的挽回成功率與 ROI 最高。只回答一個單詞缺乏業務論證。

---

#### 題目 4：業務代表戰力與客單價排行
- **本題得分**：**4 / 10**

##### ✍️ 【你的原卷作答內容】：
```sql
-- [我的 SQL 作答]：
select sr.rep_name, sr.region,
coalesce(sum(o.total_amount),0) sales_volume,
count(o.order_id) deals_closed,
coalesce(round(sum(o.total_amount)/count(o.order_id),2),0) avg_deal_size
 
from sales_reps sr
left join orders o on sr.rep_id  = o.rep_id 
group by sr.rep_name, sr.region
order by sales_volume desc

-- [商業結論與團隊績效建議]：
-- 1. 哪位業務客單價最高？哪位屬於薄利多銷路線？
Alice Wang	North	sales_volume:995000.00	deals_closed:5	avg_deal_size:199000.00
Bob Chen	Central	sales_volume:965000.00	deals_closed:5	avg_deal_size:193000.00
Charlie Lee	South	sales_volume:500000.00	deals_closed:4	avg_deal_size:125000.00
Diana Chang	North	sales_volume:155000.00	deals_closed:2	avg_deal_size:77500.00
Evan Lin	Central	sales_volume:0	deals_closed:0	avg_deal_size:0
Alice Wang單價最高；Diana Chang屬於薄利多效路線
-- 2. 針對尚未開單的新業務之輔導建議：
多打電話連繫客戶
```

##### 🔍 【最高標準檢討與扣分分析】：
1. 🚨 **嚴重業務邏輯漏失：漏篩 Completed 狀態 (-4 分)**：
   - 題目明確要求：「計算每位業務**已完成訂單**的總銷售額、成交訂單數」。
   - 你的第 145 行 `left join orders o on sr.rep_id = o.rep_id` 完全沒有過濾狀態，把 Cancelled 和 Refunded 的訂單全部算入業績！
   - 導致排出來的數字全部失真，你算出的業務冠軍是 Alice Wang（99.5 萬），但實際上 Bob Chen 才是真正的冠軍（94.5 萬，Alice 僅 89 萬）。
   - **標準解法**：條件必須寫在 `ON` 裡：`LEFT JOIN orders o ON sr.rep_id = o.rep_id AND o.status = 'Completed'`，才能既保留沒單的業務 Evan Lin，又只採計成功訂單。
2. **管理建議敷衍 (-2 分)**：
   - 你的第 161 行寫：「多打電話連繫客戶」。
   - 面試中這會被視為缺乏企業組織管理思維。應提出具體輔導機制（如安排冠軍業務 Bob 進行 Shadowing 雙人拜訪、協助梳理目標名單）。

---

#### 題目 5：長尾滯銷產品盤點
- **本題得分**：**1 / 10**

##### ✍️ 【你的原卷作答內容】：
```sql
-- [我的 SQL 作答]：
select oi.product_id product_id,
p.product_name product_name,
p.category category,
oi.unit_price unit_price,
o.status
from order_items oi
left join orders o on oi.order_id  = o.order_id
left join products p on oi.product_id  = p.product_id
where o.status != 'Completed'

-- [商業結論與庫存處理建議]：
-- 1. 零銷量產品名單與庫存痛點：
可能太貴或是有替代品
-- 2. 供應鏈與產品部門下一步行動：
降價出清
```

##### 🔍 【最高標準檢討與扣分分析】：
1. 🚨 **核心主表選錯，邏輯完全崩潰 (-7 分)**：
   - 題目需求是找「**從未有過銷售紀錄**」的產品。
   - 如果某產品從上架以來**從未被任何人下過單**，它在 `order_items` 表裡根本沒有任何紀錄！
   - 你的第 176 行竟然以 `order_items oi` 當主表，那些從未售出的產品一開始就被你漏掉了！
   - 且 `where o.status != 'Completed'` 會把平常熱銷、但碰巧某一張訂單被取消的商品錯誤抓出來。
   - **標準解法**：主表必須是 `products p`，搭配 `LEFT JOIN ... WHERE o.order_id IS NULL`。
2. **未列出產品名稱與具體洞察 (-2 分)**：
   - 未從查詢結果找出滯銷產品（產品 7：Quantum Security Key Dongle 與產品 8：Legacy Tape Backup Unit），僅寫空泛的「可能太貴或有替代品，降價出清」。

##### 💡 【滿分商業結論示範（建議這樣寫）】：
> **1. 零銷量產品名單與庫存痛點**：
> 「經排查，全公司目前共有 **2 款產品** 歷史累計完成銷售為 0，且兩者痛點型態截然不同：
> - **產品 7（Quantum Security Key Dongle，資安類，單價 28,000）**：自上架以來**完全零下單紀錄**，屬於市場接受度低或定價偏離行情的滯銷新品。
> - **產品 8（Legacy Tape Backup Unit，硬體類，單價 60,000）**：歷史唯一一筆訂單**遭客戶取消（Cancelled）**。由於磁帶備份屬於過時淘汰技術（Legacy），加上單價高昂，面臨嚴重的技術世代交替與呆滯料風險。」
>
> **2. 供應鏈與產品部門下一步行動**：
> 「針對兩款不同特性的滯銷品，建議採取**差異化庫存處置策略**：
> - **針對產品 8（磁帶備份機）**：供應鏈應**立即啟動 EOL（End of Life，停產與終止進貨）**，現有庫存以 5~7 折出清給仍有舊系統維護需求的既有客戶，避免倉儲跌價損失持續擴大。
> - **針對產品 7（量子資安金鑰）**：產品部門應重新評估市場競品定價；業務端可嘗試將其與高客單價的伺服器/雲端方案進行**『搭售促銷（Bundle）』**或作為大客戶簽約的**『滿額贈品』**，以消化現有庫存並測試市場水溫。」

---

### 🗣️ 第二部分：口試面試題（得分：15 / 30）

#### Q1：WHERE 與 HAVING 的本質差異
- **本題得分**：**7 / 10**

##### ✍️ 【你的原卷回答內容】：
> `where 用來做原始資料篩選；having用來做彙整篩選`  
> `資料處理順序：from->where->group by->having->order by->limit`

##### 🔍 【最高標準檢討與扣分分析】：
- **優點**：指出兩者定位差異，且 SQL 執行生命週期順序正確。
- **扣分 (-3 分)**：未正面回答面試官題目核心「**為什麼寫 `WHERE SUM(...)` 會噴錯**」。
  - 關鍵在於：當資料庫執行到 `WHERE` 時，`GROUP BY` 與聚合運算根本還沒執行，記憶體中還沒有 SUM 的運算結果，因此語法分析器會直接拋出語法錯誤。

---

#### Q2：JOIN 導致的資料膨脹 (Fan-out trap)
- **本題得分**：**1 / 10**

##### ✍️ 【你的原卷回答內容】：
> `不確定；可能會有笛卡兒積；我會先用customers當主表，再把orders和order_items left join 加進來再進行 group by，這樣就不會有客戶重複計算的問題`

##### 🔍 【最高標準檢討與扣分分析】：
- 🚨 **嚴重不及格！觀念完全顛倒 (-9 分)**：
  - 你回答採用的方案（「先用 customers 當主表，把 orders 和 order_items left join 加進來 group by」），**恰恰就是產生 Fan-out 資料膨脹的元兇！**
  - 當 orders JOIN order_items 時，一筆訂單會因多個品項被展開成多行；此時如果你對 `orders.total_amount` 做 SUM，金額就會被重複加總多次！
  - **正確防呆思維**：既然已經展開到明細表，就「**不要碰 orders.total_amount**，改對明細表的 `order_items.subtotal` 做 SUM」，或者「先在子查詢把 orders 彙總完再 JOIN」。

---

#### Q3：三值邏輯與 NULL 陷阱
- **本題得分**：**7 / 10**

##### ✍️ 【你的原卷回答內容】：
> `null 就是 null 不屬於任何數值，所以才會找抓不到資料`  
> `防呆的話我會用is null 或是使用coalesce把null轉換成0，前提是不會影響到後續的業務判斷`

##### 🔍 【最高標準檢討與扣分分析】：
- **優點**：指出 NULL 不屬於任何數值，且防呆策略（`IS NULL`、`COALESCE`）方向正確。
- **扣分 (-3 分)**：未點出 SQL 三值邏輯的核心詞彙 **`UNKNOWN`**。
  - 在 SQL 規範中，任何數值與 NULL 比較其結果均為 `UNKNOWN`；而 `WHERE` 條件**只會放行結果為 `TRUE` 的資料**，因此 UNKNOWN 會被默默過濾掉。

---

### 🤖 第三部分：AI 陷阱除錯題 (Bug Hunting)（得分：2 / 20）

#### 實習生提交的錯誤 SQL：
```sql
SELECT 
    c.customer_id,
    c.company_name,
    SUM(o.total_amount) AS total_revenue,
    COUNT(oi.product_id) AS total_items_bought
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY c.customer_id, c.company_name;
```

---

##### ✍️ 【你的原卷重構 SQL 與分析內容】：
```sql
-- [重構修正後的正確 SQL]：
SELECT 
    c.customer_id,
    c.company_name,
    o.total_amount,
    SUM(o.total_amount) AS total_revenue,
    COUNT(oi.product_id) AS total_items_bought
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
where o.status = 'Completed'
GROUP BY c.customer_id, c.company_name,o.total_amount;

-- [Bug 分析與白話解釋]：
-- 原因分析：
總金額有包含未完成訂單的金額
-- 為什麼修正後的寫法能解決資料粒度不匹配問題：
嘗試where o.status != 'Completed'有找到未完成訂單，代表原來的sql有把未完成訂單也算進去
```

---

##### 🔍 【最高標準檢討與扣分分析】：
1. 🚨 **未識破 AI 的根本致命 Bug (-9 分)**：
   - 題目任務明確提示：「實習生的 SQL 會產生『資料膨脹 (Fan-out)』算錯金額」。
   - 你在原因分析中寫「總金額有包含未完成訂單的金額」，完全忽略了資料倍數膨脹的核心問題！一筆訂單有多個商品時，`o.total_amount` 會被重複累加多次，造成嚴重財務報表虛報！
2. 🚨 **重構 SQL 完全破壞業務粒度 (-9 分)**：
   - 你在第 228 行把 `o.total_amount` 放進 `GROUP BY`：
     - 如果一個客戶有 3 筆不同金額的訂單，該客戶就會被拆成 3 列！這完全違背了「計算每位客戶總營收」的聚合需求！
     - 且若單張訂單內有多個商品，`SUM(o.total_amount)` 依然會乘上品項數，Fan-out 根本沒有解決！
3. **正確修正方式（Month 01 最優解）**：
   - 改對天然不重複展開的 `oi.subtotal` 做 SUM：
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

## 🎯 結語與複習指引

這份考卷的作答呈現了你在基本語法上的努力，但同時也清楚暴露了你在**「多表 JOIN 時的底層展開機制」**與**「商業數據思維」**上的盲區。

請依循以下步驟進行深度訂正：
1. **重溫第 06 篇教學**：詳細閱讀 [`01_學習篇/06_JOIN陷阱與資料粒度問題.md`](../01_學習篇/06_JOIN陷阱與資料粒度問題.md)，在 DBeaver 實際觀察一次 `orders` JOIN `order_items` 時資料是如何被複製膨脹的。
2. **對照詳解手冊**：研讀 [`02_考試篇/02_Exit_Exam_參考解答與詳解.md`](../02_Exit_Exam_參考解答與詳解.md)，理解標準商業結論的論述結構。
3. **重考驗證**：清空作答卷後重新獨立手寫一次，將目標設定在 90 分以上！
