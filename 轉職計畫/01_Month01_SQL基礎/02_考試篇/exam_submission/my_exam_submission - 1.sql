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



-- --------------------------------------------------------------------
-- 題目 2：Top 10 旗艦客戶貢獻度分析
-- 需求：找出全歷史累計消費最高的前 10 名客戶（限 Completed）。
-- 欄位：company_name, industry, total_spent, order_count, avg_order_value。
-- --------------------------------------------------------------------
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



-- --------------------------------------------------------------------
-- 題目 3：高危險沉睡客戶警報 (Churn Alert)
-- 需求：基準日 2024-03-31，找出有過 Completed 訂單但已超過 90 天未下單的客戶。
-- 欄位：customer_id, company_name, last_order_date, days_since_last_order (依天數降序)。
-- --------------------------------------------------------------------
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



-- --------------------------------------------------------------------
-- 題目 4：業務代表戰力與客單價排行
-- 需求：列出每位業務代表姓名、區域、總銷售額、成交訂單數、平均成交金額（沒單也要列出，考察 LEFT JOIN）。
-- 欄位：rep_name, region, sales_volume, deals_closed, avg_deal_size。
-- --------------------------------------------------------------------
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


-- --------------------------------------------------------------------
-- 題目 5：長尾滯銷產品盤點
-- 需求：找出歷史上從未有過任何銷售紀錄（未出現在 Completed 訂單中）的產品清單。
-- 欄位：product_id, product_name, category, unit_price。
-- --------------------------------------------------------------------
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




-- ====================================================================
-- 🗣️ 第二部分：口試面試題 (Interview Ready)
-- 請以錄音或口頭自述的方式，用非技術主管與工程師皆能理解的語言回答以下 3 題：
-- ====================================================================
--1.WHERE 與 HAVING 的本質差異：
--「為什麼我寫 WHERE SUM(total_amount) > 50000 會噴錯？SQL 底層的運算順序（Execution Order）到底是什麼？」
where 用來做原始資料篩選；having用來做彙整篩選

資料處理順序：
from->where->group by->having->order by->limit

--2.JOIN 導致的資料膨脹（Fan-out trap）：
--「如果有一張訂單表 orders（1 萬筆）與訂單明細表 order_items（5 萬筆），我想要算每個客戶的總消費金額。如果直接 JOIN 後再 GROUP BY，計算出來的金額會正確嗎？為什麼？應該怎麼避免？」
不確定；可能會有笛卡兒積；我會先用customers當主表，再把orders和order_items left join 加進來再進行 group by，這樣就不會有客戶重複計算的問題
--3.三值邏輯與 NULL 陷阱：
--「在 SQL 裡面，為什麼 WHERE discount_rate <> 0.1 無法抓出那些 discount_rate IS NULL 的資料？身為 Data Engineer，你在實務上會怎麼防呆？」
null 就是 null 不屬於任何數值，所以才會找抓不到資料
防呆的話我會用is null 或是使用coalesce把null轉換成0，前提是不會影響到後續的業務判斷



-- ====================================================================
-- 🤖 第三部分：AI 陷阱除錯題 (Bug Hunting)
-- 任務：實習生的 SQL 會產生「資料膨脹 (Fan-out)」算錯金額，請寫出修正後的正確寫法。
-- ====================================================================
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

