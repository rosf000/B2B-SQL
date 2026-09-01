# 02 Text-to-SQL 與 Function Calling 原理解析

## 一、AI Data Agent 運作閉環

```mermaid
sequenceDiagram
    autonumber
    actor User as 業務主管 (User)
    participant Agent as AI Agent (Python)
    participant LLM as 大型語言模型 (LLM)
    participant DB as PostgreSQL 資料庫

    User->>Agent: 「幫我查今年在台北買最多的前 3 家客戶」
    Agent->>LLM: 注入 DB Schema + 使用者提問
    LLM-->>Agent: 回傳工具呼叫 `run_sql(query="SELECT ...")`
    Agent->>Agent: 執行 SQL 安全校驗 (唯讀檢查)
    Agent->>DB: 執行 SQL 查詢
    DB-->>Agent: 返回查詢結果資料集
    Agent->>LLM: 注入查詢結果資料集，要求產出中文解讀
    LLM-->>Agent: 產出結構化商業摘要
    Agent-->>User: 「今年台北消費最高的客戶為：1. Apex Tech (80萬)...」
```

---

## 二、SQL 唯讀防護層 (Security Guardrail)

在執行任何 AI 產生的 SQL 前，必須進行嚴格的 AST (抽象語法樹) 或關鍵字過濾：

```python
FORBIDDEN_KEYWORDS = ["DROP", "DELETE", "UPDATE", "INSERT", "ALTER", "TRUNCATE", "GRANT", "REVOKE"]

def validate_safe_sql(sql: str) -> bool:
    clean = sql.strip().upper()
    if not clean.startswith("SELECT") and not clean.startswith("WITH"):
        return False
    for kw in FORBIDDEN_KEYWORDS:
        # 使用正規表達式匹配獨立單詞，避免欄位名稱內含 substring 誤判
        if re.search(r'\b' + kw + r'\b', clean):
            return False
    return True
```
