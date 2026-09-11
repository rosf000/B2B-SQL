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

## 💻 任務目標：打造高韌性抽取器 `fetch_with_resilience`

請實作一段生產級 Python 腳本，封裝以下防禦邏輯：

```python
import time
import random
import logging
import requests
from typing import Optional, Any

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

def fetch_with_resilience(
    url: str,
    params: Optional[dict] = None,
    max_retries: int = 3,
    base_backoff: float = 1.0,
    timeout: tuple[float, float] = (3.0, 10.0) # (connect_timeout, read_timeout)
) -> Optional[dict[str, Any]]:
    """
    具備生產級防禦的 API 請求抽取器：
    1. 顯式設定連線與讀取逾時時間 (防卡死)
    2. 指數退避 + 隨機抖動 (Exponential Backoff with Full Jitter)
    3. 針對 429 / 5xx / Timeout 進行安全重試
    4. 遇 4xx 客戶端錯誤立刻終止不盲目重試
    5. 重試耗盡後將失敗請求保存至本地 dead_letter_log.json
    """
    for attempt in range(1, max_retries + 1):
        try:
            logging.info(f"發起請求 (第 {attempt} 次嘗試): {url}")
            resp = requests.get(url, params=params, timeout=timeout)
            
            # 成功直接返回
            if resp.status_code == 200:
                try:
                    return resp.json()
                except requests.exceptions.JSONDecodeError:
                    logging.error("遠端回傳 200 但非合法 JSON (可能是 HTML 報錯頁面)！")
                    break
            
            # 處理 429 Rate Limit
            if resp.status_code == 429:
                wait_time = int(resp.headers.get("Retry-After", base_backoff * (2 ** attempt)))
                wait_time += random.uniform(0, 1)  # 加入隨機抖動 Jitter
                logging.warning(f"⚠️ 觸發 API 限流 (429)！等待 {wait_time:.2f} 秒後重試...")
                time.sleep(wait_time)
                continue
                
            # 處理 5xx 伺服器錯誤
            if 500 <= resp.status_code < 600:
                wait_time = base_backoff * (2 ** attempt) + random.uniform(0, 1)
                logging.warning(f"⚠️ 遠端伺服器異常 ({resp.status_code})！等待 {wait_time:.2f} 秒後重試...")
                time.sleep(wait_time)
                continue
                
            # 其他不可重試的 4xx 錯誤 (如 401 密碼錯、404 不存在)
            logging.error(f"❌ 不可重試的客戶端錯誤 ({resp.status_code})，終止請求。")
            break

        except (requests.exceptions.Timeout, requests.exceptions.ConnectionError) as exc:
            wait_time = base_backoff * (2 ** attempt) + random.uniform(0, 1)
            logging.warning(f"⚠️ 網路連線/逾時異常: {exc}！等待 {wait_time:.2f} 秒後重試...")
            time.sleep(wait_time)

    # 重試耗盡，死信落盤
    logging.critical(f"🚨 請求失敗超過最大重試次數 ({max_retries})，記錄至死信日誌！")
    record_dead_letter(url, params)
    return None

def record_dead_letter(url: str, params: Optional[dict]):
    """將失敗任務保存於本地，供後續手動重放 (Replay)"""
    with open("dead_letter_log.jsonl", "a", encoding="utf-8") as f:
        import json
        f.write(json.dumps({"url": url, "params": params, "timestamp": time.time()}) + "\n")
```

---

## 🧪 任務二：Mock 模擬測試 (Testing Mindset)

使用 Python 測試模組（如 `responses` 或手動 Mock）模擬以下情境，證明你的腳本不會 Crash：
1. **測試 429 限流**：模擬前 2 次回傳 429，第 3 次回傳 200，驗證腳本是否正確暫停並最終成功取得資料。
2. **測試 Timeout**：模擬連線超時，驗證捕獲 `requests.Timeout` 並自動重試。
3. **測試死信佇列**：模擬連續 3 次 500 錯誤，驗證 `dead_letter_log.jsonl` 成功寫入失敗記錄。

---

## 🗣️ 口試題 (Interview Ready)

1. 「在呼叫第三方 API 時，為什麼不設定 `timeout` 是極度危險的架構毒瘤？」
   - *答題要點*：Python `requests` 默認沒有 timeout，若遠端伺服器假死，你的 Worker 會永久掛起（Hang 住），耗盡伺服器連線資源，導致整個 Pipeline 癱瘓。
2. 「什麼是指數退避（Exponential Backoff）與 Jitter？為什麼多個 Worker 同時重試時必須加隨機抖動？」
   - *答題要點*：避免所有客戶端在相同秒數（如第 2 秒、第 4 秒）同時發起重試，造成遠端伺服器二度被瞬間流量打垮（雷鳴群效應）。

---

## 📝 結業簽核 (Pass Criteria)

- [ ] 獨立實作具備指數退避、Jitter、Timeout 與死信落盤的 API 請求器
- [ ] 通過 429、500、Timeout 模擬測試
- [ ] 能清楚口述 API 防禦設計與 Timeout 危害

> 通過本測驗，代表你具備 **Month 06 Job Ready** 的高韌性資料爬取與自動化對接能力！
