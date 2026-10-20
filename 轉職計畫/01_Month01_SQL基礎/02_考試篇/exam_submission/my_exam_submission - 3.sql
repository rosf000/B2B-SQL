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


-- [商業結論與行動建議]：
-- 1. 2024 年 3 月的實收營收為：
總營收：735000.00 		
完成訂單數: 3 		
取消總金額:95000.00		
退款總金額:120000.00

-- 2. 訂單損失情況與營運建議：
損失訂單金額:215000.00
損失金額占比:22.63%

營運建議:
有可能是產品價格太貴不符成本導致取消訂單還有產品效果不符預期，
消費者在鑑賞期辦理退款，建議重新分析產品在市場的價格以及檢討產品功能是否達到市面上的使用水準



-- --------------------------------------------------------------------
-- 題目 2：Top 10 旗艦客戶貢獻度分析
-- 需求：找出全歷史累計消費最高的前 10 名客戶（限 Completed）。
-- 欄位：company_name, industry, total_spent, order_count, avg_order_value。
-- --------------------------------------------------------------------
-- [我的 SQL 作答]：







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



-- [商業結論與 Top 1 客戶維護建議]：
-- 1. 排名第一的客戶與貢獻佔比：
公司名稱:Apex Semi Tech
產業:Manufacturing
總銷售額:540000
訂單數:2
平均訂單金額:270000
貢獻佔比:23.08%

-- 2. 針對該客戶的防流失策略：

訂定訂單生命週期與主動關懷客戶，有最新產品消息可優先通知，提供優惠價格


-- --------------------------------------------------------------------
-- 題目 3：高危險沉睡客戶警報 (Churn Alert)
-- 需求：基準日 2024-03-31，找出有過 Completed 訂單但已超過 90 天未下單的客戶。
-- 欄位：customer_id, company_name, last_order_date, days_since_last_order (依天數降序)。
-- --------------------------------------------------------------------
-- [我的 SQL 作答]：

select o.customer_id,c.company_name ,c.industry,
max(o.order_date )last_order_date,
'2024-03-31' - max(o.order_date ) days_since_last_order
from orders o
left join customers c on o.customer_id  = c.customer_id 
and status = 'Completed'
group by o.customer_id,o.status,c.company_name,c.industry
having '2024-03-31' - max(o.order_date )>=90
order by o.customer_id 






-- [商業結論與業務挽回建議]：
-- 1. 目前處於流失警報的高危險客戶清單分析：

customer_id:6	company_name:Frontier AI Studio	產業:SaaS	最後一次下單日期:2023-11-15	沉睡天數:137
customer_id:7	company_name:Grand Harbor Mart	產業:Retail	最後一次下單日期:2023-12-10	沉睡天數:112
customer_id:8	company_name:HyperScale BioMed	產業:Healthcare	最後一次下單日期:2023-12-28	沉睡天數:94

-- 2. 業務團隊應優先聯繫哪類產業客戶：
優先聯繫Healthcare-HyperScale BioMed
才剛過限制天數，可以馬上聯繫追蹤是否有新訂單

Frontier AI Studio、Grand Harbor Mart沉睡天數已超過100天還沒有下新訂單，
不繼續交易機率很高，但還是可以聯繫確認狀況




-- --------------------------------------------------------------------
-- 題目 4：業務代表戰力與客單價排行
-- 需求：列出每位業務代表姓名、區域、總銷售額、成交訂單數、平均成交金額（沒單也要列出，考察 LEFT JOIN）。
-- 欄位：rep_name, region, sales_volume, deals_closed, avg_deal_size。
-- --------------------------------------------------------------------
-- [我的 SQL 作答]：



select rep_name,region,
coalesce(sum(o.total_amount),0)sales_volume,
count(o.order_id )deals_closed,
coalesce(round((sum(o.total_amount )/count(o.order_id )),2),0)avg_deal_size
from sales_reps sr
left join orders o on sr.rep_id  = o.rep_id 
and o.status = 'Completed'
group by sr.rep_name,sr.region
order by avg_deal_size desc


-- [商業結論與團隊績效建議]：
-- 1. 哪位業務客單價最高？哪位屬於薄利多銷路線？
名字:Alice Wang	North	總銷售:900000.00	數量:4	平均:225000.00
名字:Bob Chen	Central	總銷售:845000.00	數量:4	平均:211250.00
名字:Charlie Lee	South	總銷售:440000.00	數量:3	平均:146666.67
名字:Diana Chang	North	總銷售:155000.00	數量:2	平均:77500.00
名字:Evan Lin	地區:Central	總銷售:0	數量:0	平均:0

Alice Wang單價最高，Diana Chang薄利多銷
-- 2. 針對尚未開單的新業務之輔導建議：

Evan Lin是新人，還沒有訂單，可以由銷冠Alice Wang帶領，跟著學習銷售技巧與客戶開發


-- --------------------------------------------------------------------
-- 題目 5：長尾滯銷產品盤點
-- 需求：找出歷史上從未有過任何銷售紀錄（未出現在 Completed 訂單中）的產品清單。
-- 欄位：product_id, product_name, category, unit_price。
-- --------------------------------------------------------------------
-- [我的 SQL 作答]：

select p.product_id, p.product_name,p.category,oi.unit_price,o.status
from products p 
left join order_items oi on p.product_id  = oi.product_id 
left join orders o on oi.order_id  = o.order_id 
--and o.status  = 'Completed'
--where o.status is null or o.status !='Completed'
where o.status != 'Completed' or o.status is null

-- [商業結論與庫存處理建議]：
-- 1. 零銷量產品名單與庫存痛點：

產品ID:4	產品名:BI Analytics Suite (1-Yr)	產業:Software	價格:95000.00	訂單狀態:Cancelled
產品ID:1	產品名:Enterprise Rack Server X1	產業:Hardware	價格:120000.00	訂單狀態:Refunded
產品ID:8	產品名:Legacy Tape Backup Unit	產業:Hardware	價格:60000.00	訂單狀態:Cancelled
產品ID:7	產品名:Quantum Security Key Dongle	產業:Security			
產品ID:4、8，訂單曾被取消
產品ID:1，訂單曾被退款
產品ID:7，完全沒有交易紀錄
-- 2. 供應鏈與產品部門下一步行動：
產品ID:4、8，沒有紀錄是什麼原因而取消訂單，初步判斷可能是價格太高，需要派業務聯絡進一步釐清
產品ID:1，被退款，可能是產品功能不符預期
產品ID:7，可能乏人問津，沒有人知道這項產品的實際應用
如果要銷庫存，可以做套裝優惠販售並提供使用教學



-- ====================================================================
-- 🗣️ 第二部分：口試面試題 (Interview Ready)
-- 請以錄音或口頭自述的方式，用非技術主管與工程師皆能理解的語言回答以下 3 題：
-- ====================================================================
--1.WHERE 與 HAVING 的本質差異：
--「為什麼我寫 WHERE SUM(total_amount) > 50000 會噴錯？SQL 底層的運算順序（Execution Order）到底是什麼？」
WHERE只負責分類，還沒有計算功能，在二次分類having才有計算功能，使用SUM(total_amount) > 50000就不會噴錯
from >where>group by > having>select>order by > limit

--2.JOIN 導致的資料膨脹（Fan-out trap）：
--「如果有一張訂單表 orders（1 萬筆）與訂單明細表 order_items（5 萬筆），我想要算每個客戶的總消費金額。如果直接 JOIN 後再 GROUP BY，計算出來的金額會正確嗎？為什麼？應該怎麼避免？」
不會；金額被重複計算；如果要用total_amount計算總消費金額，需要先用CTE單獨計算客戶每筆訂單的消費金額還有訂單狀態，然後在JOIN訂單表，這樣計算出來的總消費金額就不會出錯；或是直接用每筆訂單的sub_total計算就不會出錯
--3.三值邏輯與 NULL 陷阱：
--「在 SQL 裡面，為什麼 WHERE discount_rate <> 0.1 無法抓出那些 discount_rate IS NULL 的資料？身為 Data Engineer，你在實務上會怎麼防呆？」
WHERE discount_rate <> 0.1 只能抓到不是0.1的數值，null是unknow而非樹值，理所當然抓不到，建議寫法為WHERE discount_rate <> 0.1  or discount_rate IS NULL


-- ====================================================================
-- 🤖 第三部分：AI 陷阱除錯題 (Bug Hunting)
-- 任務：實習生的 SQL 會產生「資料膨脹 (Fan-out)」算錯金額，請寫出修正後的正確寫法。
-- ====================================================================
-- [重構修正後的正確 SQL]：

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

-- [Bug 分析與白話解釋]：
-- 原因分析：
原本使用SUM(o.total_amount ) AS total_revenue，導致重複計算；沒有確認訂單狀態，把沒成交的訂單金額也納入計算
-- 為什麼修正後的寫法能解決資料粒度不匹配問題：
SUM(oi.subtotal ) AS total_revenue計算訂單明細總金額，避免重複計算；加上where o.status = 'Completed'篩選掉沒成交的訂單
