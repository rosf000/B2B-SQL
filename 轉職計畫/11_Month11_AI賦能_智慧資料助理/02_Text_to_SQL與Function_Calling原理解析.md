# 02. Text-to-SQL 與 Function Calling 原理解析與企業實戰

> **模組目標**：打造企業級 GenAI 最具商業價值的殺手級應用——**智慧自然語言資料庫助理（Text-to-SQL AI Assistant）**。深入理解大模型 Function Calling（工具調用 / Tool Use）的三階段閉環運作原理；掌握動態資料庫綱要（Schema Injection）壓縮與 Few-shot 引導；構築多層次安全防線（Read-Only 唯讀權限、SQL 語法審查、LIMIT 自動注入、防 DROP/DELETE 災難）；並實作具備「SQL 執行錯誤自動反饋自我修復（Self-Correction Loop）」的工業級資料助理。

---

## 目錄
1. [Text-to-SQL 的商業價值與工程挑戰](#1-text-to-sql-的商業價值與工程挑戰)
   - [1.1 釋放非技術決策者的數據生產力](#11-釋放非技術決策者的數據生產力)
   - [1.2 落地四大致命痛點：幻覺、性能、資安與語意模糊](#12-落地四大致命痛點幻覺性能資安與語意模糊)
2. [Function Calling（工具調用）核心機制剖析](#2-function-calling工具調用核心機制剖析)
   - [2.1 模型不是執行者，而是「決策與參數填寫者」](#21-模型不是執行者而是決策與參數填寫者)
   - [2.2 三階段交互標準循環（Three-step Tool Call Cycle）](#22-三階段交互標準循環three-step-tool-call-cycle)
   - [2.3 工具定義規範：JSON Schema 與 Python 函式映射](#23-工具定義規範json-schema-與-python-函式映射)
3. [生產級 Text-to-SQL 架構設計與安全防護體系](#3-生產級-text-to-sql-架構設計與安全防護體系)
   - [3.1 動態 Schema 注入與壓縮（DDL + 註釋 + 範例）](#31-動態-schema-注入與壓縮ddl--註釋--範例)
   - [3.2 資安防禦三道盾牌：唯讀使用者、語法 AST 審查與強制 LIMIT](#32-資安防禦三道盾牌唯讀使用者語法-ast-審查與強制-limit)
   - [3.3 自我修復迴圈（Self-Correction Loop）：錯誤反饋自動糾正](#33-自我修復迴圈self-correction-loop錯誤反饋自動糾正)
4. [企業 B2B 資料助理端到端實作（End-to-End）](#4-企業-b2b-資料助理端到端實作end-to-end)
5. [商業情境綜合練習題（含詳解）](#5-商業情境綜合練習題含詳解)

---

## 1. Text-to-SQL 的商業價值與工程挑戰

### 1.1 釋放非技術決策者的數據生產力

在傳統企業中，業務主管想知道：「*上個月在北部地區，哪一位業務員負責的電子製造業客戶總貢獻金額最高？*」
通常流程為：
1. 業務主管填寫需求單通知資料團隊。
2. 資料工程師排期、寫 SQL、產出報表。
3. 業務主管在 3 天後才收到 Excel 數據。

**Text-to-SQL 智慧助理的目標**：讓使用者直接在 Slack / Teams / 企業內部對話視窗輸入自然語言，系統在 **3 秒鐘內** 自動翻譯為高效 PostgreSQL 查詢、執行並轉化為白話商業洞察與視覺化圖表！

```
[ 使用者自然語言提問 ] 
        |
        v
[ LLM (搭載 Schema + 商業規則) ] 
        |
        v (Function Calling: execute_sql)
[ 唯讀資料庫 (PostgreSQL B2B ERP) ]
        |
        v (查詢結果 Rows / JSON)
[ LLM 綜合解讀與總結 ]
        |
        v
[ 最終白話洞察報告與趨勢圖 ]
```

---

### 1.2 落地四大致命痛點：幻覺、性能、資安與語意模糊

1. **幻覺欄位（Hallucinated Columns）**：
   - 資料庫欄位叫 `company_name`，模型憑直覺自己發明了 `customer_name` 或 `client_name`，導致 SQL 執行直接報錯不存在。
2. **毀滅性操作（Destructive Operations）**：
   - 使用者提問帶有陷阱或 Prompt Injection，若模型生成了 `DELETE FROM orders` 或 `DROP TABLE customers`，後果不堪設想。
3. **資料庫效能雪崩（Cartesian Product / Unbounded Query）**：
   - 生成未加 `LIMIT` 的全表查詢，或者多表 JOIN 缺少 `ON` 條件產生笛卡兒積，直接將線上生產資料庫記憶體與 CPU 佔滿。
4. **業務指標歧義（Business Logic Ambiguity）**：
   - 「今年營業額」到底是指「已下單但未付款（PENDING）」、還是「已出貨核准（APPROVED）」？需要 Prompt 明確固化業務規則。

---

## 2. Function Calling（工具調用）核心機制剖析

### 2.1 模型不是執行者，而是「決策與參數填寫者」

初學者常見誤區：以為大模型內部真的連接了資料庫。
**真相是：LLM 只是一個純粹的文字/符號預測器，它完全沒有連網或存取資料庫的權限！**
大模型在 Function Calling 中的職責只有兩件事：
1. **判斷是否需要呼叫工具**（以及呼叫哪一個工具）。
2. **根據對話上下文，精準提取並填寫該工具所需的參數（以 JSON 格式輸出）**。
真正的「執行（Execution）」100% 是在你的 Python 後端伺服器上安全完成的！

---

### 2.2 三階段交互標準循環（Three-step Tool Call Cycle）

```
Step 1: 
客戶端 (Python) ---> 送出 [User 提問 + Tools 定義清單] ---> LLM (OpenAI / Claude)

Step 2: 
LLM 決策並返回 ---> [tool_calls: 呼叫 execute_sql, 參數: "SELECT ..."] ---> 客戶端 (Python)

Step 3: 
客戶端本地執行 SQL 取得結果 ---> 送出 [Tool 執行結果] ---> LLM (生成最終白話回應)
```

---

### 2.3 工具定義規範：JSON Schema 與 Python 函式映射

使用 OpenAI 現代 Tools 規格定義：

```python
tools = [
    {
        "type": "function",
        "function": {
            "name": "execute_readonly_sql",
            "description": "在 B2B ERP PostgreSQL 資料庫中執行純唯讀 (SELECT) 查詢以取得數據",
            "parameters": {
                "type": "object",
                "properties": {
                    "sql_query": {
                        "type": "string",
                        "description": "欲執行的標準 PostgreSQL 查詢語句，必須以 SELECT 開頭，且必須包含 LIMIT 限制"
                    }
                },
                "required": ["sql_query"]
            }
        }
    }
]
```

---

## 3. 生產級 Text-to-SQL 架構設計與安全防護體系

### 3.1 動態 Schema 注入與壓縮（DDL + 註釋 + 範例）

我們不可能把整個資料庫幾百張表的原始 DDL 全部塞進 Prompt（會耗盡 Token）。我們需要提供精簡版 Schema 與業務定義：

```python
SYSTEM_PROMPT = """
你是一位精通 PostgreSQL 的 B2B 企業級資料庫分析師。
你的任務是將使用者的商業問題轉換為最佳化的 SQL 查詢並呼叫 `execute_readonly_sql` 工具。

### 資料庫綱要 (PostgreSQL Schema):
1. customers (客戶主表):
   - customer_id VARCHAR(20) PK
   - company_name VARCHAR(100) -- 公司全名
   - industry VARCHAR(50)       -- 產業類別 (如 '半導體', 'IC設計')
   - credit_limit NUMERIC(14,2) -- 授信額度
2. salespeople (業務主表):
   - salesperson_id VARCHAR(20) PK
   - name VARCHAR(50)           -- 業務員姓名
   - department VARCHAR(50)     -- 所屬部門 (如 '北區業務部')
3. orders (訂單主表):
   - order_id VARCHAR(30) PK
   - customer_id VARCHAR(20) FK -> customers
   - salesperson_id VARCHAR(20) FK -> salespeople
   - order_date TIMESTAMP
   - status VARCHAR(20)         -- 'PENDING', 'APPROVED', 'CANCELLED'
   - total_amount NUMERIC(14,2)
4. products (產品主表):
   - product_id VARCHAR(20) PK
   - product_name VARCHAR(100)
   - category VARCHAR(50)
   - stock_quantity INT
   - selling_price NUMERIC(12,2)
5. order_items (訂單明細):
   - item_id INT PK
   - order_id VARCHAR(30) FK -> orders
   - product_id VARCHAR(20) FK -> products
   - quantity INT
   - unit_price NUMERIC(12,2)

### 商業規則與原則：
- 計算業績或營收時，一律只計算 status = 'APPROVED' 的訂單！
- 嚴格禁止使用 SELECT *，僅能選取分析所需的具體欄位。
- 所有查詢必須在末尾包含 LIMIT (預設 50，除非需要彙總統計)。
"""
```

---

### 3.2 資安防禦三道盾牌：唯讀使用者、語法 AST 審查與強制 LIMIT

> [!CAUTION]
> **企業級 Text-to-SQL 資安底線**  
> 絕對不要相信模型自己的安全約束！若直接使用資料庫管理員帳號 (`postgres` / `sa`) 執行 AI 生成的 SQL，一旦遭遇 Prompt Injection 或幻覺誤殺，整座資料庫可能被 `DROP` 或資料被外洩。必須貫徹「**DB 唯讀權限隔離 + AST 語法樹白名單 + 伺服器端強制 LIMIT**」三道鋼鐵防線！

即便在 Prompt 中寫了一萬遍「只能寫 SELECT」，黑客依然可能透過越獄誘導模型生成 `DROP TABLE`。我們必須實作多層物理與邏輯防禦：

#### 防禦盾牌一：資料庫層面建立只讀帳戶（Least Privilege）
在 PostgreSQL 中專門建立一個只具有 `CONNECT` 與 `SELECT` 權限的唯讀帳號，從根本上禁止 DDL/DML：
```sql
CREATE ROLE ai_readonly_user WITH LOGIN PASSWORD 'Readonly_Secret_2026';
GRANT CONNECT ON DATABASE b2b_erp TO ai_readonly_user;
GRANT USAGE ON SCHEMA public TO ai_readonly_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO ai_readonly_user;
-- 剝奪一切寫入、修改、刪除權限！
```

#### 防禦盾牌二：Python 端語法審核器
```python
import re

def validate_sql_safety(sql: str) -> str:
    """防禦性檢查 SQL 語法"""
    cleaned = sql.strip().strip(";").lower()
    
    # 1. 嚴格限定必須以 select 或 with 開頭 (CTE)
    if not (cleaned.startswith("select") or cleaned.startswith("with")):
        raise PermissionError("安全阻絕：僅允許執行 SELECT 查詢！")
        
    # 2. 禁止高危險關鍵字黑名單
    forbidden_words = [
        "insert ", "update ", "delete ", "drop ", "truncate ", 
        "alter ", "create ", "grant ", "revoke ", "exec ", "--", "/*"
    ]
    for word in forbidden_words:
        if word in cleaned:
            raise PermissionError(f"安全阻絕：偵測到危險或修改指令 [{word.strip()}]！")
            
    # 3. 強制注入 LIMIT (若無 LIMIT 且非單一聚合統計)
    if "limit " not in cleaned and "count(" not in cleaned:
        sql = f"{sql.rstrip(';')} LIMIT 50;"
        
    return sql
```

---

### 3.3 自我修復迴圈（Self-Correction Loop）：錯誤反饋自動糾正

> [!TIP]
> **閉環自我修復 (Self-Correction Loop) 的威力**：
> 人類寫 SQL 也常有錯字。生產實踐表明，當第一輪生成的 SQL 報錯時（如少寫一個 GROUP BY 欄位），只要將 PostgreSQL 的精確報錯訊息原封不動回餵給 LLM，模型自我修復的成功率高達 **85% 以上**！這能大幅減少終端使用者的挫折感。

即使最頂尖的模型，偶爾也會發生欄位名稱打錯或 GROUP BY 欄位漏列的情況。
**自我修復架構（Self-Correction Loop）**：
當執行 SQL 拋出 `psycopg2.ProgrammingError` 時，**不要直接將錯誤噴給使用者**，而是將資料庫回傳的真實錯誤訊息（如 `column "orders.amount" does not exist`）包裝成 Tool 執行結果送回給大模型，讓模型在同一個 Session 內自動反思修正，重新生成正確的 SQL！

```
執行失敗: [column "amount" does not exist. Did you mean "total_amount"?]
   |
   v
回傳 Error 給 LLM
   |
   v
LLM 思考: "原來欄位名稱是 total_amount，立即修正重新產生 SQL..."
   |
   v
二次執行成功！使用者完全無感知底層曾經報錯！
```

---

## 4. 企業 B2B 資料助理端到端實作（End-to-End）

以下為一個完整的、具備自我修復與安全性校驗的 Text-to-SQL 引擎實現：

```python
import json
import psycopg2
from psycopg2.extras import RealDictCursor
from openai import OpenAI

client = OpenAI()

# 資料庫連線工廠 (使用唯讀用戶)
DB_CONFIG = {
    "dbname": "b2b_erp",
    "user": "ai_readonly_user",
    "password": "Readonly_Secret_2026",
    "host": "localhost",
    "port": 5432
}

def execute_readonly_sql(sql_query: str) -> dict:
    """底層工具執行函式"""
    try:
        safe_sql = validate_sql_safety(sql_query)
        with psycopg2.connect(**DB_CONFIG) as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(safe_sql)
                rows = cur.fetchall()
                # 轉為可 JSON 序列化的格式 (處理 Decimal 與 datetime)
                return {
                    "success": True,
                    "row_count": len(rows),
                    "data": json.loads(json.dumps(rows, default=str))
                }
    except Exception as e:
        return {
            "success": False,
            "error_message": str(e)
        }

def ask_b2b_assistant(user_question: str, max_retries: int = 3) -> str:
    """Text-to-SQL 智慧對話主控制器 (含自動糾錯循環)"""
    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": user_question}
    ]
    
    tools = [
        {
            "type": "function",
            "function": {
                "name": "execute_readonly_sql",
                "description": "執行唯讀 SQL 查詢以回答使用者數據問題",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "sql_query": {"type": "string", "description": "欲執行的 PostgreSQL 語句"}
                    },
                    "required": ["sql_query"]
                }
            }
        }
    ]

    for attempt in range(max_retries):
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=messages,
            tools=tools,
            temperature=0.0
        )
        
        response_msg = response.choices[0].message
        messages.append(response_msg) # 加入對話歷史
        
        # 若模型沒有發起 Tool Call，代表已得出結論或不需查資料庫
        if not response_msg.tool_calls:
            return response_msg.content

        # 處理模型發起的 Tool Calls
        for tool_call in response_msg.tool_calls:
            if tool_call.function.name == "execute_readonly_sql":
                func_args = json.loads(tool_call.function.arguments)
                sql_to_run = func_args.get("sql_query")
                print(f"[嘗試 {attempt + 1}] 正在執行模型產生的 SQL:\n{sql_to_run}\n")
                
                # 本地執行 SQL
                exec_result = execute_readonly_sql(sql_to_run)
                
                # 將執行結果回灌給對話歷史
                messages.append({
                    "role": "tool",
                    "tool_call_id": tool_call.id,
                    "content": json.dumps(exec_result, ensure_ascii=False)
                })

    # 若超過重試上限仍失敗
    return "抱歉，經過多次嘗試，未能成功解析正確的資料庫語法，請嘗試換個方式描述您的問題。"
```

---

## 5. 商業情境綜合練習題（含詳解）

### 題目一：實作安全 SQL 語法審查器（SQLGuard）
**業務情境**：
請撰寫一個類別 `SQLGuard`，提供 `sanitize(sql: str) -> str` 方法：
1. 移除註解（`--` 與 `/* ... */`），防止註解隱藏的注入攻擊。
2. 檢查語句數量：禁止多重語句（以分號分隔的多句 SQL，如 `SELECT 1; DROP TABLE users;`），只允許單一查詢。
3. 僅允許執行 `SELECT` 語句或 `WITH ... SELECT`（CTE 語法）。
4. 自動檢查是否具備 `LIMIT`，若缺少則自動在結尾補上 `LIMIT 50`。

#### 【題目一解答程式碼】
```python
import re

class SQLGuard:
    @staticmethod
    def sanitize(sql: str) -> str:
        # 1. 移除多行註解 /* ... */ 與單行註解 -- ...
        sql_no_comments = re.sub(r"/\*.*?\*/", "", sql, flags=re.DOTALL)
        sql_no_comments = re.sub(r"--.*$", "", sql_no_comments, flags=re.MULTILINE)
        cleaned = sql_no_comments.strip()

        # 2. 檢查是否有分號連接的多重語句
        statements = [s.strip() for s in cleaned.split(";") if s.strip()]
        if len(statements) > 1:
            raise ValueError("安全違規：嚴禁單次傳入多條分號拼接的 SQL 語句！")
        if not statements:
            raise ValueError("傳入的 SQL 語句為空！")

        target_sql = statements[0]

        # 3. 必須以 SELECT 或 WITH 開頭
        if not re.match(r"^(SELECT|WITH)\b", target_sql, re.IGNORECASE):
            raise ValueError("安全違規：語句必須以 SELECT 或 WITH 開頭，禁止一切修改操作！")

        # 4. 禁止高危關鍵字
        dangerous_keywords = r"\b(INSERT|UPDATE|DELETE|DROP|ALTER|TRUNCATE|GRANT|REVOKE)\b"
        if re.search(dangerous_keywords, target_sql, re.IGNORECASE):
            raise ValueError("安全違規：SQL 中包含受限制的寫入或維運關鍵字！")

        # 5. 強制 LIMIT 檢查 (若無 LIMIT 且無 COUNT 聚合)
        if not re.search(r"\bLIMIT\s+[0-9]+\b", target_sql, re.IGNORECASE):
            if not re.search(r"\bCOUNT\(", target_sql, re.IGNORECASE):
                target_sql = f"{target_sql} LIMIT 50"

        return target_sql
```

---

### 題目二：設計支援「查詢資料」與「圖表建議」的多功能 Function Calling 體系
**業務情境**：
除了 `execute_readonly_sql` 外，我們希望模型在取得數據後，能主動呼叫第二個工具 `suggest_chart_type`：
- 參數：`chart_type`（枚舉：`BAR_CHART`, `LINE_CHART`, `PIE_CHART`, `TABLE`）、`x_axis`、`y_axis`、`title`。
請定義完整的 Tools 規格，並撰寫主排程判斷。

#### 【題目二解答程式碼】
```python
tools_spec = [
    {
        "type": "function",
        "function": {
            "name": "execute_readonly_sql",
            "description": "執行唯讀 SQL 取得數據",
            "parameters": {
                "type": "object",
                "properties": {
                    "sql_query": {"type": "string", "description": "PostgreSQL 查詢"}
                },
                "required": ["sql_query"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "suggest_chart_type",
            "description": "根據數據特徵建議最佳前端視覺化圖表類型",
            "parameters": {
                "type": "object",
                "properties": {
                    "chart_type": {
                        "type": "string",
                        "enum": ["BAR_CHART", "LINE_CHART", "PIE_CHART", "TABLE"],
                        "description": "圖表類型：時間趨勢用 LINE_CHART，排名比較用 BAR_CHART，佔比用 PIE_CHART"
                    },
                    "title": {"type": "string", "description": "圖表標題"},
                    "x_axis": {"type": "string", "description": "X 軸欄位名稱"},
                    "y_axis": {"type": "string", "description": "Y 軸數值欄位名稱"}
                },
                "required": ["chart_type", "title", "x_axis", "y_axis"]
            }
        }
    }
]
```

---

### 題目三：實作基於 LangChain 或純 Python 的 Text-to-SQL 評測 Benchmark 腳本
**業務情境**：
為了評估你的 Text-to-SQL 系統在 B2B 資料庫上的精準度，請撰寫一個自動評測腳本：
1. 準備 3 道標準測試問題（含對照的標準 Golden SQL）。
2. 將使用者問題輸入你的助理函式，取得模型生成的 Predicted SQL。
3. 同時執行 Golden SQL 與 Predicted SQL，比對兩者回傳的資料內容（DataFrame / 結果集）是否 100% 相同。
4. 計算並輸出模型在此評測集上的「**執行準確率（Execution Accuracy, EX）**」。

#### 【題目三解答程式碼】
```python
import pandas as pd
from typing import List, Dict

benchmark_test_cases = [
    {
        "question": "列出信用額度超過 300 萬的所有半導體客戶名稱與額度",
        "golden_sql": "SELECT company_name, credit_limit FROM customers WHERE industry = '半導體' AND credit_limit > 3000000;"
    },
    {
        "question": "統計各部門業務員目前成交的訂單總金額，依金額由高至低排序",
        "golden_sql": """
        SELECT s.department, SUM(o.total_amount) AS total_sales
        FROM salespeople s
        JOIN orders o ON s.salesperson_id = o.salesperson_id
        WHERE o.status = 'APPROVED'
        GROUP BY s.department
        ORDER BY total_sales DESC;
        """
    },
    {
        "question": "找出目前庫存數量低於 50 的產品名稱與現有庫存",
        "golden_sql": "SELECT product_name, stock_quantity FROM products WHERE stock_quantity < 50;"
    }
]

def run_sql_to_df(conn, sql: str) -> pd.DataFrame:
    try:
        return pd.read_sql_query(sql, conn)
    except Exception:
        return pd.DataFrame() # 執行失敗返回空表

def evaluate_text_to_sql_benchmark(conn, assistant_func) -> float:
    passed_count = 0
    total_count = len(benchmark_test_cases)
    
    print(f"===== 開始執行 Text-to-SQL 基準測試 (共 {total_count} 題) =====")
    
    for i, test in enumerate(benchmark_test_cases, start=1):
        q = test["question"]
        golden_sql = test["golden_sql"]
        
        # 1. 取得 Golden 結果
        df_golden = run_sql_to_df(conn, golden_sql)
        
        # 2. 取得模型生成並執行的結果
        predicted_sql = assistant_func(q) # 此處假設返回生成的 SQL 字串
        df_pred = run_sql_to_df(conn, predicted_sql)
        
        # 3. 比較兩者內容是否一致 (忽略欄位大小寫與排序順序)
        is_match = False
        if not df_golden.empty and not df_pred.empty:
            # 依欄位值排序比對
            try:
                pd.testing.assert_frame_equal(
                    df_golden.sort_index(axis=1),
                    df_pred.sort_index(axis=1),
                    check_dtype=False,
                    check_like=True
                )
                is_match = True
            except AssertionError:
                is_match = False
                
        if is_match:
            print(f"第 {i} 題: [PASS] - {q}")
            passed_count += 1
        else:
            print(f"第 {i} 題: [FAIL] - {q}\n  Golden SQL: {golden_sql}\n  Pred SQL:   {predicted_sql}")

    accuracy = (passed_count / total_count) * 100
    print(f"\n==========================================")
    print(f"評測結束！執行準確率 (Execution Accuracy): {accuracy:.1f}% ({passed_count}/{total_count})")
    print(f"==========================================")
    return accuracy
```

---

## 🎯 本章重點彙整 (Key Takeaways)

```text
┌───────────────────┬──────────────────────────────────────────────────────────┐
│ 核心觀念          │ 工程實踐重點與面試得分點                                 │
├───────────────────┼──────────────────────────────────────────────────────────┤
│ Function Calling  │ LLM 扮演「大腦決策與參數提取」，由後端安全引擎執行實體操作│
│ 三道安全防線      │ DB 唯讀帳戶隔離 + Python AST 語法白名單 + 強制 LIMIT 50  │
│ 動態 Schema 注入  │ 壓縮 DDL 與列舉枚舉值，避免浪費 Context Window 與 Token 成本│
│ 自我修復迴圈      │ SQL 報錯時回餵原生錯誤 Traceback，自動修正語法與欄位錯字 │
│ Benchmark 評測    │ 使用 Golden SQL 與 Execution Accuracy 建立客觀品質評測體系│
└───────────────────┴──────────────────────────────────────────────────────────┘
```

---

## 🔗 章節導航

- **前一篇**：[01_LLM_API_Prompt工程與Structured_Output.md](./01_LLM_API_Prompt工程與Structured_Output.md)（Prompt 工程、Token 精算與原生結構化輸出）
- **安全審查**：[00_AI_Safety_Gate_安全防禦檢驗標準.md](./00_AI_Safety_Gate_安全防禦檢驗標準.md)（10 大滲透測試標準與 AST 防禦認證）
- **邁向下一月**：[Month 12 轉職衝刺與求職寶典](../12_Month12_轉職衝刺與求職寶典/README.md)（中英文履歷、50大核心面試題與求職看板）
- **回到目錄**：[Month 11 學習模組主導航](./README.md)

