# 02. ETL 自動化管線與企業日誌系統設計

> **📌 本章定位**：ETL（Extract, Transform, Load）是資料工程師最核心的本領。本篇的核心心智模型是：**「管線必須具備冪等性（Idempotency）、髒資料隔離性（Quarantine）與全鏈路可觀測性（Logging）」**。
>
> **⚠️ 痛點場景（生產管線三大事故）**：
> 1. **記憶體巨獸 OOM（Out of Memory）**：直接用 `pd.read_csv("10GB.csv")` 一次性載入，導致雲端伺服器記憶體瞬間耗盡被 Linux Kernel OOM Killer 砍死。
> 2. **一粒老鼠屎壞了一鍋粥**：10 萬筆交易資料跑到第 99,999 筆時，因某客戶統編填了 "N/A" 導致轉型崩潰，整個交易全盤回滾，業務主管一早看不到任何數據。
> 3. **補跑重跑導致營收翻倍**：半夜排程失敗，工程師早上手動補跑，因未設計「冪等載入（Staging + UPSERT）」，昨天所有金額被重複加總兩次，財務報表嚴重失真。
>
> **💡 學習策略**：先定位（ETL 核心架構）➔ 再理解（生成器串流讀取、Quarantine 模式與 Staging Table）➔ 再操作（動手寫具備 Webhook 告警的 ETL 控制器）➔ 再回收（生產級管線防護清單）。

---

## 目錄
1. [ETL 架構思維與業務價值](#1-etl-架構思維與業務價值)
   - [1.1 什麼是 ETL？ETL vs ELT 決策矩陣](#11-什麼是-etletl-vs-elt-決策矩陣)
   - [1.2 工業級管線的核心原則：冪等性與可觀測性](#12-工業級管線的核心原則冪等性與可觀測性)
2. [Extract 階段：異質來源防禦性讀取](#2-extract-階段異質來源防禦性讀取)
   - [2.1 企業常見檔案痛點：編碼、截斷與大檔處理](#21-企業常見檔案痛點編碼截斷與大檔處理)
   - [2.2 串流與生成器模式：避免記憶體崩潰](#22-串流與生成器模式避免記憶體崩潰)
3. [Transform 階段：資料清洗與壞資料隔離機制](#3-transform-階段資料清洗與壞資料隔離機制)
   - [3.1 資料型別清洗與標準化](#31-資料型別清洗與標準化)
   - [3.2 商業規則校驗與 Quarantine 隔離架構](#32-商業規則校驗與-quarantine-隔離架構)
4. [Load 階段：冪等載入與暫存表（Staging）模式](#4-load-階段冪等載入與暫存表staging模式)
   - [4.1 為什麼直接寫入主表是危險的？](#41-為什麼直接寫入主表是危險的)
   - [4.2 Staging Table 載入與原子切換實務](#42-staging-table-載入與原子切換實務)
5. [企業級日誌（Logging）系統架構](#5-企業級日誌logging系統架構)
   - [5.1 告別 print()：建立生產級 Logging 設定](#51-告別-print建立生產級-logging-設定)
   - [5.2 RotatingFileHandler 與管線指標度量](#52-rotatingfilehandler-與管線指標度量)
6. [自動化排程與即時異常告警（Webhook）](#6-自動化排程與即時異常告警webhook)
7. [商業情境綜合練習題（含詳解）](#7-商業情境綜合練習題含詳解)

---

## 1. ETL 架構思維與業務價值

在任何企業環境中，資料鮮少以乾淨、整齊、即時的方式存在於資料庫中。業務人員每天透過 Excel 回報訂單、第三方金流平台透過 API 定期提供結算對帳單、庫存條碼槍生成文字檔...

**ETL 管線的使命**，就是將這些混亂、零散的資料源，透過自動化程式穩健地轉換為業務決策系統所信賴的單一事實來源（Single Source of Truth）。

```
+------------------+     +------------------+     +------------------+
|  外部資料來源     |     |  Transform 清洗  |     |  PostgreSQL      |
|  - 業務 Excel    | --> |  - 型別校驗      | --> |  - Staging Table |
|  - 廠商 CSV      |     |  - 業務防偽規則  |     |  - 正式主表      |
|  - 門市 API      |     |  - 壞資料隔離    |     |  - 報表 View     |
+------------------+     +------------------+     +------------------+
                                  |
                                  v
                        [ Quarantine 隔離區 ]
                        (quarantine_YYYYMMDD.csv)
```

### 1.1 什麼是 ETL？ETL vs ELT 決策矩陣

| 維度 | 傳統 ETL (Extract -> Transform -> Load) | 現代 ELT (Extract -> Load -> Transform) |
| :--- | :--- | :--- |
| **運算發生地** | 專用的 Python 應用伺服器 / 記憶體 | 目標雲端資料倉儲（Snowflake, BigQuery, ClickHouse） |
| **載入前的資料** | 已清洗過、完全符合 Schema 的純淨資料 | 原始未加工資料（Raw JSON, Parquet）直接進入 Data Lake |
| **適用場景** | 關聯式資料庫（PostgreSQL, MySQL）、運算負載不能影響資料庫、有嚴格資安脫敏需求 | 巨量資料倉儲、分析維度多變、運算資源彈性極高的大數據場景 |
| **成本效益** | 中小型企業首選，利用低成本 Python 伺服器完成清洗 | 需支付較高的雲端倉儲運算費用 |

---

### 1.2 工業級管線的核心原則：冪等性與可觀測性

1. **冪等性（Idempotency）**：
   > **「無論這個管線因為斷電、網路中斷而重複執行了 1 次還是 100 次，資料庫最終的狀態必須完全相同，絕不會產生重複訂單或重複計算的金額！」**
2. **可觀測性（Observability）**：
   > 管線不能是個黑盒子。執行了多久？讀取了幾筆？成功幾筆？哪幾筆因為什麼原因失敗？產生的日誌必須讓維運人員在 30 秒內定位問題。
3. **無毒化（Detoxification）**：
   > 永遠不要因為 1 筆髒資料（例如金額填寫了字串 "N/A"），就讓整份含有 10 萬筆正常訂單的檔案全部失敗中斷。好的管線必須懂得「隔離壞資料，繼續處理好資料」。

---

## 2. Extract 階段：異質來源防禦性讀取

### 2.1 企業常見檔案痛點：編碼、截斷與大檔處理

在讀取外部檔案時，最容易讓腳本在半夜崩潰的三大殺手：
1. **編碼問題**：Windows 匯出的 CSV 常常是 `cp950`（Big5）或含有 `utf-8-sig`（BOM 檔頭）。
2. **格式不規範**：表頭前多出了 3 行報表說明文字；欄位數量前後不一致。
3. **記憶體爆裂**：一次性使用 `pd.read_csv("10GB.csv")` 導致伺服器 OOM 被作業系統強制終止。

### 2.2 串流與生成器模式：避免記憶體崩潰

使用 Python 內建的 `csv` 模組配合生成器（Generator），可以實現 **O(1) 恆定記憶體** 消耗：

```python
import csv
from typing import Generator, Dict, Any

def stream_csv_records(file_path: str, encoding: str = "utf-8-sig") -> Generator[Dict[str, Any], None, None]:
    """
    防禦性串流讀取 CSV 檔案
    - 自動處理 UTF-8 BOM 檔頭
    - 逐行產生字典，即使檔案達 50GB 也不會爆記憶體
    """
    with open(file_path, mode="r", encoding=encoding, errors="replace") as f:
        # 自動嗅探分隔符號（逗號或 Tab）
        sample = f.read(2048)
        f.seek(0)
        
        try:
            dialect = csv.Sniffer().sniff(sample)
        except csv.Error:
            dialect = csv.excel  # 預設使用標準逗號
            
        reader = csv.DictReader(f, dialect=dialect)
        
        for line_num, row in enumerate(reader, start=2):
            # 去除欄位鍵與值的多餘空白
            cleaned_row = {k.strip(): v.strip() if v else "" for k, v in row.items() if k}
            cleaned_row["_source_line"] = line_num
            yield cleaned_row
```

---

## 3. Transform 階段：資料清洗與壞資料隔離機制

### 3.1 資料型別清洗與標準化

外部輸入的欄位全都是字串型別，需轉為 Python 正確型別：

```python
from datetime import datetime
from decimal import Decimal, InvalidOperation
import re

def parse_currency(value_str: str) -> Decimal:
    """清洗金額字串：支援 '$1,200.50' 或 ' 1200.50 ' 或 'NT$ 500'"""
    if not value_str:
        return Decimal("0.00")
    # 移除非數字、非負號與非小數點字符
    cleaned = re.sub(r"[^\d.-]", "", value_str)
    try:
        return Decimal(cleaned).quantize(Decimal("0.01"))
    except InvalidOperation:
        raise ValueError(f"無法解析為合法金額: {value_str}")

def parse_order_date(date_str: str) -> datetime:
    """支援企業常見的多種日期格式：'2026-03-01', '2026/03/01', '01-03-2026'"""
    formats = ["%Y-%m-%d", "%Y/%m/%d", "%Y%m%d", "%Y-%m-%d %H:%M:%S"]
    for fmt in formats:
        try:
            return datetime.strptime(date_str, fmt)
        except ValueError:
            continue
    raise ValueError(f"未知的日期時間格式: {date_str}")
```

---

### 3.2 商業規則校驗與 Quarantine 隔離架構

當資料不符合商業規則時，我們採用 **Dead Letter Queue（死信佇列 / Quarantine 隔離檔案）** 機制：

```python
from dataclasses import dataclass, asdict
from typing import List, Tuple

@dataclass
class ValidatedOrderRow:
    order_id: str
    customer_id: str
    salesperson_id: str
    order_date: datetime
    product_id: str
    quantity: int
    unit_price: Decimal
    total_amount: Decimal

def validate_and_transform_pipeline(raw_records: Generator[dict, None, None]) -> Tuple[List[ValidatedOrderRow], List[dict]]:
    """
    雙軌清洗機制：
    - 通過校驗的資料進入 valid_rows 準備寫入資料庫
    - 失敗的資料附帶錯誤原因進入 quarantine_rows 輸出為待修正報表
    """
    valid_rows: List[ValidatedOrderRow] = []
    quarantine_rows: List[dict] = []
    
    for row in raw_records:
        line_num = row.get("_source_line", 0)
        errors = []
        
        # 1. 訂單編號必填檢驗
        order_id = row.get("Order ID", "")
        if not order_id:
            errors.append("訂單編號為空")
            
        # 2. 客戶編號格式檢驗
        customer_id = row.get("Customer Code", "")
        if not customer_id.startswith("CUST_"):
            errors.append(f"客戶代號格式錯誤: {customer_id}")
            
        # 3. 數量檢驗
        try:
            qty = int(row.get("Quantity", 0))
            if qty <= 0:
                errors.append(f"購買數量必須大於 0: {qty}")
        except ValueError:
            errors.append(f"購買數量非整數: {row.get('Quantity')}")
            qty = 0
            
        # 4. 單價檢驗
        try:
            price = parse_currency(row.get("Unit Price", ""))
            if price <= 0:
                errors.append(f"產品單價不可小於等於 0: {price}")
        except ValueError as ve:
            errors.append(str(ve))
            price = Decimal("0.00")
            
        # 5. 日期檢驗
        try:
            order_date = parse_order_date(row.get("Order Date", ""))
        except ValueError as ve:
            errors.append(str(ve))
            order_date = None

        if errors:
            # 壞資料存入隔離區
            row["_error_reasons"] = "; ".join(errors)
            quarantine_rows.append(row)
        else:
            total_amt = (price * qty).quantize(Decimal("0.01"))
            valid_rows.append(
                ValidatedOrderRow(
                    order_id=order_id,
                    customer_id=customer_id,
                    salesperson_id=row.get("Salesperson Code", "EMP_DEFAULT"),
                    order_date=order_date,
                    product_id=row.get("Product Code", ""),
                    quantity=qty,
                    unit_price=price,
                    total_amount=total_amt
                )
            )
            
    return valid_rows, quarantine_rows
```

---

## 4. Load 階段：冪等載入與暫存表（Staging）模式

### 4.1 為什麼直接寫入主表是危險的？
若批次處理有 50,000 筆資料，直接 `INSERT INTO orders`，寫到第 42,000 筆時網路發生中斷：
- 部分資料進了主表，部分沒進。
- 線上系統正在查詢，使用者看到了殘缺不齊的訂單。
- 下次重新跑腳本時，會因前 42,000 筆的主鍵衝突直接報錯中斷！

### 4.2 Staging Table 載入與原子切換實務

**標準企業設計模式：暫存表原子切換**：
1. 建立一張結構相同的暫存表 `staging_orders`（或使用 `UNLOGGED` 表提高寫入速度）。
2. 使用極速 `execute_values` 將清洗好的資料全數灌入 `staging_orders`。
3. 在單一資料庫交易內，透過 SQL `INSERT INTO orders ... ON CONFLICT ... DO UPDATE` 將資料整併至正式表。
4. 清空（`TRUNCATE`）或刪除暫存表。

```python
import psycopg2
from psycopg2.extras import execute_values

def load_data_via_staging(conn, valid_data: List[ValidatedOrderRow]):
    """使用暫存表實現安全、具冪等性的載入"""
    if not valid_data:
        return
    
    # 將 dataclass 轉為 tuple 列表
    tuples_data = [
        (
            r.order_id, r.customer_id, r.salesperson_id,
            r.order_date, r.total_amount
        )
        for r in valid_data
    ]

    create_staging_sql = """
    CREATE TEMP TABLE staging_orders (
        order_id VARCHAR(30),
        customer_id VARCHAR(20),
        salesperson_id VARCHAR(20),
        order_date TIMESTAMP,
        total_amount NUMERIC(14, 2)
    ) ON COMMIT DROP; -- 交易提交後自動刪除此暫存表
    """

    upsert_to_prod_sql = """
    INSERT INTO orders (order_id, customer_id, salesperson_id, order_date, total_amount, status)
    SELECT order_id, customer_id, salesperson_id, order_date, total_amount, 'APPROVED'
    FROM staging_orders
    ON CONFLICT (order_id) DO UPDATE SET
        total_amount = EXCLUDED.total_amount,
        order_date = EXCLUDED.order_date,
        status = 'APPROVED';
    """

    with conn: # 交易區塊：具備 ACID 原子性
        with conn.cursor() as cur:
            # 1. 建立暫存表
            cur.execute(create_staging_sql)
            
            # 2. 批次注入暫存表
            insert_staging_sql = """
            INSERT INTO staging_orders (order_id, customer_id, salesperson_id, order_date, total_amount)
            VALUES %s;
            """
            execute_values(cur, insert_staging_sql, tuples_data, page_size=2000)
            
            # 3. 從暫存表原子合流進正式生產表
            cur.execute(upsert_to_prod_sql)
            print(f"成功將 {len(tuples_data)} 筆訂單原子合併至生產正式表。")
```

---

## 5. 企業級日誌（Logging）系統架構

### 5.1 告別 print()：建立生產級 Logging 設定

`print()` 輸出在腳本結束後隨視窗關閉而消失，無法追溯歷史紀錄，且沒有等級過濾。我們必須使用 Python 內建的 `logging` 模組，並建立控制台（Console）與滾動檔案（Rotating File）雙向輸出。

```python
import logging
from logging.handlers import TimedRotatingFileHandler
import os

def setup_pipeline_logger(name: str = "etl_pipeline", log_dir: str = "logs") -> logging.Logger:
    """
    建立具備每日自動滾動與歷史備份的企業級 Logger
    """
    os.makedirs(log_dir, exist_ok=True)
    logger = logging.getLogger(name)
    logger.setLevel(logging.INFO)

    # 避免重複綁定 handler
    if logger.handlers:
        return logger

    # 統一日誌輸出格式
    formatter = logging.Formatter(
        fmt="[%(asctime)s] [%(levelname)s] [%(name)s] [%(filename)s:%(lineno)d] - %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    )

    # 1. 控制台 Handler (標準輸出)
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)

    # 2. 每日滾動檔案 Handler (每天午夜切割，保留 30 天日誌)
    file_handler = TimedRotatingFileHandler(
        filename=os.path.join(log_dir, "b2b_etl.log"),
        when="midnight",
        interval=1,
        backupCount=30,
        encoding="utf-8"
    )
    file_handler.setLevel(logging.INFO)
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)

    return logger
```

---

### 5.2 RotatingFileHandler 與管線指標度量

一個優秀的 ETL 任務在結束時，必須在日誌中打出結構化的「執行指標（Pipeline Metrics Summary）」：

```python
import time

def run_etl_with_metrics(file_path: str):
    logger = setup_pipeline_logger()
    start_time = time.time()
    
    metrics = {
        "file_path": file_path,
        "total_extracted": 0,
        "valid_records": 0,
        "quarantined_records": 0,
        "elapsed_seconds": 0.0
    }
    
    logger.info(f"===== 開始執行 B2B 訂單 ETL 管線: {file_path} =====")
    
    try:
        raw_stream = stream_csv_records(file_path)
        # 統計萃取總量
        raw_list = []
        for r in raw_stream:
            metrics["total_extracted"] += 1
            raw_list.append(r)
            
        valid_rows, bad_rows = validate_and_transform_pipeline(iter(raw_list))
        metrics["valid_records"] = len(valid_rows)
        metrics["quarantined_records"] = len(bad_rows)

        # 寫入隔離區
        if bad_rows:
            logger.warning(f"偵測到 {len(bad_rows)} 筆壞資料，已導向隔離清單！")
            # 儲存 bad_rows 到 quarantine 檔案...

        # 寫入資料庫
        # load_data_via_staging(conn, valid_rows)
        
        metrics["elapsed_seconds"] = round(time.time() - start_time, 2)
        logger.info(f"ETL 執行圓滿成功！指標統計: {metrics}")
        
    except Exception as e:
        metrics["elapsed_seconds"] = round(time.time() - start_time, 2)
        logger.critical(f"ETL 管線發生非預期致命崩潰: {e}", exc_info=True)
        # 觸發告警通知！
        raise e
```

---

## 6. 自動化排程與即時異常告警（Webhook）

在無維運人員駐守的伺服器環境中，當 ETL 失敗時，程式必須在 1 分鐘內主動呼叫 Webhook 通知團隊（例如 Slack、Discord、Microsoft Teams 或 Telegram）：

```python
import json
import urllib.request
import urllib.error

def send_slack_alert(webhook_url: str, error_title: str, details: str):
    """使用 Python 內建 urllib 發送 Webhook 告警，無需第三方套件依賴"""
    payload = {
        "text": f"🚨 *【B2B ETL 管線致命告警】*",
        "attachments": [
            {
                "color": "#FF0000",
                "title": error_title,
                "text": details,
                "footer": "ETL Monitor System"
            }
        ]
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        webhook_url,
        data=data,
        headers={"Content-Type": "application/json"}
    )
    try:
        with urllib.request.urlopen(req, timeout=5) as response:
            if response.status == 200:
                print("告警 Webhook 發送成功。")
    except urllib.error.URLError as e:
        print(f"告警發送失敗: {e}")
```

---

## 7. 商業情境綜合練習題（實戰動腦自測）

> 💡 **自我檢驗規範**：請先不要展開解答，在你的 Python 檔案中寫出清洗驗證邏輯與 Staging 流程，再點開參考擬答對照！

### 題目一：設計具備 Quarantine 隔離機制的 Excel 訂單匯入管線
**業務情境**：
外部經銷商每週會提供一份經銷商訂單 Excel 檔案（欄位包含：`Order_No`, `Customer_Code`, `SKU`, `Qty`, `Price`）。
請撰寫一個 Python 函式 `process_distributor_orders(file_path: str, conn)`：
1. 讀取資料並驗證：
   - `Order_No` 不得為空。
   - `Qty` 必須為大於 0 的正整數。
   - `Price` 必須大於 0。
2. 凡不符合條件的列，收集其完整資料與「錯誤原因」，存入 `quarantine/bad_orders_YYYYMMDD.csv`。
3. 驗證通過的列，透過 `psycopg2` 批次寫入資料庫 `staging_orders`。
4. 返回成功筆數與失敗筆數字典。

<details>
<summary>🔍 點擊展開「思維引導」</summary>

- 遍歷每筆資料時，建立 `errors = []` 清單收集所有校驗失敗原因。
- 若 `errors` 不為空，將原始行紀錄附加 `_file_line` 與 `_error_reason`，加入 `quarantined_records`。
- 若全數通過，才將清洗後的數值型態打包為 tuple 加入 `valid_records`，並使用 `execute_values` 批次寫入。
</details>

<details>
<summary>🔑 點擊展開「題目一參考擬答」</summary>

```python
import os
import csv
from datetime import datetime
from decimal import Decimal
import psycopg2
from psycopg2.extras import execute_values

def process_distributor_orders(file_path: str, conn) -> dict:
    """經銷商訂單處理管線：含髒資料隔離"""
    quarantine_dir = "quarantine"
    os.makedirs(quarantine_dir, exist_ok=True)
    today_str = datetime.now().strftime("%Y%m%d")
    quarantine_path = os.path.join(quarantine_dir, f"bad_orders_{today_str}.csv")
    
    valid_records = []
    quarantined_records = []
    
    # 1. 讀取 CSV
    with open(file_path, mode="r", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames or []
        
        for line_num, row in enumerate(reader, start=2):
            errors = []
            order_no = row.get("Order_No", "").strip()
            cust_code = row.get("Customer_Code", "").strip()
            sku = row.get("SKU", "").strip()
            qty_str = row.get("Qty", "").strip()
            price_str = row.get("Price", "").strip()
            
            # 業務邏輯驗證
            if not order_no:
                errors.append("訂單編號不能為空")
            if not sku:
                errors.append("產品料號不能為空")
                
            qty = 0
            try:
                qty = int(qty_str)
                if qty <= 0:
                    errors.append(f"數量必須為大於0的正整數(當前:{qty})")
            except ValueError:
                errors.append(f"數量非數字格式: {qty_str}")
                
            price = Decimal("0.00")
            try:
                price = Decimal(price_str)
                if price <= 0:
                    errors.append(f"單價必須大於0(當前:{price})")
            except Exception:
                errors.append(f"單價格式錯誤: {price_str}")
                
            if errors:
                row["_error_reason"] = " | ".join(errors)
                row["_file_line"] = line_num
                quarantined_records.append(row)
            else:
                valid_records.append((order_no, cust_code, sku, qty, price))

    # 2. 輸出隔離資料（若有）
    if quarantined_records:
        q_fields = list(fieldnames) + ["_file_line", "_error_reason"]
        with open(quarantine_path, mode="w", encoding="utf-8-sig", newline="") as qf:
            writer = csv.DictWriter(qf, fieldnames=q_fields)
            writer.writeheader()
            writer.writerows(quarantined_records)
            
    # 3. 批次寫入資料庫 Staging
    if valid_records:
        insert_sql = """
        INSERT INTO staging_orders (order_id, customer_id, product_id, quantity, unit_price)
        VALUES %s;
        """
        with conn:
            with conn.cursor() as cur:
                execute_values(cur, insert_sql, valid_records, page_size=1000)
                
    return {
        "success_count": len(valid_records),
        "quarantine_count": len(quarantined_records),
        "quarantine_file": quarantine_path if quarantined_records else None
    }
```
</details>

---

### 題目二：設計支援「冪等重跑」的訂單日結算彙總 ETL
**業務情境**：
公司每晚需執行 `daily_sales_summary` 彙總批次作業，計算當日每位業務員的總銷售額、總成交單數。
該腳本可能因為網路偶發問題而失敗，維運人員可能會手動補跑好幾次。
請設計一個具備**完全冪等性**的 SQL/Python 彙總流程：
- 目標資料表：`salesperson_daily_summary (summary_date, salesperson_id, total_orders, total_revenue)`。
- 主鍵約束：`PRIMARY KEY (summary_date, salesperson_id)`。
- 無論同一個 `summary_date` 執行多少次，都不會造成數據加倍累加。

<details>
<summary>🔍 點擊展開「思維引導」</summary>

- 彙總結果表必須有唯一的複合主鍵 `(summary_date, salesperson_id)`。
- 使用 `INSERT INTO ... ON CONFLICT (summary_date, salesperson_id) DO UPDATE SET ...`。
- 無論該函式對同一個 `target_date` 執行 1 次還是 10 次，資料庫中的統計數字保證完全一致。
</details>

<details>
<summary>🔑 點擊展開「題目二參考擬答」</summary>

```python
from datetime import date
import psycopg2

def run_daily_sales_summary(conn, target_date: date):
    """
    冪等性訂單日彙總管線
    - 採用 INSERT ... ON CONFLICT DO UPDATE (Upsert) 架構
    - 確保重跑時覆蓋而非累加
    """
    summary_sql = """
    INSERT INTO salesperson_daily_summary (
        summary_date, salesperson_id, total_orders, total_revenue
    )
    SELECT 
        DATE(o.order_date) AS summary_date,
        o.salesperson_id,
        COUNT(o.order_id) AS total_orders,
        COALESCE(SUM(o.total_amount), 0) AS total_revenue
    FROM orders o
    WHERE DATE(o.order_date) = %s AND o.status = 'APPROVED'
    GROUP BY DATE(o.order_date), o.salesperson_id
    ON CONFLICT (summary_date, salesperson_id)
    DO UPDATE SET
        total_orders = EXCLUDED.total_orders,
        total_revenue = EXCLUDED.total_revenue,
        updated_at = NOW();
    """
    
    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute(summary_sql, (target_date,))
                affected_rows = cur.rowcount
                print(f"[{target_date}] 業務日彙總計算完成，共處理/更新 {affected_rows} 位業務員數據。")
    except psycopg2.Error as e:
        print(f"彙總計算失敗: {e}")
        raise e
```
</details>

---

### 題目三：整合 Logging 與 Webhook 告警的排程管線核心控制器
**業務情境**：
請撰寫一個企業級 ETL 控制器類別 `ETLRunner`：
1. 封裝整個 ETL 的生命週期（開始、提取、清洗、入庫、結束）。
2. 在每個關鍵步驟使用 logger 記錄耗時與筆數。
3. 若發生未捕捉的異常，自動擷取完整的 Traceback，記錄至 CRITICAL 日誌，並觸發 Webhook 告警通知。

<details>
<summary>🔍 點擊展開「思維引導」</summary>

- 接收自定義的 step 函式作為參數（Higher-Order Function）。
- 使用 `time.time()` 測量整體執行時間。
- 使用 `traceback.format_exc()` 抓取錯誤字串，並在捕捉例外後主動 re-raise，確保呼叫端知曉失敗。
</details>

<details>
<summary>🔑 點擊展開「題目三參考擬答」</summary>

```python
import time
import traceback
from typing import Callable

class ETLRunner:
    def __init__(self, pipeline_name: str, webhook_url: str = None):
        self.pipeline_name = pipeline_name
        self.webhook_url = webhook_url
        self.logger = setup_pipeline_logger(pipeline_name)

    def execute(self, step_func: Callable, *args, **kwargs):
        start_time = time.time()
        self.logger.info(f">>> 啟動管線: [{self.pipeline_name}]")
        
        try:
            result = step_func(*args, **kwargs)
            elapsed = round(time.time() - start_time, 3)
            self.logger.info(f"<<< 管線 [{self.pipeline_name}] 順利完成！總耗時: {elapsed} 秒。回傳結果: {result}")
            return result
        except Exception as err:
            elapsed = round(time.time() - start_time, 3)
            tb_str = traceback.format_exc()
            self.logger.critical(
                f"❌ 管線 [{self.pipeline_name}] 於 {elapsed} 秒時崩潰！錯誤: {err}\nTraceback:\n{tb_str}"
            )
            
            # 若有配置 Webhook，觸發即時通知
            if self.webhook_url:
                try:
                    send_slack_alert(
                        webhook_url=self.webhook_url,
                        error_title=f"管線崩潰: {self.pipeline_name}",
                        details=f"錯誤類型: {type(err).__name__}\n訊息: {err}\n耗時: {elapsed}s"
                    )
                except Exception as alert_err:
                    self.logger.error(f"告警發送機制本身失敗: {alert_err}")
                    
            raise err
```
</details>

---

## 🎯 本章收斂總結
> **💡 核心金句**：
> 「串流讀檔防記憶，髒污隔離莫全棄；暫存切換保原子，冪等重跑無所懼。」

