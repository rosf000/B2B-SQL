# 01. Pandas 數據清理與轉換完全手冊

> **模組目標**：掌握商業分析與資料工程中最核心的資料處理函式庫 **Pandas**。徹底搞懂底層向量化（Vectorization）運算原理，告別低效的 Python 迴圈；熟練運用缺失值與異常值清洗、高效記憶體優化技巧；精通多表 Merge / Join、GroupBy 多重聚合、透視表（Pivot Table）以及時間序列滾動分析。結合 B2B 企業資料庫情境，實作具備生產水準的分析管線。

---

## 目錄
1. [Pandas 核心哲學：為什麼向量化運算如此飛快？](#1-pandas-核心哲學為什麼向量化運算如此飛快)
   - [1.1 記憶體連續性與 NumPy C-Array 架構](#11-記憶體連續性與-numpy-c-array-架構)
   - [1.2 效能大比拼：向量化 vs apply vs iterrows](#12-效能大比拼向量化-vs-apply-vs-iterrows)
2. [核心資料結構深度解析：Series 與 DataFrame](#2-核心資料結構深度解析series-與-dataframe)
   - [2.1 Index 索引的本質與對齊特性](#21-index-索引的本質與對齊特性)
   - [2.2 索引取值關鍵對決：loc vs iloc](#22-索引取值關鍵對決loc-vs-iloc)
3. [企業級資料清洗（Data Cleansing）實戰](#3-企業級資料清洗data-cleansing實戰)
   - [3.1 缺失值（NaN）的偵測、刪除與智慧填充](#31-缺失值nan的偵測刪除與智慧填充)
   - [3.2 重複值識別與唯一約束清理](#32-重複值識別與唯一約束清理)
   - [3.3 記憶體瘦身黑魔法：Category 型別優化](#33-記憶體瘦身黑魔法category-型別優化)
   - [3.4 向量化字串處理與正規表達式擷取](#34-向量化字串處理與正規表達式擷取)
4. [維度重塑與進階分析](#4-維度重塑與進階分析)
   - [4.1 GroupBy 分組與 agg() 多指標聚合](#41-groupby-分組與-agg-多指標聚合)
   - [4.2 樞紐分析（Pivot Table）與長寬表互轉（melt）](#42-樞紐分析pivot-table與長寬表互轉melt)
   - [4.3 多表關聯：merge, join, concat 與 SQL 映射](#43-多表關聯merge-join-concat-與-sql-映射)
5. [時間序列分析專題（Time Series）](#5-時間序列分析專題time-series)
   - [5.1 DatetimeIndex 與重採樣（resample）](#51-datetimeindex-與重採樣resample)
   - [5.2 滾動視窗（rolling）與趨勢平滑](#52-滾動視窗rolling與趨勢平滑)
6. [常見陷阱與避坑指南：SettingWithCopyWarning](#6-常見陷阱與避坑指南settingwithcopywarning)
7. [商業情境綜合練習題（含詳解）](#7-商業情境綜合練習題含詳解)

---

## 1. Pandas 核心哲學：為什麼向量化運算如此飛快？

初學 Python 轉職者最常見的壞習慣，就是把 Pandas DataFrame 當成二維列表（List of Lists），用 `for` 迴圈一行一行去運算資料。

### 1.1 記憶體連續性與 NumPy C-Array 架構

Python 原生列表（`list`）儲存的是**物件指標（Pointers）**，資料分散在記憶體各處；每次讀取都要經歷解指標（De-referencing）、動態型別檢查（Type Checking）與垃圾回收開銷。

Pandas 的底層是 **NumPy C-Array**：
- **記憶體連續（Contiguous Memory）**：同一個欄位的數據在記憶體中緊密相鄰排列。
- **單一資料型別（Homogeneous Type）**：每個欄位所有數值型別完全一致（例如 `int64`、`float64`）。
- **SIMD（單指令多資料流）**：現代 CPU 可透過向量化指令（如 AVX-512）在單一指令週期內同時對 8 個或 16 個浮點數進行加乘運算。

```
Python 原生 List: [ Pointer1 ] --> (PyObject: 1200)
                  [ Pointer2 ] --> (PyObject: 350)
                  (記憶體跳躍，慢！)

Pandas / NumPy:   | 1200.0 | 350.0 | 85000.0 | 450.0 |
                  (連續記憶體區塊，CPU 快取快，支援 SIMD 向量化運算！)
```

### 1.2 效能大比拼：向量化 vs apply vs iterrows

假設我們要針對 100 萬筆訂單明細計算 `小計 = 單價 * 數量 * (1 - 折扣率)`：

```python
import numpy as np
import pandas as pd
import time

# 模擬 100 萬筆訂單明細
n = 1_000_000
df = pd.DataFrame({
    "unit_price": np.random.uniform(100, 5000, size=n),
    "quantity": np.random.randint(1, 50, size=n),
    "discount": np.random.uniform(0, 0.2, size=n)
})

# 方法 1：極度慢的 iterrows() 迴圈（耗時約 25 ~ 40 秒）
# for idx, row in df.iterrows(): ...

# 方法 2：使用 apply() 匿名函式（耗時約 1.5 ~ 2.5 秒）
# df["subtotal"] = df.apply(lambda r: r["unit_price"] * r["quantity"] * (1 - r["discount"]), axis=1)

# 方法 3：底層向量化運算（耗時僅需 0.005 ~ 0.015 秒，比 iterrows 快近 3000 倍！）
start = time.time()
df["subtotal"] = df["unit_price"] * df["quantity"] * (1 - df["discount"])
print(f"向量化運算耗時: {time.time() - start:.4f} 秒")
```

> **金科玉律**：在 Pandas 中，凡能使用向量化算式（加減乘除、邏輯運算子 `&`, `|`）、內建向量化函式（如 `.str`、`.dt`）解決的，**絕對不要使用 `.apply(..., axis=1)`，更絕對禁止使用 `iterrows()`**！

---

## 2. 核心資料結構深度解析：Series 與 DataFrame

### 2.1 Index 索引的本質與對齊特性

Pandas 最強大的特性之一是 **自動索引對齊（Automatic Index Alignment）**：
當兩個 Series 進行相加時，Pandas 不是根據「位置」相加，而是根據「**相同的 Index 標籤**」相加！

```python
# 業務部 1 月業績
sales_jan = pd.Series([120, 85, 95], index=["Alice", "Bob", "Charlie"])
# 業務部 2 月業績（注意順序與成員不同）
sales_feb = pd.Series([90, 110, 40], index=["Charlie", "Alice", "David"])

# 自動根據業務姓名對齊相加！
total_sales = sales_jan.add(sales_feb, fill_value=0)
print(total_sales)
# Alice      230.0 (120 + 110)
# Bob         85.0 (85 + 0)
# Charlie    185.0 (95 + 90)
# David       40.0 (0 + 40)
```

### 2.2 索引取值關鍵對決：loc vs iloc

這在初學者代碼中是引發 Bug 的頭號元兇：
- **`loc`（Label-based）**：依據**標籤名稱**切片。**包含結尾端點**！
- **`iloc`（Integer-position based）**：依據**底層數值位置（從 0 開始）**切片。**遵循 Python 慣例：左閉右開（不含結尾端點）**！

```python
df_demo = pd.DataFrame(
    {"company": ["科技A", "生技B", "傳產C"], "revenue": [500, 300, 800]},
    index=[101, 102, 103] # 非預設 0, 1, 2
)

# 使用 loc[101:102] -> 尋找標籤為 101 到 102 的列（包含 102，共 2 筆）
print(df_demo.loc[101:102, ["company"]])

# 使用 iloc[0:2] -> 尋找第 0 個位置到第 2 個位置（不含 2，即第 0, 1 列，共 2 筆）
print(df_demo.iloc[0:2, 0:1])
```

---

## 3. 企業級資料清洗（Data Cleansing）實戰

### 3.1 缺失值（NaN）的偵測、刪除與智慧填充

```python
# 建立範例客戶資料表
df_customers = pd.DataFrame({
    "customer_id": ["CUST_001", "CUST_002", "CUST_003", "CUST_004", "CUST_005"],
    "company_name": ["台積電商務", "聯發通信", "廣達系統", None, "華碩科技"],
    "industry": ["半導體", "IC設計", None, "零售", "電腦週邊"],
    "credit_limit": [5000000.0, None, 2000000.0, 500000.0, None],
    "region": ["北區", "北區", "中區", "南區", "北區"]
})

# 1. 偵測缺失值比例
missing_report = df_customers.isna().sum() / len(df_customers) * 100
print("欄位缺失比例(%):\n", missing_report)

# 2. 刪除關鍵識別欄位為空的無效列（例如 company_name 為空）
df_clean = df_customers.dropna(subset=["company_name"]).copy()

# 3. 智慧填充：類別欄位以固定值或眾數填充
df_clean["industry"] = df_clean["industry"].fillna("其他未分類")

# 4. 智慧填充：數值欄位依據「地區分組中位數」填充信用額度！
df_clean["credit_limit"] = df_clean.groupby("region")["credit_limit"].transform(
    lambda grp: grp.fillna(grp.median())
)
# 若仍有缺失（該分組全為空），以整體中位數防禦
df_clean["credit_limit"] = df_clean["credit_limit"].fillna(df_clean["credit_limit"].median())
```

### 3.2 重複值識別與唯一約束清理

```python
# 業務系統常發生重送或多終端上報導致的重複資料
# 找出所有重複的訂單編號（保留最後更新的一筆）
df_orders = pd.DataFrame({
    "order_id": ["ORD_001", "ORD_002", "ORD_001", "ORD_003"],
    "version": [1, 1, 2, 1],
    "amount": [1000, 2500, 1200, 3000]
})

# 依照 version 排序後，保留最後一筆
df_dedup = df_orders.sort_values("version").drop_duplicates(subset=["order_id"], keep="last")
print(df_dedup)
```

### 3.3 記憶體瘦身黑魔法：Category 型別優化

當資料庫有上千萬筆訂單，其中「訂單狀態（PENDING, APPROVED, SHIPPED, CANCELLED）」或「產業別」等重複字串欄位，預設會以 Python `object` 字串指標存儲，極耗記憶體。將其轉為 `category`（內部以 8-bit 整數編碼）能**瞬間減少 80% 記憶體**：

```python
# 記憶體分析
print("未優化前記憶體佔用:")
print(df_clean.memory_usage(deep=True))

# 轉換為 category
df_clean["industry"] = df_clean["industry"].astype("category")
df_clean["region"] = df_clean["region"].astype("category")

print("優化後記憶體佔用:")
print(df_clean.memory_usage(deep=True))
```

### 3.4 向量化字串處理與正規表達式擷取

```python
df_contacts = pd.DataFrame({
    "info": [
        "採購部: 王大明 <wang@tsmc.com> (分機: 1234)",
        "財務部: 李小美 <lee@mediatek.com> (分機: 8888)",
        "資訊部: 陳經理 <chen@asus.com>"
    ]
})

# 向量化正規擷取姓名與 Email
extracted = df_contacts["info"].str.extract(r":\s*(?P<name>[\u4e00-\u9fa5]+)\s*<(?P<email>[^>]+)>")
print(extracted)
#     name                email
# 0  王大明      wang@tsmc.com
# 1  李小美  lee@mediatek.com
# 2  陳經理       chen@asus.com
```

---

## 4. 維度重塑與進階分析

### 4.1 GroupBy 分組與 agg() 多指標聚合

現代商業分析常需一次計算多個統計指標（總合、平均、筆數、最大值）：

```python
df_sales = pd.DataFrame({
    "department": ["南區", "北區", "北區", "中區", "南區", "北區"],
    "salesperson": ["張三", "李四", "王五", "趙六", "張三", "李四"],
    "revenue": [50000, 120000, 80000, 45000, 70000, 95000]
})

# 多重指標聚合
dept_summary = df_sales.groupby("department")["revenue"].agg(
    total_revenue="sum",
    avg_deal_size="mean",
    deal_count="count",
    max_deal="max"
).reset_index()

# 格式化百分比與貨幣
dept_summary["revenue_share"] = (dept_summary["total_revenue"] / dept_summary["total_revenue"].sum() * 100).round(2)
print(dept_summary)
```

### 4.2 樞紐分析（Pivot Table）與長寬表互轉（melt）

```python
# 業務員在各季度的銷售業績
df_quarterly = pd.DataFrame({
    "salesperson": ["李四", "李四", "王五", "王五", "張三"],
    "quarter": ["Q1", "Q2", "Q1", "Q2", "Q1"],
    "sales": [120000, 150000, 80000, 90000, 50000]
})

# 1. 轉為寬表（Pivot Table）
pivot_wide = df_quarterly.pivot_table(
    index="salesperson",
    columns="quarter",
    values="sales",
    fill_value=0,
    aggfunc="sum",
    margins=True,          # 加上總計欄列
    margins_name="Total"
)
print("=== 季度銷售樞紐分析表 ===\n", pivot_wide)

# 2. 寬表轉長表（Melt）：適合將報表還原為資料庫友善的格式
df_wide_demo = pd.DataFrame({
    "salesperson": ["李四", "王五"],
    "Q1": [120000, 80000],
    "Q2": [150000, 90000]
})
df_long = df_wide_demo.melt(
    id_vars=["salesperson"],
    value_vars=["Q1", "Q2"],
    var_name="quarter",
    value_name="sales"
)
print("=== 長表格式 ===\n", df_long)
```

### 4.3 多表關聯：merge, join, concat 與 SQL 映射

| Pandas 語法 | SQL 對應語法 | 說明 |
| :--- | :--- | :--- |
| `pd.merge(df1, df2, on='key', how='inner')` | `SELECT * FROM df1 INNER JOIN df2 ON ...` | 僅保留兩表均匹配之列 |
| `pd.merge(df1, df2, on='key', how='left')` | `SELECT * FROM df1 LEFT JOIN df2 ON ...` | 保留左表全部，右表無匹配填 NaN |
| `pd.merge(df1, df2, on='key', how='outer')` | `SELECT * FROM df1 FULL OUTER JOIN df2 ON ...` | 兩表全保留，無匹配填 NaN |
| `pd.concat([df1, df2], axis=0)` | `SELECT * FROM df1 UNION ALL SELECT * FROM df2` | 直向堆疊追加資料行 |
| `pd.concat([df1, df2], axis=1)` | 橫向按 Index 拼裝欄位 | 類似依據位置或索引水平拼接 |

---

## 5. 時間序列分析專題（Time Series）

在 B2B 財務分析中，時間維度（日、週、月、季、年）的重採樣與滾動計算是必考題。

```python
# 產生連續 90 天的模擬每日下單紀錄
dates = pd.date_range(start="2026-01-01", periods=90, freq="D")
np.random.seed(42)
df_daily_orders = pd.DataFrame({
    "order_date": dates,
    "daily_revenue": np.random.normal(loc=50000, scale=8000, size=90).round(2)
})
df_daily_orders.set_index("order_date", inplace=True)

# 5.1 月度重採樣（Resample）：類似 SQL 的 DATE_TRUNC('month', ...)
monthly_summary = df_daily_orders.resample("ME").agg({
    "daily_revenue": ["sum", "mean", "count"]
})
print("=== 月度重採樣報告 ===\n", monthly_summary)

# 5.2 7 日滑動移動平均線（Rolling 7-day Moving Average）：平滑週末效應
df_daily_orders["ma_7d"] = df_daily_orders["daily_revenue"].rolling(window=7, min_periods=1).mean()
print("=== 含 7 日均線之數據預覽 ===\n", df_daily_orders.head(10))
```

---

## 6. 常見陷阱與避坑指南：SettingWithCopyWarning

你一定看過這段令人心驚膽跳的警告：
`SettingWithCopyWarning: A value is trying to be set on a copy of a slice from a DataFrame.`

### 為什麼會發生？
因為 Pandas 無法確定你篩選出來的子表到底是原始 DataFrame 的**副本（Copy）**還是**檢視視圖（View）**。當你嘗試對其指派修改時，可能根本沒修改到原始資料！

```python
# 錯誤示範（鏈式賦值 Chained Assignment）
df_bad = pd.DataFrame({"company": ["A", "B", "C"], "score": [80, 55, 90]})
# 隱式分兩步：先取 slice，再 set，觸發 Warning！
df_bad[df_bad["score"] < 60]["score"] = 60 

# 正確作法 1：使用 .loc 明確在原 DataFrame 上定位賦值
df_bad.loc[df_bad["score"] < 60, "score"] = 60

# 正確作法 2：若要產出獨立的新 DataFrame，明確呼叫 .copy()
df_sub = df_bad[df_bad["score"] >= 80].copy()
df_sub["grade"] = "VIP"  # 安全！絕不會觸發 Warning
```

---

## 7. 商業情境綜合練習題（含詳解）

### 題目一：B2B 客戶價值分析（RFM 模型運算）
**業務情境**：
行銷主管希望針對所有客戶進行 RFM 分群：
- **R（Recency 最新購買天數）**：以基準日 `2026-06-30` 為準，該客戶「最後一次下單日」距離基準日相差多少天。
- **F（Frequency 購買頻率）**：該客戶的總下單次數。
- **M（Monetary 消費金額）**：該客戶的累計訂單總金額。
請撰寫一個函式 `calculate_rfm(df_orders, snapshot_date)`，產出每個客戶的 R、F、M 指標，並依 M（消費金額）由大至小排序。

#### 【題目一解答程式碼】
```python
import pandas as pd
from datetime import datetime

def calculate_rfm(df_orders: pd.DataFrame, snapshot_date: str = "2026-06-30") -> pd.DataFrame:
    """
    計算 B2B 客戶 RFM 指標
    df_orders 欄位要求: customer_id, order_date, total_amount
    """
    df = df_orders.copy()
    df["order_date"] = pd.to_datetime(df["order_date"])
    ref_date = pd.to_datetime(snapshot_date)
    
    # 分組聚合計算 RFM
    rfm = df.groupby("customer_id").agg(
        last_order_date=("order_date", "max"),
        Frequency=("order_date", "count"),
        Monetary=("total_amount", "sum")
    ).reset_index()
    
    # 計算 Recency（相差天數）
    rfm["Recency"] = (ref_date - rfm["last_order_date"]).dt.days
    
    # 整理輸出欄位
    result = rfm[["customer_id", "Recency", "Frequency", "Monetary"]].sort_values(
        by="Monetary", ascending=False
    ).reset_index(drop=True)
    
    return result

# 測試資料驗證
orders_test = pd.DataFrame({
    "customer_id": ["CUST_A", "CUST_B", "CUST_A", "CUST_C", "CUST_B"],
    "order_date": ["2026-06-25", "2026-05-10", "2026-06-28", "2026-01-15", "2026-06-01"],
    "total_amount": [50000, 120000, 30000, 15000, 80000]
})
print("=== 客戶 RFM 指標分析結果 ===")
print(calculate_rfm(orders_test, "2026-06-30"))
```

---

### 題目二：多產品線月營收透視與 MoM（月增率）計算
**業務情境**：
請使用 `orders` 與 `order_items` 合併後的明細資料表，產出各「產品類別（category）」在各月份的銷售總額透視表，並計算各類別在最近一個月的「月增率（MoM, Month-over-Month Growth %）」。
- 欄位：`category`, `order_date`, `subtotal`
- 月增率公式：`((當月營收 - 上月營收) / 上月營收) * 100`

#### 【題目二解答程式碼】
```python
def calculate_category_mom(df_sales_items: pd.DataFrame) -> pd.DataFrame:
    df = df_sales_items.copy()
    df["order_date"] = pd.to_datetime(df["order_date"])
    # 轉換為 YYYY-MM 格式字串或 Period
    df["year_month"] = df["order_date"].dt.to_period("M")
    
    # 1. 建立月營收透視表
    pivot = df.pivot_table(
        index="category",
        columns="year_month",
        values="subtotal",
        aggfunc="sum",
        fill_value=0.0
    )
    
    # 2. 計算月增率 (pct_change 沿著 columns 方向: axis=1)
    mom_table = pivot.pct_change(axis=1) * 100
    mom_table = mom_table.round(2)
    
    # 合併兩者或展示最近一個月的 MoM
    latest_month = pivot.columns[-1]
    prev_month = pivot.columns[-2] if len(pivot.columns) >= 2 else None
    
    if prev_month:
        pivot[f"MoM_{latest_month}_%"] = (
            (pivot[latest_month] - pivot[prev_month]) / pivot[prev_month] * 100
        ).round(2)
        
    return pivot

# 測試資料
items_data = pd.DataFrame({
    "category": ["晶片零組件", "晶片零組件", "感測模組", "感測模組", "伺服器機架", "伺服器機架"],
    "order_date": ["2026-04-10", "2026-05-12", "2026-04-15", "2026-05-20", "2026-04-05", "2026-05-18"],
    "subtotal": [100000, 150000, 40000, 36000, 300000, 450000]
})
print("=== 產品類別營收透視與 MoM 報表 ===")
print(calculate_category_mom(items_data))
```

---

### 題目三：庫存出庫滑動監控與安全水位預警系統
**業務情境**：
倉庫管理系統記錄了每天各產品的出庫扣減紀錄（出庫日 `log_date`, 產品代碼 `product_id`, 出庫數量 `qty_out`），以及產品主表中的「當前現有庫存 `current_stock`」。
請撰寫一個監控演算法：
1. 針對每項產品，計算「最近 7 天的每日平均出庫消耗量（7-day Rolling Burn Rate）」。
2. 預估「現有庫存預計可支撐天數（Days of Inventory Remaining, DIR）」：
   - `DIR = current_stock / 最近 7 天平均每日出庫量`
3. 若 `DIR < 14 天`，標記警示為 `"CRITICAL: 請立即下採購單"`；若 `DIR < 30 天`，標記 `"WARNING: 庫存偏低"`；其餘為 `"NORMAL"`。

#### 【題目三解答程式碼】
```python
def generate_inventory_alert_report(df_logs: pd.DataFrame, df_products: pd.DataFrame) -> pd.DataFrame:
    """
    庫存安全天數預警管線
    """
    logs = df_logs.copy()
    logs["log_date"] = pd.to_datetime(logs["log_date"])
    
    # 確保每個產品在最近 7 天內的出庫量被正確加總
    # 取最近 7 天
    max_date = logs["log_date"].max()
    start_date = max_date - pd.Timedelta(days=6) # 包含最後一天共 7 天
    
    recent_7d_logs = logs[logs["log_date"] >= start_date]
    
    # 計算每項產品 7 天內出庫總量，除以 7 取得每日平均消耗量
    burn_rate = recent_7d_logs.groupby("product_id")["qty_out"].sum().reset_index()
    burn_rate["daily_burn_rate"] = (burn_rate["qty_out"] / 7.0).round(2)
    
    # 與產品主表合併
    merged = pd.merge(df_products, burn_rate, on="product_id", how="left")
    merged["daily_burn_rate"] = merged["daily_burn_rate"].fillna(0.0)
    
    # 計算可支撐天數 DIR (防範除以 0)
    def calc_dir(row):
        burn = row["daily_burn_rate"]
        stock = row["current_stock"]
        if burn <= 0:
            return 999.0 # 無消耗，視為安全
        return round(stock / burn, 1)

    merged["days_remaining"] = merged.apply(calc_dir, axis=1)

    # 警示等級判斷
    def set_alert(days):
        if days < 14:
            return "CRITICAL: 請立即下採購單"
        elif days < 30:
            return "WARNING: 庫存偏低"
        else:
            return "NORMAL"

    merged["alert_level"] = merged["days_remaining"].apply(set_alert)
    
    output_cols = ["product_id", "product_name", "current_stock", "daily_burn_rate", "days_remaining", "alert_level"]
    return merged[output_cols].sort_values("days_remaining", ascending=True).reset_index(drop=True)

# 測試資料
df_prod_mock = pd.DataFrame({
    "product_id": ["P101", "P102", "P103"],
    "product_name": ["車用 MCU 晶片", "光電感測器", "工業伺服主板"],
    "current_stock": [150, 800, 30]
})
df_logs_mock = pd.DataFrame({
    "log_date": ["2026-06-24", "2026-06-25", "2026-06-26", "2026-06-27", "2026-06-28", "2026-06-29", "2026-06-30"] * 3,
    "product_id": ["P101"] * 7 + ["P102"] * 7 + ["P103"] * 7,
    "qty_out": [20, 15, 25, 30, 10, 18, 22,   # P101 每日平均約 20，庫存 150 -> 約 7.5 天 (CRITICAL)
                10, 12, 8, 15, 11, 9, 14,     # P102 每日平均約 11，庫存 800 -> 約 70 天 (NORMAL)
                2, 3, 1, 4, 2, 3, 2]          # P103 每日平均約 2.4，庫存 30 -> 約 12.5 天 (CRITICAL)
})

print("=== 庫存水位預警系統報告 ===")
print(generate_inventory_alert_report(df_logs_mock, df_prod_mock))
```
