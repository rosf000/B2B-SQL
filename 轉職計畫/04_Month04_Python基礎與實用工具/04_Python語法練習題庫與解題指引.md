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

### Q7. 實作安全除法裝飾器 (Decorator)，當除以 0 或輸入非數值時返回 None 並記錄警告。
```python
def safe_calc(func):
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except ZeroDivisionError:
            print("[Warning] 除數為 0，已安全攔截")
            return None
        except Exception as e:
            print(f"[Error] 計算異常: {e}")
            return None
    return wrapper

@safe_calc
def calculate_margin(revenue, cost):
    return (revenue - cost) / revenue

print(calculate_margin(100, 80)) # 0.2
print(calculate_margin(0, 0))    # None (捕捉除以0)
```
