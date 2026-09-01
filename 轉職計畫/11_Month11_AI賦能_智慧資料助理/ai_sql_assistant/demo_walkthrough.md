# AI Data Assistant 示範流程與面試展示重點

## 1. 商業價值亮點
傳統上業務端需要臨時數據時，必須提交 Jira Ticket 等待資料團隊 2~3 天才能拿到 SQL 報表。
透過此系統，非技術同仁可直接在聊天視窗提問，系統於 1 秒內精準生成安全 SQL 並返回結果，大幅釋放工程師人效。

## 2. 面試展示示範問答
- **提問**：「幫我找出最近 3 個月沒有下單、但過去消費超過 50 萬的客戶。」
- **AI 思考**：需計算每位客戶 `MAX(order_date) < CURRENT_DATE - INTERVAL '3 months'` 且 `SUM(total_amount) >= 500000`。
- **產出 SQL**：
```sql
SELECT 
    c.company_name,
    MAX(o.order_date) AS last_order_date,
    SUM(o.total_amount) AS historical_spent
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.status = 'COMPLETED'
GROUP BY c.customer_id, c.company_name
HAVING MAX(o.order_date) < CURRENT_DATE - INTERVAL '3 months'
   AND SUM(o.total_amount) >= 500000
ORDER BY historical_spent DESC;
```
