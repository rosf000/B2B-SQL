# 04 Python 核心語法與演算法練習題庫（15 題含擬答）

請在 VS Code 中建立 `practice.py` 逐題練習，並養成不看解答先自行除錯的習慣。

---

### Q1. 給定一個整數列表 `nums = [12, 45, 78, 23, 56, 89, 90]`，請找出其中的最大值與最小值（不使用 `max()` / `min()` 內建函數）。
```python
nums = [12, 45, 78, 23, 56, 89, 90]
max_val = nums[0]
min_val = nums[0]
for n in nums[1:]:
    if n > max_val:
        max_val = n
    if n < min_val:
        min_val = n
print(f"Max: {max_val}, Min: {min_val}")
```

### Q2. 統計一段客戶反饋文字中每個單詞出現的頻率（Word Frequency Counter）。
```python
feedback = "the server is fast and the cloud service is great and fast"
words = feedback.lower().split()
freq = {}
for w in words:
    freq[w] = freq.get(w, 0) + 1
print(freq)
# {'the': 2, 'server': 1, 'is': 2, 'fast': 2, 'and': 2, 'cloud': 1, 'service': 1, 'great': 1}
```

### Q3. 給定包含多個業務員業績的字典列表，請依據 `sales` 由高到低排序。
```python
reps = [
    {"name": "Alex", "sales": 550000},
    {"name": "Betty", "sales": 820000},
    {"name": "Charlie", "sales": 640000}
]
sorted_reps = sorted(reps, key=lambda x: x["sales"], reverse=True)
print(sorted_reps)
```

### Q4. 寫一個函式 `is_valid_taiwan_tax_id(tax_id: str) -> bool`，檢查輸入是否為 8 位純數字。
```python
def is_valid_taiwan_tax_id(tax_id: str) -> bool:
    return len(tax_id) == 8 and tax_id.isdigit()

print(is_valid_taiwan_tax_id("28491023")) # True
print(is_valid_taiwan_tax_id("284910A3")) # False
```

### Q5. 扁平化多層巢狀列表 (Flatten Nested List)。
```python
nested = [[1, 2, [3]], [4, [5, 6]], 7]

def flatten(lst):
    result = []
    for item in lst:
        if isinstance(item, list):
            result.extend(flatten(item))
        else:
            result.append(item)
    return result

print(flatten(nested)) # [1, 2, 3, 4, 5, 6, 7]
```

### Q6. 合併兩份客戶資料字典，若鍵相同則累加其消費額。
```python
dict_a = {"Apex": 500000, "BlueSky": 300000, "Cyber": 150000}
dict_b = {"Apex": 200000, "Cyber": 50000, "Delta": 400000}

merged = dict_a.copy()
for k, v in dict_b.items():
    merged[k] = merged.get(k, 0) + v
print(merged)
```

### Q7. 實作安全毛利率計算函式 `safe_calculate_margin(revenue, cost)`，當營收為 0 或輸入非數值時返回 None，並使用 `try-except` 優雅攔截例外。
```python
from typing import Optional

def safe_calculate_margin(revenue: float, cost: float) -> Optional[float]:
    """計算毛利率 (revenue - cost) / revenue，具備防禦性除零與型態檢查。"""
    try:
        rev = float(revenue)
        c = float(cost)
        if rev <= 0:
            print(f"[Warning] 營收必須大於 0 (傳入值: {revenue})")
            return None
        return round((rev - c) / rev, 4)
    except (ZeroDivisionError, ValueError, TypeError) as e:
        print(f"[Error] 計算異常攔截: {e}")
        return None

print(safe_calculate_margin(100000, 75000)) # 0.25
print(safe_calculate_margin(0, 50000))       # None (捕捉除以0或負數)
print(safe_calculate_margin("invalid", 20))  # None (捕捉型態轉換錯誤)
```

### Q8. 集合運算 (Set Operations)：比對 1 月與 2 月客戶名冊，找出「兩月皆有下單的留存客戶」與「2 月流失的客戶」。
```python
jan_clients = {"Apex Semi", "BlueSky", "CyberCore", "Delta Log", "Echo Energy"}
feb_clients = {"Apex Semi", "CyberCore", "Future AI", "Grand Precision"}

# 1. 兩月皆活躍客戶 (交集 Intersection)
retained_clients = jan_clients & feb_clients
print("留存客戶:", retained_clients) # {'Apex Semi', 'CyberCore'}

# 2. 1月有但2月未下單客戶 (差集 Difference)
churned_clients = jan_clients - feb_clients
print("流失客戶:", churned_clients) # {'BlueSky', 'Delta Log', 'Echo Energy'}
```

### Q9. 資料清洗實務：擷取混雜文字中的台灣統一編號純數字，若不足 8 位則標記無效。
```python
import re

def clean_tax_id(raw_tax_id: str) -> str:
    # 移除非數字的所有符號
    digits = re.sub(r"\D", "", str(raw_tax_id))
    return digits if len(digits) == 8 else "INVALID"

test_cases = ["統編: 2849-1023 (現役)", " 54329871 ", "TaxID: 12984", "None"]
cleaned = [clean_tax_id(tc) for tc in test_cases]
print(cleaned) # ['28491023', '54329871', 'INVALID', 'INVALID']
```

### Q10. 巢狀字典防呆安全取值 (Safe Deep Get)。
```python
from typing import Any, List

def deep_get(data: dict, keys: List[str], default: Any = None) -> Any:
    """依照層級鍵依序安全取值，任一層為 None 或不存在時回傳 default，不拋出 KeyError。"""
    current = data
    for k in keys:
        if isinstance(current, dict):
            current = current.get(k)
        else:
            return default
    return current if current is not None else default

sample_customer = {
    "company": "Apex Semi Tech",
    "contact": {
        "primary": {"name": "David", "email": "david@apex.com"}
    }
}

print(deep_get(sample_customer, ["contact", "primary", "email"])) # david@apex.com
print(deep_get(sample_customer, ["contact", "billing", "phone"], "未填寫")) # 未填寫
```

### Q11. 清單推導式 (List Comprehension)：批次格式化訂單號碼序列。
```python
# 產生 ORD-2024-001 至 ORD-2024-010 的流水號序列
order_numbers = [f"ORD-2024-{i:03d}" for i in range(1, 11)]
print(order_numbers[:5]) # ['ORD-2024-001', 'ORD-2024-002', 'ORD-2024-003', 'ORD-2024-004', 'ORD-2024-005']
```

### Q12. 模擬 SQL CASE WHEN：依訂單金額自動標註客戶等級。
```python
orders = [
    {"order_id": 1, "amount": 450000},
    {"order_id": 2, "amount": 180000},
    {"order_id": 3, "amount": 60000}
]

def get_tier(amount: float) -> str:
    if amount >= 300000:
        return "Tier 1 (Enterprise)"
    elif amount >= 100000:
        return "Tier 2 (Mid-Market)"
    return "Tier 3 (SMB)"

for o in orders:
    o["order_tier"] = get_tier(o["amount"])

print(orders)
```

### Q13. 檔案路徑與副檔名過濾（使用 `os.path`）。
```python
import os

files = ["sales_2024_01.csv", "summary.xlsx", "report.pdf", "customers_clean.csv", "backup.zip"]

# 篩選所有 CSV 檔案並提取不含副檔名的主檔名
csv_basenames = [os.path.splitext(f)[0] for f in files if f.endswith(".csv")]
print(csv_basenames) # ['sales_2024_01', 'customers_clean']
```

### Q14. 純 Python 計算數列的中位數 (Median)（不依賴 numpy / pandas）。
```python
def calculate_median(values: list) -> float:
    if not values:
        raise ValueError("數列不可為空")
    sorted_v = sorted(values)
    n = len(sorted_v)
    mid = n // 2
    if n % 2 == 1:
        return float(sorted_v[mid])
    else:
        return (sorted_v[mid - 1] + sorted_v[mid]) / 2.0

print(calculate_median([10, 20, 30, 40, 50]))      # 30.0 (奇數長度)
print(calculate_median([10, 20, 30, 40, 50, 60]))  # 35.0 (偶數長度取平均)
```

### Q15. 字典分組聚合 (Group By In Python)：依業務員 ID 加總業績與計數。
```python
raw_orders = [
    {"salesperson_id": 1, "amount": 360000},
    {"salesperson_id": 2, "amount": 155000},
    {"salesperson_id": 1, "amount": 450000},
    {"salesperson_id": 3, "amount": 240000},
    {"salesperson_id": 2, "amount": 80000}
]

summary = {}
for ord in raw_orders:
    sp_id = ord["salesperson_id"]
    if sp_id not in summary:
        summary[sp_id] = {"count": 0, "total_revenue": 0}
    summary[sp_id]["count"] += 1
    summary[sp_id]["total_revenue"] += ord["amount"]

print(summary)
# {1: {'count': 2, 'total_revenue': 810000}, 2: {'count': 2, 'total_revenue': 235000}, 3: {'count': 1, 'total_revenue': 240000}}
```
