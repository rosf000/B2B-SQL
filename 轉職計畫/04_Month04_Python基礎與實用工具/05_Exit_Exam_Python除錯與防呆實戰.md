# 🎓 M4 Exit Exam：Python 除錯與防禦性編程實戰 (Debug Lab)

> **「初學者寫 Python 只要跑出結果就覺得大功告成；工程師寫 Python 第一眼看的是：空值會不會崩？型態錯了會不會 Crash？出錯時有沒有乾淨的 Traceback 與日誌？」**

在 B2B 工作環境中，業務或客戶丟給你的 CSV / JSON 永遠充滿髒資料。本測驗考察你面對真實世界 Python 報錯時的 **定位、修復與防禦性編程（Defensive Programming）** 實力。

---

## 📋 測驗標準與三層完成度 (Three-Tier Mastery)

- 🟢 **Level 1 — Survival**：能看懂 Python Traceback 堆疊追蹤訊息，定位報錯發生的檔案與行號。
- 🔵 **Level 2 — Job Ready (80分晉級線)**：
  - 成功找出並修復以下髒程式碼中的 5 大致命 Bug。
  - 使用 Python 寫出防禦性封裝（安全轉型、`.get()` 默認值、例外捕捉）。
  - 使用 `assert` 撰寫單元測試，驗證 5 大極端髒資料輸入不崩潰。
- 🔴 **Level 3 — Bonus (Interview Ready)**：
  - 解釋 Python 的 EAFP（Easier to Ask for Forgiveness than Permission）與 LBYL（Look Before You Leap）設計哲學。
  - 解釋為什麼絕對不能寫裸露的 `except: pass`（吞掉例外的致命危害）。

---

## 🚨 挑戰案例：一個隨時會 Crash 的批次處理腳本

以下是一段真實模擬的 B2B 訂單利潤批次計算腳本，內部暗藏 5 個隨時引爆的炸彈：

```python
# buggy_pipeline.py (充滿隱患的原始程式碼)
def process_b2b_orders(raw_orders):
    processed = []
    for order in raw_orders:
        # 1. 取得客戶統編與公司
        tax_id = order["tax_id"]
        company = order["company_name"].strip()
        
        # 2. 計算淨利潤與毛利率
        # total: 訂單總額, cost: 採購成本
        revenue = float(order["revenue"])
        cost = float(order["cost"])
        profit = revenue - cost
        margin_pct = (profit / revenue) * 100
        
        # 3. 格式化折扣碼
        discount = order["discount_code"].upper()
        
        processed.append({
            "tax_id": tax_id,
            "company": company,
            "profit": profit,
            "margin_pct": margin_pct,
            "discount": discount
        })
    return processed
```

---

## 💣 觸發崩潰的 5 大極端測試案例 (Crash Cases)

當傳入以下真實髒資料時，原始腳本必死無疑：

```python
dirty_data = [
    # Case 1: 缺少 tax_id 鍵值 ➜ 引爆 KeyError
    {"company_name": "宏達企業", "revenue": "10000", "cost": "8000", "discount_code": "vip"},
    
    # Case 2: revenue 為字串帶貨幣符號 "$5,000" 或為 None ➜ 引爆 ValueError / TypeError
    {"tax_id": "12345678", "company_name": "聯發商貿", "revenue": "$5,000", "cost": "3000", "discount_code": "none"},
    
    # Case 3: 免費樣品單 revenue 為 0 ➜ 引爆 ZeroDivisionError: division by zero
    {"tax_id": "87654321", "company_name": "創意思維", "revenue": 0, "cost": "500", "discount_code": "free"},
    
    # Case 4: 某些客戶無折扣碼 (欄位不存在或為 None) ➜ 引爆 KeyError 或 AttributeError: 'NoneType' object has no attribute 'upper'
    {"tax_id": "55667788", "company_name": "華南物流", "revenue": "20000", "cost": "15000", "discount_code": None},
    
    # Case 5: 繁體中文編碼問題 (Big5 vs UTF-8) 讀取 CSV 時噴 UnicodeDecodeError
]
```

---

## 🛠️ 任務目標：重構防禦型函式 `safe_process_orders`

請在你的環境中建立 `safe_pipeline.py`，要求做到：

1. **型態防呆清洗器 (`safe_float`)**：
   - 能自動剔除 `$`, `,`, 空白等雜質，若為 `None` 或無法解析則安全回傳預設值 `0.0`，並記錄 Warning 日誌。
2. **安全的字典鍵值讀取**：
   - 使用 `.get(key, default)` 避免 `KeyError`。
3. **安全除法 (`safe_division`)**：
   - 當分母為 0 時，回傳 `0.0`，杜絕 `ZeroDivisionError`。
4. **字串防呆**：
   - 確保欄位為 `None` 時回傳 `""` 或 `"DEFAULT"`，不拋出 `AttributeError`。
5. **隔離區機制 (Quarantine Pattern)**：
   - 若資料損毀嚴重（例如缺少關鍵識別項），將該筆紀錄放入 `rejected_records` 並註明原因，**絕不能讓整批資料中斷！**

<details>
<summary>🔑 點擊展開「safe_pipeline.py 參考重構解答」</summary>

```python
import re
import logging
from typing import List, Dict, Tuple, Any

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

def safe_float(value: Any, default: float = 0.0) -> float:
    """清理貨幣符號、逗號並轉為浮點數，異常時回傳 default。"""
    if value is None:
        return default
    try:
        # 去除 $, 空格與千分位逗號
        cleaned_str = re.sub(r"[^\d.-]", "", str(value))
        return float(cleaned_str) if cleaned_str else default
    except (ValueError, TypeError) as e:
        logger.warning(f"無法解析為數值: {value} -> 回傳預設值 {default}")
        return default

def safe_division(numerator: float, denominator: float) -> float:
    """安全除法，防範 ZeroDivisionError。"""
    if denominator == 0:
        return 0.0
    return numerator / denominator

def safe_process_orders(raw_orders: List[Dict[str, Any]]) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
    """具備隔離區 (Quarantine) 的生產級訂單清洗管線。"""
    valid_records = []
    rejected_records = []

    for idx, order in enumerate(raw_orders):
        try:
            # 1. 必填識別項檢查
            tax_id = order.get("tax_id")
            if not tax_id:
                rejected_records.append({
                    "raw_order": order,
                    "error_reason": "缺少關鍵識別項 tax_id",
                    "row_index": idx
                })
                logger.warning(f"第 {idx} 筆紀錄因缺少 tax_id 進入隔離區")
                continue

            company = str(order.get("company_name", "未知企業")).strip()

            # 2. 安全數值解析與計算
            revenue = safe_float(order.get("revenue"))
            cost = safe_float(order.get("cost"))
            profit = revenue - cost
            margin_pct = round(safe_division(profit, revenue) * 100, 2)

            # 3. 字串安全格式化
            raw_discount = order.get("discount_code")
            discount = str(raw_discount).upper() if raw_discount is not None else "NONE"

            valid_records.append({
                "tax_id": str(tax_id).strip(),
                "company": company,
                "revenue": revenue,
                "cost": cost,
                "profit": profit,
                "margin_pct": margin_pct,
                "discount": discount
            })
        except Exception as e:
            # 意外未捕捉異常進入隔離區，保證整個批次不中斷
            logger.error(f"處理第 {idx} 筆訂單發生未預期異常: {e}", exc_info=True)
            rejected_records.append({
                "raw_order": order,
                "error_reason": f"未預期例外: {str(e)}",
                "row_index": idx
            })

    return valid_records, rejected_records
```
</details>

---

## 🧪 任務二：單元測試防禦 (Testing Mindset)

使用 Python 撰寫測試腳本，執行 5 道斷言測試：

```python
# test_safe_pipeline.py 範例骨架
from safe_pipeline import safe_process_orders

def test_defensive_pipeline():
    # 傳入 dirty_data
    valid_records, rejected_records = safe_process_orders(dirty_data)
    
    # 斷言 1: 腳本不能崩潰，必須完整執行完畢
    assert len(valid_records) + len(rejected_records) == len(dirty_data)
    
    # 斷言 2: 免費樣品單 (revenue=0) 的毛利率必須為 0.0，不拋 ZeroDivisionError
    sample_order = next(r for r in valid_records if r["tax_id"] == "87654321")
    assert sample_order["margin_pct"] == 0.0
    
    # 斷言 3: 帶有貨幣符號 "$5,000" 的訂單能正確解析為浮點數
    currency_order = next(r for r in valid_records if r["tax_id"] == "12345678")
    assert currency_order["profit"] == 2000.0
    
    print("🎉 所有防禦性測試全數通過！")

if __name__ == "__main__":
    test_defensive_pipeline()
```

---

## 🗣️ 口試題 (Interview Ready)

1. 「在 Python 中，`try...except` 效能很差嗎？為什麼業界常說『Python 鼓勵使用 try...except 而不是一堆 if...else（EAFP 原則）』？」
2. 「在資料工程批次處理時，遇到髒資料應該直接 raise Error 讓整個流程死掉，還是偷偷跳過（pass）？你在實務上會怎麼設計？」

<details>
<summary>🔑 點擊展開「口試題深度擬答（EAFP 與隔離區架構）」</summary>

1. **EAFP（Easier to Ask for Forgiveness than Permission）哲學**：
   - 在 Python 中，如果沒有拋出例外，`try` 區塊的執行開銷幾乎為零（Python 3.11+ 的 Zero-cost exception handling）。
   - 相比於在每次操作前使用大量 `if hasattr(...)`、`if key in dict`（LBYL 風格，會造成兩次尋找開銷），直接 `try` 執行並在失敗時捕捉更為 Pythonic 且具備原子性（防止 Race Condition）。
2. **生產資料管線的三態設計**：
   - 既不能「直接 Crash 導致全公司管線癱瘓」，更絕對不能「用 `pass` 靜默吞掉造成幽靈遺失」。
   - **實務標準架構**：
     - **隔離區（Quarantine Table / Dead Letter Queue, DLQ）**：將損毀資料連同時間、錯誤原因寫入隔離表或專屬 JSON 檔案。
     - **健康度度量（Data Quality Metric）**：計算「髒資料比例」；若髒資料率 < 1%，告警並繼續下游；若髒資料率 > 10%（代表上游 Schema 變更或 API 故障），觸發熔斷機制（Circuit Breaker）中斷管線並發送 P1 告警至 Slack/PagerDuty。
</details>

---

## 📝 結業簽核 (Pass Criteria)

- [ ] 完整重構防禦型資料處理程式碼，杜絕 5 大 Crash 炸彈
- [ ] 實作單元測試腳本，所有斷言 100% 通過
- [ ] 具備隔離區 (Quarantine) 與 Logging 紀錄機制
- [ ] 能以口頭清晰解釋 EAFP 與例外處理設計哲學

> 通過本測驗，代表你具備 **Month 04 Job Ready** 的 Python 穩健工程開發能力！
