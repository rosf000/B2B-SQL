# 02. REST API 原理與 Python Requests 企業實戰

> **📌 本章定位**：現代資料工程鮮少只面對單一本機資料庫，絕大多數業務數據來自跨組織的 **HTTP / RESTful API**。本篇的核心心智模型是：**「把網路通訊視為隨時會斷線、超時與限流的不可靠環境」**，學會以 Session 連線複用、指數退避重試與 HMAC 數位簽章建立企業級 API 整合客戶端。
>
> **⚠️ 痛點場景（生產環境三大 API 慘案）**：
> 1. **未設 Timeout 導致整個服務凍結**：呼叫第三方金流 API 時寫 `requests.get(url)` 沒設 timeout，對方伺服器當機不回傳，Python 執行緒無上限永久掛死，Web 伺服器 Worker 全數耗盡。
> 2. **遭遇 429 瘋狂重試被封鎖 IP**：觸發第三方 API 限流（Rate Limit）時，使用無延遲 while 迴圈硬打，直接被對方的 Cloudflare 判定為 DDoS 攻擊並永久拉黑 IP，導致整條業務線癱瘓。
> 3. **每次請求重新握手慢如牛步**：在迴圈內反覆呼叫 `requests.get()`，每一筆都要重新經歷 DNS 解析與 TCP 三次交握，1,000 次請求耗時 50 秒（改用 `requests.Session()` 僅需 4 秒）。
>
> **💡 學習策略**：先定位（HTTP 動詞與狀態碼語意）➔ 再理解（Session 複用、指數退避與 Cursor 分頁）➔ 再操作（手寫帶快取與 HMAC 簽章的 API 客戶端）➔ 再回收（高可用 API 串接檢核清單）。

---

## 目錄
1. [RESTful API 核心架構與 HTTP 協定](#1-restful-api-核心架構與-http-協定)
   - [1.1 資源導向架構與 HTTP 語意規範](#11-資源導向架構與-http-語意規範)
   - [1.2 HTTP 方法的安全性與冪等性（Idempotence）](#12-http-方法的安全性與冪等性idempotence)
   - [1.3 HTTP 狀態碼全解讀：從 200 到 504 的商業意義](#13-http-狀態碼全解讀從-200-到-504-的商業意義)
2. [Python Requests 企業級操作規範](#2-python-requests-企業級操作規範)
   - [2.1 GET 與 POST：Params vs JSON Body 的根本差異](#21-get-與-postparams-vs-json-body-的根本差異)
   - [2.2 權杖身份驗證：Bearer Token 與 API Key Header](#22-權杖身份驗證bearer-token-與-api-key-header)
   - [2.3 必守底線：Timeout 超時設定與連線掛死防禦](#23-必守底線timeout-超時設定與連線掛死防禦)
3. [工業級高可用 API 串接架構](#3-工業級高可用-api-串接架構)
   - [3.1 Session 物件與 TCP 連線複用](#31-session-物件與-tcp-連線複用)
   - [3.2 自動重試機制：指數退避（Exponential Backoff）實踐](#32-自動重試機制指數退避exponential-backoff實踐)
   - [3.3 遭遇 429 Too Many Requests 時的限流防護](#33-遭遇-429-too-many-requests-時的限流防護)
   - [3.4 API 分頁擷取策略：Offset vs Cursor-based](#34-api-分頁擷取策略offset-vs-cursor-based)
4. [JSON 資料工程：pd.json_normalize 展平入庫](#4-json-資料工程pdjson_normalize-展平入庫)
5. [企業資安最佳實踐：憑證金鑰管理](#5-企業資安最佳實踐憑證金鑰管理)
6. [商業情境綜合練習題（含詳解）](#6-商業情境綜合練習題含詳解)

---

## 1. RESTful API 核心架構與 HTTP 協定

在現代企業微服務架構與跨組織協作中，系統之間通常透過 RESTful API 交換資訊。

### 1.1 資源導向架構與 HTTP 語意規範

REST（Representational State Transfer，具象狀態傳輸）將所有操作對象視為**名詞（資源）**，並使用 HTTP 動詞定義對資源的行為：

| HTTP 動詞 | 資源 URI 範例 | 業務語意 | 說明 |
| :--- | :--- | :--- | :--- |
| **GET** | `/api/v1/customers` | 取得客戶列表 | 讀取操作，不改變伺服器狀態 |
| **GET** | `/api/v1/customers/CUST_001` | 取得特定客戶詳情 | 讀取單筆資源 |
| **POST** | `/api/v1/customers` | 新增一位客戶 | 建立新資源，由伺服器生成識別碼 |
| **PUT** | `/api/v1/customers/CUST_001` | 完整替換客戶資料 | 提供完整的實體屬性覆蓋舊內容 |
| **PATCH** | `/api/v1/customers/CUST_001` | 部分更新客戶資料 | 僅修改部分欄位（如只改電話或信用額度） |
| **DELETE** | `/api/v1/customers/CUST_001` | 刪除客戶 | 標記刪除或物理移除資源 |

---

### 1.2 HTTP 方法的安全性與冪等性（Idempotence）

這是架構師與資深工程師最重視的觀念：

```
+-----------+------------+------------+-------------------------------------+
| HTTP Method| Safe (安全) | Idempotent | 業務含義                             |
|           | (只讀無害)  | (重跑無副作用)|                                     |
+-----------+------------+------------+-------------------------------------+
|   GET     |    YES     |    YES     | 查 1 次跟查 10 次，資料庫皆不變      |
|   HEAD    |    YES     |    YES     | 僅取得 Header，不傳輸 Body          |
|   PUT     |    NO      |    YES     | 覆蓋更新：重複執行 N 次結果完全一致   |
|  DELETE   |    NO      |    YES     | 刪除資源：第二次刪除依然處於已刪除狀態|
|   POST    |    NO      |     NO     | 每次執行都會產生新的訂單/資料！       |
|  PATCH    |    NO      |   DEPENDS  | 端看修改邏輯（若累加餘額則非冪等）    |
+-----------+------------+------------+-------------------------------------+
```

---

### 1.3 HTTP 狀態碼全解讀：從 200 到 504 的商業意義

- **`2xx Success`（成功）**：
  - `200 OK`：標準成功回應（GET/PUT）。
  - `201 Created`：資源建立成功（POST 最常見），通常 Header 會附帶 `Location`。
  - `204 No Content`：成功處理但無須返回內容（DELETE 常見）。
- **`3xx Redirection`（重定向）**：
  - `301 Moved Permanently`：資源永久搬遷。
  - `304 Not Modified`：快取生效，伺服器資源無變動。
- **`4xx Client Error`（客戶端錯誤 - 我們的責任）**：
  - `400 Bad Request`：JSON 格式錯誤或欄位型別校驗失敗。
  - `401 Unauthorized`：**未登入 / 缺少有效憑證（Token 過期或未帶）**。
  - `403 Forbidden`：**已驗證身份但「沒有權限」執行該操作**。
  - `404 Not Found`：資源不存在或 URI 打錯。
  - `422 Unprocessable Entity`：語法正確但商業邏輯衝突（如：扣款金額大於餘額）。
  - `429 Too Many Requests`：**超出 API 呼叫頻率限制（Rate Limit Exceeded）**。
- **`5xx Server Error`（伺服器端錯誤 - 對方伺服器掛了）**：
  - `500 Internal Server Error`：對方伺服器程式碼崩潰噴 Exception。
  - `502 Bad Gateway` / `503 Service Unavailable`：對方服務過載或重啟中。
  - `504 Gateway Timeout`：對方後端處理超過反向代理（Nginx/Cloudflare）的等待上限。

---

## 2. Python Requests 企業級操作規範

### 2.1 GET 與 POST：Params vs JSON Body 的根本差異

```python
import requests

BASE_URL = "https://api.b2b-gateway.example.com/v1"

# 1. GET 請求：參數放在 URL Query String 中（使用 params 參數）
query_params = {
    "status": "APPROVED",
    "min_amount": 100000,
    "limit": 20
}
# requests 會自動將其編碼為: https://...?status=APPROVED&min_amount=100000&limit=20
response_get = requests.get(f"{BASE_URL}/orders", params=query_params, timeout=5)

# 2. POST 請求：資料序列化為 JSON 放在 Request Body（使用 json 參數）
new_order_payload = {
    "customer_id": "CUST_001",
    "salesperson_id": "EMP_008",
    "items": [
        {"product_id": "PROD_CHIP_X1", "quantity": 50, "unit_price": 1200.0}
    ]
}
# 使用 json= 會自動帶上 Header: 'Content-Type': 'application/json'
response_post = requests.post(f"{BASE_URL}/orders", json=new_order_payload, timeout=10)
```

---

### 2.2 權杖身份驗證：Bearer Token 與 API Key Header

企業級 API 幾乎不會使用明文帳號密碼，最常見的是 **JWT Bearer Token** 或 **X-API-Key Header**：

```python
API_SECRET_TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

headers = {
    "Authorization": f"Bearer {API_SECRET_TOKEN}",
    "X-Client-Version": "2.4.0",
    "Accept": "application/json"
}

resp = requests.get(f"{BASE_URL}/customers/CUST_001", headers=headers, timeout=5)

# 立即校驗狀態碼：若為 4xx 或 5xx 會直接拋出 requests.exceptions.HTTPError
resp.raise_for_status()
customer_data = resp.json()
print("客戶名稱:", customer_data["company_name"])
```

---

### 2.3 必守底線：Timeout 超時設定與連線掛死防禦

**死穴警訊**：如果不設 `timeout`，預設為 `timeout=None`。當第三方伺服器網路壅塞或防火牆默默 Drop 封包時，你的 Python 程式會**永久掛在該行程式碼上，直到宇宙盡頭都不會超時退出**！

```python
# 正確寫法：永遠指定 timeout（可傳入數值或 tuple: (連線超時, 讀取超時)）
try:
    resp = requests.get(
        f"{BASE_URL}/health",
        timeout=(3.05, 10.0) # 3.05 秒內需建立 TCP 連線，10 秒內需收到伺服器回應
    )
except requests.exceptions.ConnectTimeout:
    print("連線建立逾時，對方伺服器可能當機或網路中斷！")
except requests.exceptions.ReadTimeout:
    print("已連上伺服器，但對方資料庫處理過慢，回應逾時！")
```

---

## 3. 工業級高可用 API 串接架構

### 3.1 Session 物件與 TCP 連線複用

如果一個迴圈要連續呼叫外部 API 100 次，若每次都用 `requests.get()`，會重複進行 100 次完整的 TCP 三向交握（Three-way Handshake）與 TLS/SSL 握手，網路延遲至少增加 10 倍！

使用 `requests.Session()` 可以維持底層連線池，自動複用（Keep-Alive）已建立的連線，大幅提升吞吐量。

---

### 3.2 自動重試機制：指數退避（Exponential Backoff）實踐

第三方服務常有瞬間網路抖動或短暫 503 錯誤。如果遇到就立即中斷，系統穩定度會極差。
業界標準做法是利用 `urllib3.util.retry.Retry` 配合 `Session`，實作「**指數退避自動重試**」（例如出錯後等待 1 秒、2 秒、4 秒後重試）：

```python
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

def create_resilient_session(
    retries: int = 3,
    backoff_factor: float = 0.5,
    status_forcelist: tuple = (500, 502, 503, 504, 429)
) -> requests.Session:
    """
    建立具備連線池複用、自動重試與指數退避的高可用 Session
    """
    session = requests.Session()
    
    retry_strategy = Retry(
        total=retries,                                 # 最大重試次數
        backoff_factor=backoff_factor,                 # 退避因子: 0.5s -> 1s -> 2s
        status_forcelist=status_forcelist,             # 哪些 HTTP 狀態碼需要重試
        allowed_methods=["GET", "POST", "PUT", "DELETE"], # 允許重試的方法
        raise_on_status=False                          # 重試完若仍失敗，不在此處拋出，交由 caller 處理
    )
    
    adapter = HTTPAdapter(max_retries=retry_strategy, pool_connections=10, pool_maxsize=20)
    session.mount("https://", adapter)
    session.mount("http://", adapter)
    
    return session
```

---

### 3.3 遭遇 429 Too Many Requests 時的限流防護

當收到 HTTP 429 時，通常 Response Headers 會帶有 `Retry-After`，指示客戶端必須等待幾秒才能發送下一次請求：

```python
import time

def safe_api_call(session: requests.Session, url: str, **kwargs):
    while True:
        resp = session.get(url, **kwargs)
        if resp.status_code == 429:
            retry_after = int(resp.headers.get("Retry-After", 5))
            print(f"觸發頻率限制 (429)，依 Header 要求等待 {retry_after} 秒後重試...")
            time.sleep(retry_after)
            continue
        return resp
```

---

### 3.4 API 分頁擷取策略：Offset vs Cursor-based

當外部系統有數萬筆訂單時，不可能一次性返回，必須依據分頁規則完整爬取。

#### Cursor-based（游標分頁）標準提取範例
Cursor 分頁通常會在回應中提供 `next_cursor` 或 `has_more` 旗標：

```python
def fetch_all_orders_by_cursor(session: requests.Session, base_url: str) -> list:
    all_orders = []
    cursor = None
    
    while True:
        params = {"limit": 100}
        if cursor:
            params["cursor"] = cursor
            
        resp = session.get(f"{base_url}/orders", params=params, timeout=10)
        resp.raise_for_status()
        data = resp.json()
        
        batch = data.get("items", [])
        all_orders.extend(batch)
        print(f"已獲取 {len(all_orders)} 筆訂單...")
        
        # 檢查是否有下一頁游標
        cursor = data.get("next_cursor")
        if not cursor:
            break
            
    return all_orders
```

---

## 4. JSON 資料工程：pd.json_normalize 展平入庫

API 回應通常是多層巢狀結構（Nested JSON）。例如訂單包含 `customer: {id, name}` 和 `items: [{sku, qty}]`。
Pandas 的 `pd.json_normalize()` 是展平巢狀結構的神器：

```python
import pandas as pd

api_response_payload = [
    {
        "order_id": "ORD_2026_001",
        "order_date": "2026-06-15T09:30:00Z",
        "status": "APPROVED",
        "customer": {
            "customer_id": "CUST_001",
            "company_name": "台積電商務",
            "tier": "VIP"
        },
        "items": [
            {"product_id": "PROD_CHIP_X1", "qty": 50, "price": 1200.0},
            {"product_id": "PROD_SEN_A2", "qty": 100, "price": 350.0}
        ]
    }
]

# 將巢狀結構展開為平面表格
df_flat_items = pd.json_normalize(
    api_response_payload,
    record_path=["items"],                                        # 展開為列的巢狀列表
    meta=["order_id", "order_date", ["customer", "company_name"]], # 保留為欄位的父層屬性
    meta_prefix="meta_"
)

print(df_flat_items)
# 輸出結果為乾淨的平面關聯表：
#        product_id  qty   price   meta_order_id          meta_order_date meta_customer.company_name
# 0  PROD_CHIP_X1   50  1200.0  ORD_2026_001  2026-06-15T09:30:00Z                     台積電商務
# 1   PROD_SEN_A2  100   350.0  ORD_2026_001  2026-06-15T09:30:00Z                     台積電商務
```

---

## 5. 企業資安最佳實踐：憑證金鑰管理

- **永遠不要把 API Token 寫死在程式碼中上傳 Git**。
- 安裝 `python-dotenv`：`pip install python-dotenv`。
- 在專案根目錄建立 `.env` 檔案，並在 `.gitignore` 加入 `.env`。

```python
import os
from dotenv import load_dotenv

# 載入 .env 檔案中的環境變數
load_dotenv()

API_KEY = os.getenv("B2B_PARTNER_API_KEY")
if not API_KEY:
    raise ValueError("致命錯誤：系統未設定 B2B_PARTNER_API_KEY 環境變數！")
```

---

## 6. 商業情境綜合練習題（實戰動腦自測）

> 💡 **自我檢驗規範**：請先不要展開解答，在 Python 檔案中建立 Session、重試機制與簽章邏輯，再點開參考擬答對照！

### 題目一：高可用匯率即時轉換與快取機制
**業務情境**：
公司跨國訂單以美金（USD）、日圓（JPY）、歐元（EUR）計價，需要定期呼叫台灣銀行或第三方外匯 API 取得最新新台幣（TWD）匯率。
請撰寫一個類別 `ExchangeRateClient`：
1. 實作指數退避自動重試的 Session。
2. 支援獲取指定幣別的最新匯率。
3. 具備記憶體快取（TTL 60 分鐘）：在 60 分鐘內重複查詢相同幣別時，直接從記憶體返回，禁止重複發送網路請求浪費額度。

<details>
<summary>🔍 點擊展開「思維引導」</summary>

- 使用 `urllib3.util.retry.Retry(total=3, backoff_factor=1, status_forcelist=[500, 502, 503, 504])` 掛載至 `requests.Session()`。
- 使用字典 `self._cache` 儲存幣別、過期時間戳（`now + ttl`）與資料。
- 若網路臨時中斷且有舊快取，可實作 Stale-While-Revalidate 降級容災返回過期資料。
</details>

<details>
<summary>🔑 點擊展開「題目一參考擬答」</summary>

```python
import time
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
from typing import Dict, Any

class ExchangeRateClient:
    def __init__(self, api_base_url: str = "https://api.exchangerate-api.com/v4/latest", ttl_seconds: int = 3600):
        self.base_url = api_base_url
        self.ttl = ttl_seconds
        self._cache: Dict[str, Dict[str, Any]] = {}
        
        # 建立高可用 Session
        self.session = requests.Session()
        retry_strategy = Retry(
            total=3,
            backoff_factor=1,
            status_forcelist=[500, 502, 503, 504],
            allowed_methods=["GET"]
        )
        adapter = HTTPAdapter(max_retries=retry_strategy)
        self.session.mount("https://", adapter)

    def get_rate(self, base_currency: str = "USD", target_currency: str = "TWD") -> float:
        base_currency = base_currency.upper()
        target_currency = target_currency.upper()
        now = time.time()
        
        # 1. 檢查快取是否有效
        if base_currency in self._cache:
            cache_entry = self._cache[base_currency]
            if now < cache_entry["expire_at"]:
                rates = cache_entry["data"].get("rates", {})
                if target_currency in rates:
                    return float(rates[target_currency])

        # 2. 快取未命中或已過期，發送 API 請求
        url = f"{self.base_url}/{base_currency}"
        try:
            resp = self.session.get(url, timeout=5)
            resp.raise_for_status()
            data = resp.json()
            
            # 更新快取
            self._cache[base_currency] = {
                "data": data,
                "expire_at": now + self.ttl
            }
            
            rates = data.get("rates", {})
            if target_currency not in rates:
                raise ValueError(f"API 回應中不包含目標幣別: {target_currency}")
                
            return float(rates[target_currency])
            
        except requests.exceptions.RequestException as e:
            # 降級容災
            if base_currency in self._cache:
                print(f"[警告] API 請求失敗 ({e})，使用過期快取降級容災。")
                return float(self._cache[base_currency]["data"]["rates"][target_currency])
            raise RuntimeError(f"無法取得匯率資料: {e}")
```
</details>

---

### 題目二：Cursor 分頁批量抓取第三方物流出貨進度
**業務情境**：
每小時需要從物流合作夥伴 API 抓取「已出貨未簽收」的訂單狀態更新。
物流 API 規則如下：
- 端點：`GET /logistics/shipments`
- 參數：`status=IN_TRANSIT`、`limit=50`、`cursor=<token>`
- 回應格式：
  ```json
  {
    "has_more": true,
    "next_cursor": "eyJvZmZzZXQiOjUwfQ==",
    "shipments": [
      {"tracking_no": "TRK123", "order_id": "ORD_001", "carrier": "黑貓", "status": "IN_TRANSIT", "updated_at": "2026-06-30T10:00:00Z"}
    ]
  }
  ```
請撰寫函式 `fetch_all_in_transit_shipments(api_url, api_token)`，迴圈拉取所有分頁，並將結果轉換為乾淨的 Pandas DataFrame 返回。

<details>
<summary>🔍 點擊展開「思維引導」</summary>

- 使用 `while True:` 配合 `cursor` 迭代。
- 每次將抓到的 `shipments` 清單 `extend` 到總結果中。
- 檢查 `has_more` 是否為 False 或 `next_cursor` 為空，若是則中斷迴圈。
- 最後使用 `pd.DataFrame()` 包裝，並將日期欄位轉為 `pd.to_datetime`。
</details>

<details>
<summary>🔑 點擊展開「題目二參考擬答」</summary>

```python
import requests
import pandas as pd
from typing import List, Dict

def fetch_all_in_transit_shipments(api_url: str, api_token: str) -> pd.DataFrame:
    headers = {
        "Authorization": f"Bearer {api_token}",
        "Accept": "application/json"
    }
    
    session = requests.Session()
    cursor = None
    all_shipments: List[Dict] = []
    
    while True:
        params = {
            "status": "IN_TRANSIT",
            "limit": 50
        }
        if cursor:
            params["cursor"] = cursor
            
        try:
            resp = session.get(api_url, headers=headers, params=params, timeout=10)
            resp.raise_for_status()
            data = resp.json()
            
            shipments = data.get("shipments", [])
            all_shipments.extend(shipments)
            
            has_more = data.get("has_more", False)
            cursor = data.get("next_cursor")
            
            if not has_more or not cursor:
                break
                
        except requests.exceptions.RequestException as e:
            print(f"拉取物流分頁失敗: {e}")
            break

    if not all_shipments:
        return pd.DataFrame()

    df = pd.DataFrame(all_shipments)
    df["updated_at"] = pd.to_datetime(df["updated_at"])
    return df
```
</details>

---

### 題目三：整合電子發票開立 API 與 HMAC-SHA256 簽章產生
**業務情境**：
在台灣 B2B 電商出貨時，需串接第三方電子發票加值中心 API（如綠界或自建閘道）。
安全規範要求：除了傳遞發票 JSON Payload 外，必須在 Header 帶上 `X-Signature`，其生成規則為：
`HMAC_SHA256(SecretKey, RequestBody_JSON_String)`，並轉為十六進位小寫字串。
請撰寫一個函式 `issue_b2b_invoice(invoice_data: dict, secret_key: str, api_endpoint: str)`：
1. 嚴格按 key 排序序列化 JSON 字串。
2. 計算 HMAC-SHA256 簽章。
3. 發送 POST 請求並處理回應結果。

<details>
<summary>🔍 點擊展開「思維引導」</summary>

- 確保 JSON 格式標準化：使用 `json.dumps(invoice_data, sort_keys=True, separators=(",", ":"))`。
- 計算簽章：`hmac.new(key_bytes, payload_bytes, hashlib.sha256).hexdigest()`。
- 發送請求時，將序列化好的 `payload_bytes` 直接傳給 `data=` 參數，避免 `requests` 重新格式化導致簽章不匹配。
</details>

<details>
<summary>🔑 點擊展開「題目三參考擬答」</summary>

```python
import hmac
import hashlib
import json
import requests

def issue_b2b_invoice(invoice_data: dict, secret_key: str, api_endpoint: str) -> dict:
    """
    發送電子發票開立請求 (含 HMAC-SHA256 數位簽章)
    """
    # 1. 確保 JSON 格式標準化
    payload_str = json.dumps(invoice_data, sort_keys=True, separators=(",", ":"))
    payload_bytes = payload_str.encode("utf-8")
    key_bytes = secret_key.encode("utf-8")
    
    # 2. 計算 HMAC-SHA256 簽章
    signature = hmac.new(key_bytes, payload_bytes, hashlib.sha256).hexdigest()
    
    headers = {
        "Content-Type": "application/json",
        "X-Signature": signature,
        "User-Agent": "B2B-ERP-InvoiceClient/1.0"
    }
    
    # 3. 發送請求
    try:
        response = requests.post(
            api_endpoint,
            data=payload_bytes,
            headers=headers,
            timeout=10
        )
        response.raise_for_status()
        result = response.json()
        
        if result.get("status") == "SUCCESS":
            print(f"發票開立成功！發票號碼: {result.get('invoice_number')}")
            return result
        else:
            raise ValueError(f"開立發票被拒絕: {result.get('error_message')}")
            
    except requests.exceptions.HTTPError as http_err:
        print(f"發票 API 伺服器傳回錯誤: {http_err.response.status_code} - {http_err.response.text}")
        raise http_err
    except requests.exceptions.RequestException as req_err:
        print(f"發票 API 連線通訊失敗: {req_err}")
        raise req_err
```
</details>

---

## 🎯 本章收斂總結
> **💡 核心金句**：
> 「網路請求必設逾時，連線複用靠 Session；退避重試防崩潰，數位簽章保乾坤。」

