# 02 REST API 原理與 Python Requests 實戰

## 一、HTTP 狀態碼與 REST API 規範

| 狀態碼 | 意義 | 常見情境 |
| :--- | :--- | :--- |
| **200 OK** | 成功 | GET 查詢成功返回資料 |
| **201 Created** | 建立成功 | POST 成功新增一筆資源 |
| **400 Bad Request** | 參數錯誤 | 客戶端傳入的 JSON 格式或欄位不合法 |
| **401 Unauthorized** | 未授權 | 缺少 API Key 或 Token 過期 |
| **404 Not Found** | 資源不存在 | 請求的客戶 ID 或路徑錯誤 |
| **429 Too Many Requests** | 超出速率限制 | 短時間內發送過多請求 (觸發 Rate Limit) |
| **500 Internal Server Error** | 伺服器錯誤 | 後端代碼崩潰或資料庫斷線 |

---

## 二、Python Requests 實作範例

```python
import requests
import time

def fetch_api_with_retry(url: str, params: dict = None, max_retries: int = 3) -> dict:
    """發送 GET 請求並支援自動重試機制。"""
    headers = {"User-Agent": "B2B-DataPipeline/1.0", "Accept": "application/json"}
    
    for attempt in range(1, max_retries + 1):
        try:
            response = requests.get(url, params=params, headers=headers, timeout=10)
            response.raise_for_status() # 4xx / 5xx 會自動拋出 HTTPError
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"[嘗試 {attempt}/{max_retries}] 請求失敗: {e}")
            if attempt < max_retries:
                time.sleep(2 ** attempt) # 指數退避延遲 (Exponential Backoff)
            else:
                raise e
```
