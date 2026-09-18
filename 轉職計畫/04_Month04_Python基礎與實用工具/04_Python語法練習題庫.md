# 04 Python 核心語法與演算法練習題庫（15 題實戰自測）

> **📌 本題庫定位**：本題庫涵蓋資料工程師在日常工作與技術白板面試中最常被抽考的 15 個核心場景（字典聚合、排序、例外防禦、正則清洗、集合運算等）。
>
> **⚠️ 學習痛點與防呆要求**：
> - **切勿直接看解答**：看懂代碼不等於自己寫得出來！請在本地建立 `practice.py`，先自己獨立撰寫並執行驗證。
> - **兩層遮蔽原則**：卡關時，先點開「🔍 思維引導」獲取演算法解題提示；只有在親自寫出可跑版本或徹底卡死時，才展開「🔑 參考擬答代碼」。

---

### Q1. 找出數列中的極值（不用內建函式）
**情境**：給定一個整數列表 `nums = [12, 45, 78, 23, 56, 89, 90]`，請在不使用 `max()` / `min()` 內建函數的情況下，找出其中的最大值與最小值。

<details>
<summary>🔍 點擊展開「思維引導」</summary>

- 將第一個元素假定為初始的 `max_val` 與 `min_val`。
- 使用 `for` 迴圈從第二個元素開始線性遍歷，若發現更大/更小的值則動態覆蓋。
</details>

<details>
<summary>🔑 點擊展開「參考擬答代碼」</summary>

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
</details>

---

### Q2. 客戶反饋文字詞頻統計（Word Frequency Counter）
**情境**：統計一段客戶文字中每個單詞出現的頻率，請統一轉為小寫並用字典回傳結果。
文字：`"the server is fast and the cloud service is great and fast"`

<details>
<summary>🔍 點擊展開「思維引導」</summary>

- 使用 `.lower()` 消除大小寫差異，再用 `.split()` 依空格切分為單詞列表。
- 使用字典搭配 `.get(key, 0) + 1` 累加計數。
</details>

<details>
<summary>🔑 點擊展開「參考擬答代碼」</summary>

```python
feedback = "the server is fast and the cloud service is great and fast"
words = feedback.lower().split()
freq = {}
for w in words:
    freq[w] = freq.get(w, 0) + 1
print(freq)
# {'the': 2, 'server': 1, 'is': 2, 'fast': 2, 'and': 2, 'cloud': 1, 'service': 1, 'great': 1}
```
</details>

---

### Q3. 字典列表自訂排序（Custom Key Sorting）
**情境**：給定包含多個業務員業績的字典列表，請依據 `sales` 數值由高到低降冪排序。

```python
reps = [
    {"name": "Alex", "sales": 550000},
    {"name": "Betty", "sales": 820000},
    {"name": "Charlie", "sales": 640000}
]
```

<details>
<summary>🔍 點擊展開「思維引導」</summary>

- 使用 Python 內建的 `sorted()` 函式。
- 傳入關鍵字參數 `key=lambda x: x["sales"]` 與 `reverse=True`。
</details>

<details>
<summary>🔑 點擊展開「參考擬答代碼」</summary>

```python
sorted_reps = sorted(reps, key=lambda x: x["sales"], reverse=True)
print(sorted_reps)
```
</details>

---

### Q4. 台灣統一編號格式驗證函式
**情境**：寫一個函式 `is_valid_taiwan_tax_id(tax_id: str) -> bool`，檢查輸入是否剛好為 8 位純數字。

<details>
<summary>🔍 點擊展開「思維引導」</summary>

- 檢查字串長度是否為 8：`len(tax_id) == 8`。
- 檢查字元是否全為數字：`tax_id.isdigit()`。
</details>

<details>
<summary>🔑 點擊展開「參考擬答代碼」</summary>

```python
def is_valid_taiwan_tax_id(tax_id: str) -> bool:
    return len(tax_id) == 8 and tax_id.isdigit()

print(is_valid_taiwan_tax_id("28491023")) # True
print(is_valid_taiwan_tax_id("284910A3")) # False
```
</details>

---

### Q5. 扁平化多層巢狀列表 (Flatten Nested List)
**情境**：將任意深度的巢狀列表展平成單層一維清單。
輸入：`nested = [[1, 2, [3]], [4, [5, 6]], 7]`

<details>
<summary>🔍 點擊展開「思維引導」</summary>

- 典型的遞迴（Recursion）經典考題。
- 遍歷元素，若 `isinstance(item, list)` 則遞迴調用 `flatten(item)` 並使用 `extend` 合併；否則直接 `append`。
</details>

<details>
<summary>🔑 點擊展開「參考擬答代碼」</summary>

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
</details>

---

### Q6. 字典鍵值合併與累加
**情境**：合併兩份客戶消費額字典，若鍵相同則將其金額相加。

```python
dict_a = {"Apex": 500000, "BlueSky": 300000, "Cyber": 150000}
dict_b = {"Apex": 200000, "Cyber": 50000, "Delta": 400000}
```

<details>
<summary>🔍 點擊展開「思維引導」</summary>

- 先淺拷貝一份 `dict_a.copy()` 作為基底。
- 遍歷 `dict_b` 的 key-value，使用 `.get(k, 0) + v` 累加至合併字典。
</details>

<details>
<summary>🔑 點擊展開「參考擬答代碼」</summary>

```python
merged = dict_a.copy()
for k, v in dict_b.items():
    merged[k] = merged.get(k, 0) + v
print(merged)
# {'Apex': 700000, 'BlueSky': 300000, 'Cyber': 200000, 'Delta': 400000}
```
</details>

---

### Q7. 防禦性毛利率計算函式（例外攔截）
**情境**：實作安全毛利率計算函式 `safe_calculate_margin(revenue, cost)`，當營收為 0、小於 0 或傳入非數值字串時回傳 `None`，並以 `try-except` 優雅攔截所有異常。

<details>
<summary>🔍 點擊展開「思維引導」</summary>

- 在 `try` 區塊中將輸入轉為 float。
- 若營收 `<= 0` 主動返回 `None` 避免除以零邏輯。
- 捕捉 `(ZeroDivisionError, ValueError, TypeError)` 等例外。
</details>

<details>
<summary>🔑 點擊展開「參考擬答代碼」</summary>

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
print(safe_calculate_margin(0, 50000))       # None
print(safe_calculate_margin("invalid", 20))  # None
```
</details>

---

### Q8. 集合運算 (Set Operations)：客戶留存與流失分析
**情境**：比對 1 月與 2 月客戶名冊，找出「兩月皆有下單的留存客戶」與「2 月流失的客戶（1月有但2月無）」。

```python
jan_clients = {"Apex Semi", "BlueSky", "CyberCore", "Delta Log", "Echo Energy"}
feb_clients = {"Apex Semi", "CyberCore", "Future AI", "Grand Precision"}
```

<details>
<summary>🔍 點擊展開「思維引導」</summary>

- 留存客戶（交集）：使用集合運算子 `&`。
- 流失客戶（差集）：使用集合運算子 `-`。
</details>

<details>
<summary>🔑 點擊展開「參考擬答代碼」</summary>

```python
# 1. 兩月皆活躍客戶 (交集 Intersection)
retained_clients = jan_clients & feb_clients
print("留存客戶:", retained_clients) # {'Apex Semi', 'CyberCore'}

# 2. 1月有但2月未下單客戶 (差集 Difference)
churned_clients = jan_clients - feb_clients
print("流失客戶:", churned_clients) # {'BlueSky', 'Delta Log', 'Echo Energy'}
```
</details>

---

### Q9. 資料清洗：擷取混雜文字中的 8 位純數字統編
**情境**：從含有特殊符號或備註的字串中，抽取乾淨的 8 位數字統編，長度不符者標記為 `"INVALID"`。
測試案例：`["統編: 2849-1023 (現役)", " 54329871 ", "TaxID: 12984", "None"]`

<details>
<summary>🔍 點擊展開「思維引導」</summary>

- 使用標準庫 `re` 模組，呼叫 `re.sub(r"\D", "", raw_str)` 將非數字字元全部替換為空字串。
- 檢查清理後的數字長度是否等於 8。
</details>

<details>
<summary>🔑 點擊展開「參考擬答代碼」</summary>

```python
import re

def clean_tax_id(raw_tax_id: str) -> str:
    digits = re.sub(r"\D", "", str(raw_tax_id))
    return digits if len(digits) == 8 else "INVALID"

test_cases = ["統編: 2849-1023 (現役)", " 54329871 ", "TaxID: 12984", "None"]
cleaned = [clean_tax_id(tc) for tc in test_cases]
print(cleaned) # ['28491023', '54329871', 'INVALID', 'INVALID']
```
</details>

---

### Q10. 巢狀字典防呆安全取值 (Safe Deep Get)
**情境**：爬蟲或 API 回傳的 JSON 經常層層巢狀，若中間某個 key 不存在，直接用 `data["a"]["b"]` 會拋出 `KeyError` 或 `TypeError`。請寫一個函式安全取值。

<details>
<summary>🔍 點擊展開「思維引導」</summary>

- 接收 key 列表，依序向內查找。
- 每一層判斷當前變數是否為 dict，若不是則直接回傳預設值 `default`。
</details>

<details>
<summary>🔑 點擊展開「參考擬答代碼」</summary>

```python
from typing import Any, List

def deep_get(data: dict, keys: List[str], default: Any = None) -> Any:
    """依照層級鍵依序安全取值，任一層不存在時回傳 default，不拋出 KeyError。"""
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
</details>

---

### Q11. 清單推導式 (List Comprehension)：格式化流水號序列
**情境**：產生 `ORD-2024-001` 至 `ORD-2024-010` 的標準訂單號碼序列。

<details>
<summary>🔍 點擊展開「思維引導」</summary>

- 使用 f-string 的格式化控制符 `{i:03d}` 補零。
</details>

<details>
<summary>🔑 點擊展開「參考擬答代碼」</summary>

```python
order_numbers = [f"ORD-2024-{i:03d}" for i in range(1, 11)]
print(order_numbers[:5]) # ['ORD-2024-001', 'ORD-2024-002', 'ORD-2024-003', 'ORD-2024-004', 'ORD-2024-005']
```
</details>

---

### Q12. 模擬 SQL CASE WHEN：依金額劃分客戶等級
**情境**：若金額 >= 30 萬為 `Tier 1 (Enterprise)`，>= 10 萬為 `Tier 2 (Mid-Market)`，其餘為 `Tier 3 (SMB)`。

<details>
<summary>🔍 點擊展開「思維引導」</summary>

- 封裝條件判斷函式，並遍歷訂單列表動態新增鍵值。
</details>

<details>
<summary>🔑 點擊展開「參考擬答代碼」</summary>

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
</details>

---

### Q13. 檔案路徑與副檔名過濾
**情境**：給定檔案清單 `files = ["sales_2024_01.csv", "summary.xlsx", "report.pdf", "customers_clean.csv", "backup.zip"]`，請篩選出所有的 CSV 檔案，並提取不含副檔名的乾淨主檔名。

<details>
<summary>🔍 點擊展開「思維引導」</summary>

- 使用 `os.path.splitext()` 或字串 `.endswith(".csv")`。
</details>

<details>
<summary>🔑 點擊展開「參考擬答代碼」</summary>

```python
import os

files = ["sales_2024_01.csv", "summary.xlsx", "report.pdf", "customers_clean.csv", "backup.zip"]
csv_basenames = [os.path.splitext(f)[0] for f in files if f.endswith(".csv")]
print(csv_basenames) # ['sales_2024_01', 'customers_clean']
```
</details>

---

### Q14. 純 Python 計算數列的中位數 (Median)
**情境**：在不依賴 numpy / pandas 的情況下，計算給定數列的中位數（需考慮奇數與偶數長度）。

<details>
<summary>🔍 點擊展開「思維引導」</summary>

- 先使用 `sorted()` 排序數列。
- 奇數個取中央元素 `mid = n // 2`；偶數個取中央兩個元素的平均值。
</details>

<details>
<summary>🔑 點擊展開「參考擬答代碼」</summary>

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

print(calculate_median([10, 20, 30, 40, 50]))      # 30.0
print(calculate_median([10, 20, 30, 40, 50, 60]))  # 35.0
```
</details>

---

### Q15. 字典分組聚合 (Group By In Python)
**情境**：將原始訂單列表依 `salesperson_id` 分組，加總各業務員的訂單數與總銷售額。

```python
raw_orders = [
    {"salesperson_id": 1, "amount": 360000},
    {"salesperson_id": 2, "amount": 155000},
    {"salesperson_id": 1, "amount": 450000},
    {"salesperson_id": 3, "amount": 240000},
    {"salesperson_id": 2, "amount": 80000}
]
```

<details>
<summary>🔍 點擊展開「思維引導」</summary>

- 建立空字典 `summary = {}`，遍歷若 key 不存在則初始化 `{count: 0, total_revenue: 0}`，接著累加。
</details>

<details>
<summary>🔑 點擊展開「參考擬答代碼」</summary>

```python
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
</details>

---

## 🎯 題庫收斂總結
> **💡 核心口訣**：
> 「字典聚合先看鍵，推導簡潔避深陷；例外防禦加型別，生產代碼零風險。」
