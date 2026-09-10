# 01 Python 環境、語法與資料結構全攻略

> **寫在前面：Python 是資料工程師的瑞士刀**
> SQL 讓你能查詢資料，Python 讓你能**自動化**所有事情：
> - 每天早上自動抓最新數據、清洗、存到資料庫
> - 串接 API、處理 JSON、發送 Email 告警
> - 寫出讓同事可以使用的小工具和報表腳本
>
> 本篇從零建立 Python 環境，完整覆蓋你在資料工程工作中每天會用到的語法與資料結構。

---

## 🗺️ 本篇學習地圖

```
環境建立
  ├── Python 安裝與版本管理
  ├── venv 虛擬環境
  └── pip 套件管理

核心語法
  ├── 變數、型別、型別轉換
  ├── 條件判斷 if/elif/else
  ├── 迴圈 for/while
  └── f-string 格式化

資料結構（最重要！）
  ├── List（清單）
  ├── Dict（字典）
  ├── Set（集合）
  ├── Tuple（元組）
  └── 各結構的效能比較

推導式（Comprehension）
  ├── List Comprehension
  ├── Dict Comprehension
  └── Set Comprehension

dataclasses 簡介
```

---

## 一、環境建立

### 1.1 Python 安裝

```bash
# 到 python.org 下載 3.11 或 3.12（推薦）
# Windows 安裝時記得勾選「Add Python to PATH」

# 確認安裝成功
python --version      # Python 3.12.x
python -m pip --version  # pip 版本
```

### 1.2 venv 虛擬環境（每個專案必備）

虛擬環境讓每個專案有自己獨立的套件版本，避免「A 專案需要 pandas 1.5，B 專案需要 pandas 2.0」的版本衝突。

```bash
# 建立虛擬環境（在專案資料夾內執行）
python -m venv venv

# 啟動虛擬環境
# Windows:
.\venv\Scripts\activate
# macOS / Linux:
source venv/bin/activate

# 提示符號會變成 (venv) 代表已進入虛擬環境
(venv) $ python --version   # 這個 python 是 venv 內的

# 安裝套件（只安裝在這個 venv 內，不影響系統）
pip install pandas sqlalchemy psycopg2-binary python-dotenv

# 匯出目前安裝的套件清單（讓別人能重現你的環境）
pip freeze > requirements.txt

# 從 requirements.txt 安裝（拿到別人的專案時）
pip install -r requirements.txt

# 離開虛擬環境
deactivate
```

**標準的專案資料夾結構**：

```
my_project/
├── venv/               ← 虛擬環境（加入 .gitignore，不要 commit）
├── .env                ← 環境變數（帳密等敏感資訊，加入 .gitignore）
├── .gitignore
├── requirements.txt    ← 套件清單（要 commit）
├── README.md
├── main.py             ← 主程式
└── src/
    ├── __init__.py
    ├── db.py           ← 資料庫連線
    └── utils.py        ← 工具函式
```

`.gitignore` 最小範本：

```
venv/
.env
__pycache__/
*.pyc
.DS_Store
*.log
```

---

## 二、核心語法快速通

### 2.1 變數與型別

```python
# Python 是動態型別語言，不需要宣告型別
name    = "台灣科技股份有限公司"   # str（字串）
revenue = 1_234_567.89            # float（浮點數，底線只是視覺分隔）
orders  = 42                      # int（整數）
is_active = True                  # bool（布林）
nothing = None                    # NoneType（空值，類似 SQL 的 NULL）

# 型別檢查
type(name)        # <class 'str'>
isinstance(revenue, float)  # True

# 型別轉換
str(42)           # "42"
int("100")        # 100
float("3.14")     # 3.14
bool(0)           # False
bool("hello")     # True（非空字串都是 True）
bool("")          # False
bool(None)        # False
```

### 2.2 字串操作

```python
company = "  台灣半導體股份有限公司  "

# 常用字串方法
company.strip()             # 去除首尾空白："台灣半導體股份有限公司"
company.upper()             # 全大寫
company.lower()             # 全小寫
company.replace("有限", "股份有限")  # 取代
company.split("股份")       # 切割 → ["  台灣半導體", "有限公司  "]
"科技" in company           # True（包含判斷）
len(company.strip())        # 11（字元數）

# f-string（Python 3.6+ 的格式化利器）
name = "王小明"
revenue = 1234567.89
month = "2024-09"

print(f"業務：{name}，{month} 業績：NT${revenue:,.0f}")
# 輸出：業務：王小明，2024-09 業績：NT$1,234,568

# 多行字串
sql = """
    SELECT *
    FROM orders
    WHERE status = 'COMPLETED'
      AND order_date >= '2024-01-01'
"""
```

### 2.3 條件判斷

```python
revenue = 1_500_000
monthly_target = 1_000_000

# if / elif / else
if revenue >= monthly_target * 1.2:
    tier = "🏆 超標（>120%）"
elif revenue >= monthly_target:
    tier = "✅ 達標（100~120%）"
elif revenue >= monthly_target * 0.8:
    tier = "⚠️  接近達標（80~100%）"
else:
    tier = "❌ 未達標（<80%）"

print(f"業績等級：{tier}")

# 三元運算式（Ternary Expression）
status = "超標" if revenue > monthly_target else "未達標"

# 邏輯運算子：and / or / not
if revenue > 0 and status == 'ACTIVE':
    print("有效業務")

# None 的判斷（要用 is，不要用 ==）
if revenue is None:
    revenue = 0
if revenue is not None:
    print(f"業績：{revenue}")
```

### 2.4 迴圈

```python
# for 迴圈：遍歷序列
customers = ["台灣半導體", "智慧雲端", "全球資安"]

for customer in customers:
    print(f"處理客戶：{customer}")

# enumerate：同時取索引和值
for i, customer in enumerate(customers, start=1):
    print(f"{i}. {customer}")

# range：產生數字序列
for i in range(5):         # 0, 1, 2, 3, 4
    print(i)

for i in range(1, 11, 2): # 1, 3, 5, 7, 9（start, stop, step）
    print(i)

# while 迴圈：條件式
retry_count = 0
max_retries = 3

while retry_count < max_retries:
    try:
        # 嘗試連接資料庫
        result = connect_to_db()
        break  # 成功就跳出
    except Exception:
        retry_count += 1
        print(f"第 {retry_count} 次重試...")

# break：立即跳出迴圈
# continue：跳過本次，繼續下一次
for num in range(10):
    if num == 5:
        break      # 跳出：0 1 2 3 4
    if num % 2 == 0:
        continue   # 跳過偶數
    print(num)
```

---

## 三、資料結構深度解析

### 3.1 List（清單）— 最常用的序列結構

```python
# 建立
orders = [1001, 1002, 1003, 1004, 1005]
mixed  = [1, "hello", True, None, [1, 2]]  # 可以混合型別，但實務上避免

# 存取
orders[0]       # 1001（第一個，從 0 開始）
orders[-1]      # 1005（最後一個）
orders[1:3]     # [1002, 1003]（切片：從索引1到索引3，不包含3）
orders[:3]      # [1001, 1002, 1003]（前三個）
orders[2:]      # [1003, 1004, 1005]（從第三個到最後）

# 修改
orders.append(1006)        # 末尾加入
orders.insert(0, 1000)     # 在索引0插入
orders.extend([1007, 1008]) # 合併另一個 List
orders.remove(1003)         # 刪除第一個值為 1003 的元素
popped = orders.pop()       # 取出並刪除最後一個
popped = orders.pop(0)      # 取出並刪除索引0

# 查詢
len(orders)            # 長度
1002 in orders         # True（包含判斷）
orders.index(1004)     # 找到值 1004 的索引位置
orders.count(1001)     # 計算出現次數

# 排序
orders.sort()              # 原地排序（修改原始 List）
orders.sort(reverse=True)  # 倒序
sorted_orders = sorted(orders)  # 回傳新的 List，不修改原始
```

**List 的常見實務應用**：

```python
# 情境：從資料庫取回的訂單 ID 清單，批次處理
order_ids = [1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 1010]

# 每次處理 3 筆（分批處理大量資料）
batch_size = 3
for i in range(0, len(order_ids), batch_size):
    batch = order_ids[i:i + batch_size]
    print(f"處理批次：{batch}")
    # process_batch(batch)

# 去除重複的客戶 ID
customer_ids_with_dup = [1, 2, 1, 3, 2, 4]
unique_ids = list(set(customer_ids_with_dup))  # [1, 2, 3, 4]（順序不保證）
```

---

### 3.2 Dict（字典）— 最重要的資料結構

Dict 是 Python 資料處理的核心，幾乎所有的 JSON 資料和資料庫結果都會以 Dict 形式處理。

```python
# 建立
customer = {
    "customer_id": 5,
    "company_name": "台灣半導體股份有限公司",
    "industry": "Semiconductor",
    "city": "台北市",
    "credit_limit": 5_000_000,
    "status": "ACTIVE"
}

# 存取
customer["company_name"]            # "台灣半導體股份有限公司"
customer.get("phone")               # None（key 不存在時不報錯）
customer.get("phone", "未填寫")     # "未填寫"（提供預設值）

# 修改
customer["city"] = "高雄市"         # 修改已有的 key
customer["annual_revenue"] = 50_000_000  # 新增 key

# 刪除
del customer["annual_revenue"]      # 刪除 key
removed = customer.pop("city")      # 刪除並取得值

# 查詢
"company_name" in customer          # True（key 存在判斷）
"phone" in customer                 # False
customer.keys()                     # dict_keys([...])
customer.values()                   # dict_values([...])
customer.items()                    # dict_items([(key, value), ...])

# 遍歷
for key, value in customer.items():
    print(f"{key}: {value}")

# 合併兩個 Dict（Python 3.9+）
extra_info = {"email": "contact@tsmc.com", "phone": "02-3456-7890"}
customer_full = customer | extra_info  # 合併
customer.update(extra_info)            # 就地更新
```

**Dict 的實務應用**：

```python
# 情境 1：從資料庫查詢結果（列表of字典）聚合統計
orders = [
    {"salesperson": "王小明", "amount": 500000},
    {"salesperson": "李大華", "amount": 300000},
    {"salesperson": "王小明", "amount": 200000},
    {"salesperson": "張美玲", "amount": 800000},
]

# 按業務員彙總業績
sales_summary = {}
for order in orders:
    sp = order["salesperson"]
    if sp not in sales_summary:
        sales_summary[sp] = 0
    sales_summary[sp] += order["amount"]

print(sales_summary)
# {'王小明': 700000, '李大華': 300000, '張美玲': 800000}

# 更優雅的寫法：使用 defaultdict
from collections import defaultdict
sales_summary = defaultdict(int)  # 預設值為 0
for order in orders:
    sales_summary[order["salesperson"]] += order["amount"]

# 情境 2：Counter — 快速計數
from collections import Counter
industries = ["Semiconductor", "Software", "Semiconductor", "Hardware", "Software", "Software"]
count = Counter(industries)
print(count)  # Counter({'Software': 3, 'Semiconductor': 2, 'Hardware': 1})
print(count.most_common(2))  # [('Software', 3), ('Semiconductor', 2)]
```

---

### 3.3 Set（集合）— 快速去重與集合運算

```python
# 建立
active_customers = {1, 3, 5, 7, 9}
ordered_customers = {3, 5, 6, 7, 10}

# 集合運算（直接對應到 SQL 的集合運算）
active_customers | ordered_customers   # UNION：{1, 3, 5, 6, 7, 9, 10}
active_customers & ordered_customers   # INTERSECT：{3, 5, 7}
active_customers - ordered_customers   # EXCEPT（active 但沒下單）：{1, 9}
ordered_customers - active_customers   # （下單但非 active 客戶）：{6, 10}
active_customers ^ ordered_customers   # 對稱差（各自獨有）：{1, 6, 9, 10}

# 包含判斷（O(1) 時間複雜度，比 List 快得多）
5 in active_customers      # True（幾乎瞬間）
5 in [1, 3, 5, 7, 9]      # True（List 要逐一比對，O(N)）

# 修改
active_customers.add(11)       # 新增一個元素
active_customers.discard(11)   # 刪除（不存在時不報錯）
active_customers.remove(11)    # 刪除（不存在時報錯）

# 實務應用：快速找出「有訂單但不在客戶主檔」的異常 ID
db_customer_ids = {1, 2, 3, 4, 5, 6, 7}
order_customer_ids = {3, 5, 7, 99, 100}  # 99, 100 不在主檔！

orphan_ids = order_customer_ids - db_customer_ids
print(f"孤立的客戶 ID：{orphan_ids}")  # {99, 100}
```

---

### 3.4 Tuple（元組）— 不可變的序列

```python
# 建立（一旦建立，內容不可修改）
coordinates = (121.5, 25.0)      # 經度, 緯度
rgb = (255, 128, 0)
single = (42,)                   # 單元素 Tuple 需要逗號

# 解包（Unpacking）— 非常常用！
x, y = coordinates              # x = 121.5, y = 25.0
r, g, b = rgb

# 函數回傳多值（本質上就是 Tuple）
def get_revenue_stats(orders):
    amounts = [o["amount"] for o in orders]
    return min(amounts), max(amounts), sum(amounts) / len(amounts)

min_rev, max_rev, avg_rev = get_revenue_stats(orders)

# 用於 Dict 的 key（List 不能作為 key，因為 List 可變）
monthly_sales = {
    (2024, 1): 1_200_000,
    (2024, 2): 980_000,
    (2024, 3): 1_500_000,
}
print(monthly_sales[(2024, 2)])  # 980000
```

---

### 3.5 資料結構效能比較

```python
import timeit

# 包含判斷：List vs Set vs Dict
large_list = list(range(1_000_000))
large_set  = set(range(1_000_000))
large_dict = {i: True for i in range(1_000_000)}

# 測試 999999 in container
# List：O(N)，平均掃描 500,000 個元素
# Set：O(1)，雜湊直接定位
# Dict：O(1)，雜湊直接定位

# 結果大致如下（實際數字因硬體而異）：
# List: ~0.050 秒
# Set:  ~0.000002 秒（快 25000 倍！）
# Dict: ~0.000002 秒
```

**選擇指南**：

| 情況 | 選擇 | 原因 |
|------|------|------|
| 有序序列，需要索引存取 | `list` | 唯一選擇 |
| Key-Value 對應關係 | `dict` | 設計如此 |
| 快速包含判斷（`in`） | `set` | O(1) vs O(N) |
| 計數統計 | `Counter` | 比 dict 更方便 |
| 不可變的多值組合 | `tuple` | 可作為 dict key |
| 預設值的 dict | `defaultdict` | 避免 KeyError |

---

## 四、推導式（Comprehension）— Pythonic 的精華

推導式讓你用一行優雅的代碼取代 3-5 行的迴圈。

### 4.1 List Comprehension

```python
# 情境：從資料庫取回的原始資料，需要快速轉換
raw_revenues = [500000, -1000, 300000, 0, 800000, -500, 1200000]

# 傳統寫法（4行）
clean_revenues = []
for r in raw_revenues:
    if r > 0:
        clean_revenues.append(r)

# List Comprehension（1行）
clean_revenues = [r for r in raw_revenues if r > 0]
# [500000, 300000, 800000, 1200000]

# 帶轉換的推導式
revenues_in_millions = [r / 1_000_000 for r in clean_revenues]
# [0.5, 0.3, 0.8, 1.2]

# 巢狀推導式（製作月份×業務的組合清單）
months = ["Jan", "Feb", "Mar"]
salespeople = ["王小明", "李大華"]
combinations = [(month, sp) for month in months for sp in salespeople]
# [('Jan', '王小明'), ('Jan', '李大華'), ('Feb', '王小明'), ...]

# 條件推導式（三元）
order_labels = [
    "大訂單" if amount > 500_000 else "一般訂單"
    for amount in [200000, 600000, 150000, 800000]
]
# ['一般訂單', '大訂單', '一般訂單', '大訂單']
```

### 4.2 Dict Comprehension

```python
# 情境：從查詢結果建立 customer_id → company_name 的快速查詢表
customers_rows = [
    {"id": 1, "name": "台灣半導體", "revenue": 5_000_000},
    {"id": 2, "name": "智慧雲端",   "revenue": 2_000_000},
    {"id": 3, "name": "全球資安",   "revenue": 800_000},
]

# 建立 ID → Name 的映射
id_to_name = {row["id"]: row["name"] for row in customers_rows}
# {1: '台灣半導體', 2: '智慧雲端', 3: '全球資安'}

# 快速查詢（O(1)）
print(id_to_name[2])  # 智慧雲端

# 過濾 + 轉換：只保留高價值客戶，並轉換為百萬單位
high_value = {
    row["name"]: row["revenue"] / 1_000_000
    for row in customers_rows
    if row["revenue"] > 1_000_000
}
# {'台灣半導體': 5.0, '智慧雲端': 2.0}
```

### 4.3 Set Comprehension

```python
# 情境：從訂單清單中快速取出所有不重複的產業別
orders = [
    {"customer": "台積電", "industry": "Semiconductor"},
    {"customer": "威聯通", "industry": "Hardware"},
    {"customer": "仁寶電腦", "industry": "Hardware"},
    {"customer": "趨勢科技", "industry": "Software"},
]

unique_industries = {order["industry"] for order in orders}
# {'Semiconductor', 'Hardware', 'Software'}
```

---

## 五、dataclasses — 優雅地定義資料結構

`dataclasses` 是 Python 3.7+ 的內建模組，讓你定義「資料類別」時不需要寫大量的 `__init__` 樣板代碼。

```python
from dataclasses import dataclass, field
from typing import Optional
from datetime import date

# 定義一個代表「訂單」的資料類別
@dataclass
class Order:
    order_id:       int
    order_number:   str
    customer_id:    int
    order_date:     date
    status:         str = "PENDING"                  # 有預設值
    total_amount:   float = 0.0
    items:          list = field(default_factory=list)  # 可變預設值用 field
    notes:          Optional[str] = None

# 使用
order = Order(
    order_id=1,
    order_number="ORD-2024-001",
    customer_id=5,
    order_date=date(2024, 9, 15),
    total_amount=598_000.0
)

print(order.order_number)   # ORD-2024-001
print(order.status)         # PENDING（預設值）
print(order)
# Order(order_id=1, order_number='ORD-2024-001', ...)

# dataclass 自動提供：
# __init__：初始化
# __repr__：列印顯示
# __eq__：相等比較（按欄位值比較）

# 從資料庫結果建立 Order 物件（常見模式）
def row_to_order(row: dict) -> Order:
    return Order(
        order_id=row["order_id"],
        order_number=row["order_number"],
        customer_id=row["customer_id"],
        order_date=row["order_date"],
        status=row["status"],
        total_amount=float(row["total_amount"])
    )
```

---

## 六、常用內建函數速查

```python
# 數值計算
abs(-42)           # 42
round(3.14159, 2)  # 3.14
max([1, 5, 3])     # 5
min([1, 5, 3])     # 1
sum([1, 5, 3])     # 9
pow(2, 10)         # 1024

# 序列操作
len([1, 2, 3])     # 3
sorted([3, 1, 2])  # [1, 2, 3]
reversed([1, 2, 3])  # 回傳 iterator
list(zip([1, 2], ['a', 'b']))  # [(1, 'a'), (2, 'b')]
list(enumerate(['a', 'b'], start=1))  # [(1, 'a'), (2, 'b')]

# 型別判斷
isinstance(42, int)      # True
isinstance("hi", str)    # True
isinstance(None, type(None))  # True

# any / all（常用於資料驗證）
revenues = [100, 200, 0, 300]
any(r > 0 for r in revenues)   # True（至少一個 > 0）
all(r > 0 for r in revenues)   # False（不是全部 > 0）

# 驗證清單中所有訂單都是 COMPLETED
orders_status = ["COMPLETED", "COMPLETED", "CANCELLED"]
all_completed = all(s == "COMPLETED" for s in orders_status)  # False

# map / filter（函數式風格）
revenues = [100000, 200000, 50000, 800000]
doubled = list(map(lambda x: x * 2, revenues))    # 每個乘以 2
big    = list(filter(lambda x: x > 100000, revenues))  # 只保留 > 100000
```

---

## 七、練習題

### 題目 1：業績等級分類器

給定一個業務員業績清單（list of dict），輸出每位業務的業績等級。月目標為 100 萬。

```python
# 輸入資料
salespeople = [
    {"name": "王小明", "revenue": 1_500_000},
    {"name": "李大華", "revenue": 900_000},
    {"name": "張美玲", "revenue": 1_200_000},
    {"name": "陳建國", "revenue": 600_000},
]
monthly_target = 1_000_000

# 解答
def classify_performance(sp, target):
    r = sp["revenue"]
    if r >= target * 1.2:
        level = "🏆 超標"
    elif r >= target:
        level = "✅ 達標"
    elif r >= target * 0.8:
        level = "⚠️  接近達標"
    else:
        level = "❌ 未達標"
    return {**sp, "level": level}

results = [classify_performance(sp, monthly_target) for sp in salespeople]
for r in sorted(results, key=lambda x: x["revenue"], reverse=True):
    print(f"{r['name']:8} NT${r['revenue']:>12,} {r['level']}")
```

---

### 題目 2：字典合併與統計

給定多個月份的業績字典（各月份的業務:金額），計算每位業務的年度累計業績。

```python
# 輸入
monthly_data = [
    {"王小明": 500_000, "李大華": 300_000},
    {"王小明": 600_000, "張美玲": 800_000},
    {"李大華": 450_000, "張美玲": 700_000, "王小明": 550_000},
]

# 解答
from collections import defaultdict
annual = defaultdict(int)
for month in monthly_data:
    for sp, rev in month.items():
        annual[sp] += rev

# 用 Dict Comprehension 轉為百萬單位並排序
annual_millions = {k: v/1_000_000 for k, v in sorted(annual.items(), key=lambda x: x[1], reverse=True)}
print(annual_millions)
# {'王小明': 1.65, '張美玲': 1.5, '李大華': 0.75}
```

---

### 題目 3：資料清理流水線

給定一個含有髒資料的客戶清單，用 List Comprehension 和 Dict Comprehension 進行清洗。

```python
raw_customers = [
    {"id": 1, "name": "  台灣半導體  ", "revenue": "5000000", "status": "active"},
    {"id": 2, "name": "智慧雲端",      "revenue": "-1000",   "status": "INACTIVE"},
    {"id": 3, "name": "  全球資安  ",  "revenue": "800000",  "status": "ACTIVE"},
    {"id": 4, "name": "",              "revenue": "300000",  "status": "active"},
]

# 解答
def clean_customer(c):
    return {
        "id":      c["id"],
        "name":    c["name"].strip(),
        "revenue": max(0, int(c["revenue"])),   # 負值改為 0
        "status":  c["status"].upper()
    }

cleaned = [
    clean_customer(c)
    for c in raw_customers
    if c["name"].strip()  # 過濾空名稱
]
print(cleaned)
```

---

## 八、本章重點彙整

```
虛擬環境
  python -m venv venv → .\venv\Scripts\activate → pip install
  pip freeze > requirements.txt（提交到 Git）

資料結構選擇
  list → 有序、可重複，索引存取
  dict → key-value，快速查詢 O(1)
  set  → 去重、包含判斷 O(1)、集合運算
  tuple → 不可變、多值回傳、dict key

推導式（優先使用，比迴圈更 Pythonic）
  [expr for item in iter if cond]      → List
  {k: v for item in iter if cond}      → Dict
  {expr for item in iter if cond}      → Set

常用函數
  sorted(list, key=lambda, reverse=True) → 排序
  enumerate(list, start=1)              → 帶索引遍歷
  zip(list1, list2)                     → 並行遍歷
  any() / all()                         → 布林聚合
  defaultdict(int/list)                 → 預設值字典
  Counter(list)                         → 計數
```

---

*下一篇：[02 函式、模組與例外處理除錯實務](./02_函式_模組與例外處理除錯實務.md)*
