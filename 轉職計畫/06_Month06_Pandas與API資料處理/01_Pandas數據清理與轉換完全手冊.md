# 01 Pandas 數據清理與轉換完全手冊

## 一、Pandas 核心操作 Cheatsheet

```python
import pandas as pd
import numpy as np

# 1. 建立與讀取
df = pd.read_csv("sales_data.csv")

# 2. 檢視結構
print(df.info())       # 欄位型態與非空值計數
print(df.describe())   # 數值型統計 (mean, std, min, max, 25%, 50%, 75%)
print(df.head(5))      # 預覽前 5 筆

# 3. 欄位篩選與條件過濾
high_value_df = df[(df["total_amount"] >= 100000) & (df["city"] == "Taipei")]

# 4. 缺失值處理
df["credit_limit"] = df["credit_limit"].fillna(50000.0) # 填補缺失
df = df.dropna(subset=["company_name"])                 # 刪除無公司名稱之列

# 5. 資料型態轉換
df["order_date"] = pd.to_datetime(df["order_date"])
df["year_month"] = df["order_date"].dt.to_period("M")

# 6. GroupBy 分組統計
summary_by_city = df.groupby("city").agg(
    total_revenue=("total_amount", "sum"),
    avg_order_value=("total_amount", "mean"),
    order_count=("order_id", "count")
).reset_index()
```
