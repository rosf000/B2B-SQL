-- ====================================================================
-- Month 01 Exit Exam：B2B 商業數據偵探結業考個人作答卷
-- 檔案：02_考試篇/exam_submission/my_exam_submission.sql
-- 
-- 💡 【連線提醒】：
--   請確認 DBeaver 編輯器右上角綁定的是【b2b_exit_exam】資料庫！
--   快捷鍵：單行執行按【Ctrl + Enter】，驗證無誤後再往下作答。
-- ====================================================================

-- ====================================================================
-- 💻 第一部分：商業數據偵探實作題 (共 5 題)
-- ====================================================================

-- --------------------------------------------------------------------
-- 題目 1：營收與履約健康度檢視
-- 需求：計算 2024 年 3 月份，Completed 總營收與訂單數，以及 Cancelled/Refunded 損失金額。
-- --------------------------------------------------------------------
-- [我的 SQL 作答]：

select 
count(order_id)總訂單數,
count(case 
	when status != 'Completed' then order_id
end)損失訂單訂單數,
sum(case 
	when status = 'Completed' then total_amount else 0
end) Completed_total,
sum(case 
	when status = 'Cancelled' then total_amount else 0
end) Cancelled_total,sum(case 
	when status = 'Refunded' then total_amount else 0
end) Refunded_total


from orders 
where order_date >= '2024-03-01' and order_date <= '2024-04-01'



-- [商業結論與行動建議]：
-- 1. 2024 年 3 月的實收營收為：
2024 年 3 月份，Completed 總營收:735000與訂單數:3，以及 Cancelled金額:95000，Refunded金額:120000
-- 2. 訂單損失情況與營運建議：
總訂單數:5，損失訂單數:2；預計總營收:950000，損失金額:215000，佔比約:22.6%。建議了解取消和退款原因，避免類似事情發生。




-- --------------------------------------------------------------------
-- 題目 2：Top 10 旗艦客戶貢獻度分析
-- 需求：找出全歷史累計消費最高的前 10 名客戶（限 Completed）。
-- 欄位：company_name, industry, total_spent, order_count, avg_order_value。
-- --------------------------------------------------------------------
-- [我的 SQL 作答]：


with total_spent as(
select
customer_id ,
status,
sum(total_amount)累計消費金額,
count(order_id)累計訂單數,
round(sum(total_amount)/count(order_id),2) 平均客單價

from orders 

group by customer_id ,status
)

select company_name,industry,
累計消費金額,累計訂單數,平均客單價,

round(累計消費金額*100/SUM(累計消費金額) over(),2) 貢獻佔比
 
from customers c
left join total_spent ts on c.customer_id  = ts.customer_id
where ts.status = 'Completed'
order by 累計消費金額 desc 

-- [商業結論與 Top 1 客戶維護建議]：
-- 1. 排名第一的客戶與貢獻佔比：
排名第一的客戶:Apex Semi Tech，貢獻佔比:23.08%
-- 2. 針對該客戶的防流失策略：

分析交易週期，定期追蹤訂單


-- --------------------------------------------------------------------
-- 題目 3：高危險沉睡客戶警報 (Churn Alert)
-- 需求：基準日 2024-03-31，找出有過 Completed 訂單但已超過 90 天未下單的客戶。
-- 欄位：customer_id, company_name, last_order_date, days_since_last_order (依天數降序)。
-- --------------------------------------------------------------------
-- [我的 SQL 作答]：

select o.customer_id,c.company_name,
o.order_date last_order_date,
(date'2024-03-31' - order_date) days_since_last_order
from orders o
left join customers c on o.customer_id = c.customer_id 
where o.status = 'Completed'
group by o.customer_id,o.order_date,c.company_name
having date'2024-03-31' - o.order_date   >= 90
order by days_since_last_order desc




-- [商業結論與業務挽回建議]：
-- 1. 目前處於流失警報的高危險客戶清單分析：
Frontier AI Studio	SaaS	最後交易日:2023-11-15	流失天數:137
Grand Harbor Mart	Retail	最後交易日:2023-12-10	流失天數:112
HyperScale BioMed	Healthcare	最後交易日:2023-12-28	流失天數:94
-- 2. 業務團隊應優先聯繫哪類產業客戶：

優先聯繫 Healthcare-HyperScale BioMed 流失天數剛到警戒值附近，還有挽救機會
其他流失天數超過100天的客戶，可能找到其他合作關係，難以挽回，但還是可以嘗試聯絡並了解沒有繼續交易的原因



-- --------------------------------------------------------------------
-- 題目 4：業務代表戰力與客單價排行
-- 需求：列出每位業務代表姓名、區域、總銷售額、成交訂單數、平均成交金額（沒單也要列出，考察 LEFT JOIN）。
-- 欄位：rep_name, region, sales_volume, deals_closed, avg_deal_size。
-- --------------------------------------------------------------------
-- [我的 SQL 作答]：

with completed_orders as(
select rep_id,status,
sum(total_amount)總銷售額,
count(order_id)成交訂單數,
round((sum(total_amount)/count(order_id)),2)平均成交金額
from orders o 
where status = 'Completed'
group by rep_id,status
)

select sr.rep_name,sr.region,co.status,
總銷售額,
成交訂單數,
平均成交金額
from sales_reps sr 
left join completed_orders co on sr.rep_id  = co.rep_id



-- [商業結論與團隊績效建議]：
-- 1. 哪位業務客單價最高？哪位屬於薄利多銷路線？
Alice Wang	North	Completed	總銷售額:900000.00	成交訂單數:4	平均成交金額:225000.00
Bob Chen	Central	Completed	總銷售額:845000.00	成交訂單數:4	平均成交金額:211250.00
Charlie Lee	South	Completed	總銷售額:440000.00	成交訂單數:3	平均成交金額:146666.67
Diana Chang	North	Completed	總銷售額:155000.00	成交訂單數:2	平均成交金額:77500.00
Evan Lin	Central				
Alice Wang單價最高；Diana Chang薄利多銷

-- 2. 針對尚未開單的新業務之輔導建議：
可能是新進業務，可以請老鳥負責帶領，觀察他的業務模式，給予最適當的幫助



-- --------------------------------------------------------------------
-- 題目 5：長尾滯銷產品盤點
-- 需求：找出歷史上從未有過任何銷售紀錄（未出現在 Completed 訂單中）的產品清單。
-- 欄位：product_id, product_name, category, unit_price。
-- --------------------------------------------------------------------
-- [我的 SQL 作答]：

select p.product_id, p.product_name, p.category,oi.unit_price

from products p
left join order_items oi on p.product_id = oi.product_id 
left join orders o on oi.order_id = o.order_id 
where status != 'Completed' and  status is not null
group by p.product_id, p.product_name, p.category,oi.unit_price



-- [商業結論與庫存處理建議]：
-- 1. 零銷量產品名單與庫存痛點：
product_id:1	product_name:Enterprise Rack Server X1	category:Hardware	unit_price:120000.00

product_id:8	product_name:Legacy Tape Backup Unit	category:Hardware	unit_price:60000.00

product_id:4	product_name:BI Analytics Suite (1-Yr)	category:Software	unit_price:95000.00

初步分析建議
Hardware 產品佔比較高，可能是硬體設備採購週期較長，導致消費者不願意購買
或是產品售價佈符合消費者預期或是高於市價
Software 綁約一年，功能如果沒有符合價格所帶來的價值，沒有人想買


-- 2. 供應鏈與產品部門下一步行動：
可以考慮降低售價或是做促銷來出清庫存
針對軟體可以考虑降低售價，或是做訂閱制，提供優惠方案，增加客戶接受度




-- ====================================================================
-- 🗣️ 第二部分：口試面試題 (Interview Ready)
-- 請以錄音或口頭自述的方式，用非技術主管與工程師皆能理解的語言回答以下 3 題：
-- ====================================================================
--1.WHERE 與 HAVING 的本質差異：
--「為什麼我寫 WHERE SUM(total_amount) > 50000 會噴錯？SQL 底層的運算順序（Execution Order）到底是什麼？」
where是做初步篩選，還沒有進行聚合計算；初篩後可用having進行二次篩選，到select階段技能進行聚合計算。下圖為SQL底層的運算順序
FROM-->WHERE-->GROUP BY-->HAVING-->SELECT-->ORDER BY -->limit

--2.JOIN 導致的資料膨脹（Fan-out trap）：
--「如果有一張訂單表 orders（1 萬筆）與訂單明細表 order_items（5 萬筆），我想要算每個客戶的總消費金額。如果直接 JOIN 後再 GROUP BY，計算出來的金額會正確嗎？為什麼？應該怎麼避免？」
不正確；如果一張訂單有N個明細表，join會變成N倍的資料量，在做聚合計算時會重複計算，導致金額膨脹
不能直接對total_amount進行聚合計算，應該要先對subtotal進行計算，這樣計算出的金額才是正確的

--3.三值邏輯與 NULL 陷阱：
--「在 SQL 裡面，為什麼 WHERE discount_rate <> 0.1 無法抓出那些 discount_rate IS NULL 的資料？身為 Data Engineer，你在實務上會怎麼防呆？」
null 就是unknown，無法進行計算
要抓出null值，我會WHERE discount_rate <> 0.1 and discount_rate is not null，這樣最簡單


-- ====================================================================
-- 🤖 第三部分：AI 陷阱除錯題 (Bug Hunting)
-- 任務：實習生的 SQL 會產生「資料膨脹 (Fan-out)」算錯金額，請寫出修正後的正確寫法。
-- ====================================================================
-- [重構修正後的正確 SQL]：

SELECT 
    c.customer_id,
    c.company_name,
    SUM(oi.subtotal) AS total_revenue,
    COUNT(oi.product_id) AS total_items_bought
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
where o.status = 'Completed'
GROUP BY c.customer_id, c.company_name;

-- [Bug 分析與白話解釋]：
-- 原因分析：
原本SUM(o.total_amount) AS total_revenue 會因為JOIN的關西導致資料重複計算
且沒有過濾完成訂單，造成錯誤的金額計算，最終讓總銷售額提升
-- 為什麼修正後的寫法能解決資料粒度不匹配問題：
SUM(oi.subtotal) AS total_revenue 計算每筆訂單的價格總和
where o.status = 'Completed'，在計算前先過濾掉非完成訂單，確保資料的正確性
這樣就能確保每個客戶的總銷售額和總購買商品數是正確的
