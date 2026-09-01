# 01 LLM API、Prompt 工程與 Structured Output

## 一、Text-to-SQL 的核心挑戰與防幻覺對策

很多初學者做 Text-to-SQL 時，直接叫 LLM「寫出 SQL」，結果 LLM 經常自己發明根本不存在的欄位名稱或表名。
要解決這個問題，必須採用 **Schema Injection + Few-Shot Examples**：

### 關鍵 Prompt 設計範本
```text
你是一個專精 PostgreSQL 的資深資料工程師。
請根據以下提供的真實資料庫 Schema 回答使用者的問題，只允許產出唯讀 (SELECT) 查詢：

【資料庫 Schema】
Table: customers (customer_id, company_name, city, credit_limit, status)
Table: orders (order_id, customer_id, order_date, status, total_amount)

【輸出限制】
1. 嚴禁任何修改資料的語法 (DROP, DELETE, UPDATE, INSERT, ALTER)。
2. 回傳必須為純 JSON 格式：{"sql": "SELECT ...", "explanation": "查詢說明"}。
```

---

## 二、使用 Pydantic 實現結構化輸出 (Structured Output)

```python
from pydantic import BaseModel, Field

class SQLGenerationResult(BaseModel):
    sql_query: str = Field(..., description="產出之合規 PostgreSQL SELECT 查詢")
    thought_process: str = Field(..., description="思考邏輯與關聯鍵選擇原因")
    is_safe: bool = Field(..., description="是否為純唯讀安全查詢")
```
