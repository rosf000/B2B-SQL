# 🎓 M6 Exit Exam：API Failure & Resilience Lab (API 不可信實戰防禦)

> **「業餘工程師寫 API 呼叫：只要 `requests.get(url).json()` 能跑通就交差；資深工程師寫 API 呼叫：開口第一句是『429 怎麼限流？500 怎麼重試？Timeout 設幾秒？斷網時資料有沒有落盤備份？』」**

外部 API（CRM、ERP、金流閘道、政府開放資料）永遠處於隨時可能故障、限流或改版的狀態。本測驗考察你打造 **工業級高韌性 API 數據擷取管線** 的實戰能力。

---

## 📋 測驗標準與三層完成度 (Three-Tier Mastery)

- 🟢 **Level 1 — Survival**：能使用 `requests` 帶 Headers 與 Query Params 正確發出 GET/POST 請求並解析 JSON。
- 🔵 **Level 2 — Job Ready (80分晉級線)**：
  - 實作具備「指數退避（Exponential Backoff）」與「逾時防禦（Timeout）」的高韌性請求函式。
  - 能正確區分可重試錯誤（429, 500, 502, 503, Timeout）與不可重試錯誤（400, 401, 403, 404）。
  - 當 API 持續失敗時，具備「死信落盤（Dead Letter Queue）」機制，不丟失任務上下文。
  - 使用 Mock 或測試工具完成 5 大 HTTP 狀態異常攔截驗證。
- 🔴 **Level 3 — Bonus (Interview Ready)**：
  - 解釋「分散式系統中的雷鳴群問題（Thundering Herd Problem）」與隨機抖動（Full Jitter）演算法原理。
  - 掌握 Pandas 記憶體優化：讀取百萬筆 API 資料時的 `chunksize` 與型態壓縮。

---

## 🚨 模擬實驗室：5 大真實 API 災難情境

```
[ Your ETL Pipeline ]
        │
        ├── 1. 200 OK ➜ 正常資料解析
        ├── 2. 429 Too Many Requests ➜ 觸發 Rate Limit ➜ 需等待 Retry-After 或指數退避
        ├── 3. 500 / 503 Server Error ➜ 遠端伺服器崩潰 ➜ 指數退避重試 (最多3次)
        ├── 4. Timeout (連線或讀取超時) ➜ 捕獲 requests.Timeout ➜ 優雅重試
        └── 5. 200 OK 但 Body 是 HTML 或髒 JSON ➜ 捕獲 JSONDecodeError
```

---

## 💻 任務一：打造高韌性抽取器 `fetch_with_resilience`

請在你的環境中建立 `api_resilience.py`，手動實作一個具備生產級防禦的 API 請求抽取器函式：
`fetch_with_resilience(url, params=None, max_retries=3, base_backoff=1.0, timeout=(3.0, 10.0))`

### 核心防衛規格要求：
1. **顯式設定連線與讀取逾時**：傳入元組 `(connect_timeout, read_timeout)`，杜絕連線永久掛死。
2. **指數退避 + 隨機抖動 (Exponential Backoff with Full Jitter)**：每次重試等待時間隨次方增長並疊加隨機浮點數，防範雷鳴群問題。
3. **錯誤精準分類重試**：
   - 遇到 `429 Too Many Requests`：讀取 Header 中的 `Retry-After`，若無則按指數退避等待重試。
   - 遇到 `5xx Server Error` 或 `requests.Timeout`：執行安全重試。
   - 遇到 `400, 401, 403, 404` 等客戶端錯誤：立刻終止，禁止盲目重試浪費資源。
4. **死信落盤 (Dead Letter Queue, DLQ)**：若重試 `max_retries` 次仍全數失敗，將該請求網址、參數與時間戳寫入本地 `dead_letter_log.jsonl`，確保任務不遺失。

<details>
<summary>🔑 點擊展開「fetch_with_resilience 參考防禦代碼」</summary>

```python
import time
import random
import logging
import json
import requests
from typing import Optional, Any

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

def record_dead_letter(url: str, params: Optional[dict]):
    """將失敗任務保存於本地死信日誌，供後續手動重放 (Replay)"""
    with open("dead_letter_log.jsonl", "a", encoding="utf-8") as f:
        f.write(json.dumps({"url": url, "params": params, "timestamp": time.time()}) + "\n")

def fetch_with_resilience(
    url: str,
    params: Optional[dict] = None,
    max_retries: int = 3,
    base_backoff: float = 1.0,
    timeout: tuple[float, float] = (3.0, 10.0) # (connect_timeout, read_timeout)
) -> Optional[dict[str, Any]]:
    for attempt in range(1, max_retries + 1):
        try:
            logger.info(f"發起請求 (第 {attempt} 次嘗試): {url}")
            resp = requests.get(url, params=params, timeout=timeout)
            
            # 成功直接返回
            if resp.status_code == 200:
                try:
                    return resp.json()
                except requests.exceptions.JSONDecodeError:
                    logger.error("遠端回傳 200 但非合法 JSON (可能是 HTML 報錯頁面)！")
                    break
            
            # 處理 429 Rate Limit
            if resp.status_code == 429:
                wait_time = int(resp.headers.get("Retry-After", base_backoff * (2 ** attempt)))
                wait_time += random.uniform(0, 1)  # 加入隨機抖動 Jitter
                logger.warning(f"⚠️ 觸發 API 限流 (429)！等待 {wait_time:.2f} 秒後重試...")
                time.sleep(wait_time)
                continue
                
            # 處理 5xx 伺服器錯誤
            if 500 <= resp.status_code < 600:
                wait_time = base_backoff * (2 ** attempt) + random.uniform(0, 1)
                logger.warning(f"⚠️ 遠端伺服器異常 ({resp.status_code})！等待 {wait_time:.2f} 秒後重試...")
                time.sleep(wait_time)
                continue
                
            # 其他不可重試的 4xx 錯誤 (如 401 憑證錯、404 不存在)
            logger.error(f"❌ 不可重試的客戶端錯誤 ({resp.status_code})，終止請求。")
            break

        except (requests.exceptions.Timeout, requests.exceptions.ConnectionError) as exc:
            wait_time = base_backoff * (2 ** attempt) + random.uniform(0, 1)
            logger.warning(f"⚠️ 網路連線/逾時異常: {exc}！等待 {wait_time:.2f} 秒後重試...")
            time.sleep(wait_time)

    # 重試耗盡，死信落盤
    logger.critical(f"🚨 請求失敗超過最大重試次數 ({max_retries})，記錄至死信日誌！")
    record_dead_letter(url, params)
    return None
```
</details>

---

## 🧪 任務二：Mock 模擬測試 (Testing Mindset)

使用 Python 測試模組（如 `responses` 或手動 Mock）模擬以下情境，證明你的腳本不會 Crash：
1. **測試 429 限流**：模擬前 2 次回傳 429，第 3 次回傳 200，驗證腳本是否正確暫停並最終成功取得資料。
2. **測試 Timeout**：模擬連線超時，驗證捕獲 `requests.Timeout` 並自動重試。
3. **測試死信佇列**：模擬連續 3 次 500 錯誤，驗證 `dead_letter_log.jsonl` 成功寫入失敗記錄。

<details>
<summary>🔑 點擊展開「Mock 測試程式碼參考」</summary>

```python
import responses
from api_resilience import fetch_with_resilience

@responses.activate
def test_rate_limit_retry():
    test_url = "https://api.example.com/data"
    
    # 模擬兩次 429，第三次 200
    responses.add(responses.GET, test_url, status=429, headers={"Retry-After": "1"})
    responses.add(responses.GET, test_url, status=429, headers={"Retry-After": "1"})
    responses.add(responses.GET, test_url, status=200, json={"result": "success"})
    
    data = fetch_with_resilience(test_url, max_retries=3, base_backoff=0.1)
    assert data == {"result": "success"}
    print("✅ 429 限流退避重試測試通過！")

if __name__ == "__main__":
    test_rate_limit_retry()
```
</details>

---

## 🗣️ 口試題 (Interview Ready)

1. 「在呼叫第三方 API 時，為什麼不設定 `timeout` 是極度危險的架構毒瘤？」
2. 「什麼是指數退避（Exponential Backoff）與 Jitter？為什麼多個 Worker 同時重試時必須加隨機抖動？」

<details>
<summary>🔑 點擊展開「標準擬答要點」</summary>

1. **Timeout 致命隱患**：
   - Python `requests` 默認沒有 timeout。若遠端伺服器網路中斷或處理卡死，Python 執行緒將無上限永久掛起（Hang 住），伺服器連線資源被占滿，導致整條資料管線全面癱瘓。
2. **指數退避與 Jitter 原理**：
   - 指數退避讓重試間隔成倍數放大（1s, 2s, 4s...），給予遠端伺服器喘息恢復的空間。
   - **Full Jitter（隨機抖動）** 是為防止「雷鳴群問題（Thundering Herd Problem）」。如果 50 個分散式 Worker 同時在第 2.0 秒、第 4.0 秒發起重試，瞬間峰值會再次把剛重啟的伺服器打掛。加入隨機擾動可將重試請求在時序上均勻打散。
</details>

---

## 📝 結業簽核 (Pass Criteria)

- [ ] 獨立實作具備指數退避、Jitter、Timeout 與死信落盤的 API 請求器
- [ ] 通過 429、500、Timeout 模擬測試
- [ ] 能清楚口述 API 防禦設計與 Timeout 危害

> 通過本測驗，代表你具備 **Month 06 Job Ready** 的高韌性資料爬取與自動化對接能力！
