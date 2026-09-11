# 04 Production 工程三件套：冪等性 (Idempotency)、資料品質檢查 (Data Quality) 與稽核日誌 (Audit Log)

> **「初學者寫的 ETL：能跑通一次就算成功；資深工程師寫的 ETL：跑十次結果依然一致、資料有髒污立即攔截、每一次執行都有完整歷史審計。」**

在面試 Data Engineer 職位時，面試官一定會問你這個致命問題：
> *「如果你的 ETL 排程因為網路中斷失敗，維運人員手動重跑了一次，你的資料庫會不會產生重複資料？你怎麼知道今天進來的資料量有沒有異常暴跌？」*

如果你回答「我用 `df.to_sql(if_exists='append')`」，你在面試官心中立刻被歸類為非工程背景的新手。本篇將手把手帶你為 Project 2 注入真正的 **Production 三件套**。

---

## 🛡️ 第一件套：冪等性 (Idempotency)

### 什麼是冪等性？
> **$f(f(x)) = f(x)$**：同一個操作無論執行 1 次還是執行 100 次，系統的最終狀態都完全相同，且不會產生副作用。

```
❌ 非冪等 (append 累加)：
Run #1 寫入 10,000 筆 ➜ 資料庫有 10,000 筆
Run #2 重跑 10,000 筆 ➜ 資料庫暴增為 20,000 筆 (財報重複計算、分析全毀！)

✅ 冪等性 (Idempotent)：
Run #1 寫入 10,000 筆 ➜ 資料庫有 10,000 筆
Run #2 重跑 10,000 筆 ➜ 資料庫依然維持 10,000 筆！
```

### 解決方案 A：PostgreSQL 原生 UPSERT (`ON CONFLICT DO UPDATE`)
適用於「逐筆」或「按天然鍵 (Natural Key)」更新維度表的場景：

```python
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy import Table, MetaData

def upsert_customers(engine, customer_records: list[dict]):
    """
    若 customer_code 存在則更新資料，不存在則新增。
    保證重複執行不會造成 Primary Key / Unique Key 衝突。
    """
    metadata = MetaData()
    metadata.reflect(bind=engine, only=['dim_customers'])
    cust_table = metadata.tables['dim_customers']
    
    insert_stmt = insert(cust_table).values(customer_records)
    
    # 衝突時執行的更新語句
    do_update_stmt = insert_stmt.on_conflict_do_update(
        index_elements=['customer_code'],  # 唯一業務鍵
        set_={
            'company_name': insert_stmt.excluded.company_name,
            'contact_email': insert_stmt.excluded.contact_email,
            'updated_at': insert_stmt.excluded.updated_at
        }
    )
    
    with engine.begin() as conn:
        result = conn.execute(do_update_stmt)
        print(f"Upsert 完成，影響列數: {result.rowcount}")
```

### 解決方案 B：暫存表原子性切換 (Staging & Atomic Swap)
適用於每日「全量刷新 (Full Snapshot)」或「批次分區刷新」的場景：

```python
from sqlalchemy import text

def idempotent_batch_load(engine, df, target_table="fact_daily_orders", partition_date="2024-03-31"):
    """
    以交易 (Transaction) 保證特定分區資料在寫入時的原子性與冪等性：
    先在 Transaction 內刪除舊分區資料，再寫入新資料。
    若中途任何步驟失敗，自動回滾 (Rollback)，不留殘缺資料。
    """
    with engine.begin() as conn:
        # 1. 清理舊分區
        conn.execute(
            text(f"DELETE FROM {target_table} WHERE order_date = :p_date"),
            {"p_date": partition_date}
        )
        # 2. 寫入新分區 (底層使用同一個 connection)
        df.to_sql(target_table, con=conn, if_exists="append", index=False)
        print(f"分區 {partition_date} 冪等覆蓋寫入成功！")
```

---

## 🔍 第二件套：資料品質防衛閘門 (Data Quality Gate)

在資料正式寫入 Production Database 前，必須經過 **Data Quality (DQ) 檢查**。若未達標，立即阻斷管線並告警！

### 核心檢查指標：
1. **NULL Check**：關鍵欄位（如訂單金額、客戶 ID）不准為空。
2. **Duplicate Check**：業務鍵（如 order_number）嚴禁重複。
3. **Row Count Anomaly Check**：若今日進單量比過去 7 天平均暴跌 > 50% 或暴增 > 300%，視為源頭系統可能故障。
4. **Range / Enum Check**：訂單金額必須 > 0，狀態必須在合法的列表內。

### 實作程式碼：輕量級 DQ 檢查器

```python
import pandas as pd
from typing import NamedTuple

class DQResult(NamedTuple):
    passed: bool
    check_name: str
    details: str

class DataQualityChecker:
    def __init__(self, df: pd.DataFrame):
        self.df = df
        self.results: list[DQResult] = []

    def check_not_null(self, columns: list[str]) -> "DataQualityChecker":
        for col in columns:
            null_count = self.df[col].isnull().sum()
            passed = (null_count == 0)
            self.results.append(DQResult(
                passed=passed,
                check_name=f"NULL_CHECK: {col}",
                details=f"發現 {null_count} 筆空值" if not passed else "通過"
            ))
        return self

    def check_unique(self, columns: list[str]) -> "DataQualityChecker":
        for col in columns:
            dup_count = self.df[col].duplicated().sum()
            passed = (dup_count == 0)
            self.results.append(DQResult(
                passed=passed,
                check_name=f"UNIQUE_CHECK: {col}",
                details=f"發現 {dup_count} 筆重複值" if not passed else "通過"
            ))
        return self

    def check_positive_values(self, columns: list[str]) -> "DataQualityChecker":
        for col in columns:
            invalid_count = (self.df[col] <= 0).sum()
            passed = (invalid_count == 0)
            self.results.append(DQResult(
                passed=passed,
                check_name=f"POSITIVE_CHECK: {col}",
                details=f"發現 {invalid_count} 筆非正數" if not passed else "通過"
            ))
        return self

    def evaluate(self, fail_fast: bool = True) -> bool:
        """綜合評估所有檢查，若失敗則拋出異常阻斷管線"""
        all_passed = all(r.passed for r in self.results)
        for r in self.results:
            icon = "✅" if r.passed else "❌"
            print(f"{icon} [{r.check_name}] {r.details}")
        
        if not all_passed and fail_fast:
            raise ValueError("🚨 Data Quality Gate 攔截：資料品質不合格，停止載入！")
        return all_passed
```

---

## 📜 第三件套：管線稽核日誌 (Audit Log & Metadata Tracking)

每個嚴謹的 Data Pipeline，都必須在資料庫中留存一張 **`pipeline_execution_logs`** 元資料表：

### 稽核表 DDL (PostgreSQL)

```sql
CREATE TABLE IF NOT EXISTS pipeline_execution_logs (
    run_id VARCHAR(64) PRIMARY KEY,
    pipeline_name VARCHAR(100) NOT NULL,
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) NOT NULL, -- 'RUNNING', 'SUCCESS', 'FAILED'
    rows_extracted INT DEFAULT 0,
    rows_loaded INT DEFAULT 0,
    rows_rejected INT DEFAULT 0,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

### Python Context Manager 自動審計範例

```python
import uuid
import datetime
from contextlib import contextmanager
from sqlalchemy import text

@contextmanager
def track_pipeline_run(engine, pipeline_name: str):
    run_id = f"{pipeline_name}_{uuid.uuid4().hex[:8]}"
    start_time = datetime.datetime.now(datetime.timezone.utc)
    
    # 1. 登記啟動狀態
    with engine.begin() as conn:
        conn.execute(
            text("""
                INSERT INTO pipeline_execution_logs (run_id, pipeline_name, start_time, status)
                VALUES (:rid, :pname, :start, 'RUNNING')
            """),
            {"rid": run_id, "pname": pipeline_name, "start": start_time}
        )
    
    metrics = {"rows_extracted": 0, "rows_loaded": 0, "rows_rejected": 0}
    try:
        yield run_id, metrics  # 把控制權交給實際的 ETL 邏輯
        
        # 2. 成功完成
        end_time = datetime.datetime.now(datetime.timezone.utc)
        with engine.begin() as conn:
            conn.execute(
                text("""
                    UPDATE pipeline_execution_logs
                    SET end_time = :end, status = 'SUCCESS',
                        rows_extracted = :re, rows_loaded = :rl, rows_rejected = :rj
                    WHERE run_id = :rid
                """),
                {"end": end_time, "rid": run_id, "re": metrics["rows_extracted"], 
                 "rl": metrics["rows_loaded"], "rj": metrics["rows_rejected"]}
            )
        print(f"🎉 Pipeline {run_id} 成功完成並記入稽核日誌！")
    except Exception as exc:
        # 3. 異常失敗記錄
        end_time = datetime.datetime.now(datetime.timezone.utc)
        with engine.begin() as conn:
            conn.execute(
                text("""
                    UPDATE pipeline_execution_logs
                    SET end_time = :end, status = 'FAILED', error_message = :err
                    WHERE run_id = :rid
                """),
                {"end": end_time, "rid": run_id, "err": str(exc)}
            )
        print(f"💥 Pipeline {run_id} 失敗已記錄：{exc}")
        raise exc
```

---

## 🎓 M5 Exit Exam：Production Reality 考核

在結業 M5 時，你必須向面試官展示你的 Project 2 具備以下能力：
- [ ] **冪等性驗證**：在命令列連續執行 2 次 ETL 腳本，資料庫總列數完全一致。
- [ ] **品質攔截驗證**：故意在來源 Excel 注入帶有 NULL 的訂單金額或重複的 Order ID，管線能在 3 秒內攔截報錯、終止載入並記錄到日誌。
- [ ] **稽核查詢**：能在 DBeaver 中打開 `pipeline_execution_logs`，清楚指認每一筆執行的耗時與筆數。

> 當你的 Project 2 具備這三件套，面試官立刻會知道你不是一個只會寫爬蟲的半吊子，而是一個理解**企業級資料一致性與維運成本**的合格工程師！
