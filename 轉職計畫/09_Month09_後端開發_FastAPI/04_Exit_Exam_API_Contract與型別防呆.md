# 🎓 M9 Exit Exam：API Contract 契約規範與 Pydantic 型別防呆 (API Design Gate)

> **「新手寫後端：看著教學拼出一個 `@app.get('/')` 就覺得自己會寫 API；工程師寫後端：在敲程式碼前先定義好清晰的 API Contract（輸入、輸出、狀態碼、統一錯誤格式），並以 Pydantic 嚴防任何髒 Payload。」**

本測驗考察你身為後端與資料工程師的 **API 架構設計素養（API Design & Contract First）**。

---

## 📋 測驗標準與三層完成度 (Three-Tier Mastery)

- 🟢 **Level 1 — Survival**：能使用 FastAPI 建立基本的 GET / POST 路由，並在 `/docs` 成功呼叫。
- 🔵 **Level 2 — Job Ready (80分晉級線)**：
  - 實作標準的 **API Contract 契約**（嚴格定義 Request / Response Schema 與 HTTP Status Code）。
  - 使用 Pydantic V2 實作強型別邊界防呆（正則統編、正數金額、Email 格式、Enum 狀態）。
  - 建立全域統一的例外回應格式（Standardized JSON Error Response）。
  - 使用 `TestClient` 撰寫至少 4 個自動化測試用例，覆蓋 200, 201, 404, 422 狀態碼。
- 🔴 **Level 3 — Bonus (Interview Ready)**：
  - 深入理解 Python `async def` 異步機制與傳統同步 `def` 的執行差異（何時用 async？何時會被阻塞？）。
  - 掌握 FastAPI 依賴注入系統（Dependency Injection: `Depends`）實現資料庫 Session 共享與乾淨關閉。

---

## 📑 任務一：定義嚴謹的 API Contract（契約先行）

請在實作程式碼前，明確規範以下兩個核心端點的契約結構：

### 1. `POST /api/v1/orders`（建立 B2B 訂單）
- **Request Body (JSON)**：
  ```json
  {
    "customer_tax_id": "12345678",
    "contact_email": "procurement@example.com",
    "total_amount": 15800.50,
    "currency": "TWD",
    "status": "Pending",
    "items": [
      {"product_id": 101, "quantity": 5, "unit_price": 3160.10}
    ]
  }
  ```
- **Response 規格**：
  - 成功：`201 Created` 回傳包含 `order_id` 與建立時間。
  - 驗證失敗：`422 Unprocessable Entity`（例如金額小於等於 0、統編非 8 碼）。
  - 業務失敗：`404 Not Found`（客戶統編不存在於資料庫）。

---

## 🛠️ 任務二：Pydantic V2 邊界防呆模型

在你的程式碼中實現以下嚴格防呆規則：

```python
from pydantic import BaseModel, Field, EmailStr, field_validator
from typing import Literal, List

class OrderItemSchema(BaseModel):
    product_id: int = Field(gt=0, description="產品編號必須大於 0")
    quantity: int = Field(gt=0, description="數量必須為正整數")
    unit_price: float = Field(gt=0, description="單價必須大於 0")

class CreateOrderRequest(BaseModel):
    customer_tax_id: str = Field(..., pattern=r"^\d{8}$", description="台灣統編精確 8 碼數字")
    contact_email: EmailStr = Field(..., description="合法電子信箱")
    total_amount: float = Field(..., gt=0, description="總金額必須大於 0")
    currency: Literal["TWD", "USD", "EUR"] = "TWD"
    status: Literal["Pending", "Completed"] = "Pending"
    items: List[OrderItemSchema] = Field(..., min_length=1, description="至少需包含一個訂單品項")

    @field_validator("total_amount")
    @classmethod
    def validate_sum_matches(cls, total_amount, info):
        # 防呆檢查：品項總額是否等於訂單總額
        # (避免前後端計算不一致的惡意篡改)
        return total_amount
```

---

## 🧪 任務三：TestClient 自動化接口測試 (Testing Mindset)

使用 pytest 與 FastAPI 的 `TestClient` 驗證契約執行力：

```python
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_create_order_invalid_tax_id():
    """驗證當統編不是 8 碼時，必須被 Pydantic 攔截並回傳 422"""
    payload = {
        "customer_tax_id": "ABC123",  # 非法統編
        "contact_email": "test@b2b.com",
        "total_amount": 1000.0,
        "items": [{"product_id": 1, "quantity": 1, "unit_price": 1000.0}]
    }
    response = client.post("/api/v1/orders", json=payload)
    assert response.status_code == 422

def test_create_order_negative_amount():
    """驗證金額為負數時直接拒絕"""
    payload = {
        "customer_tax_id": "12345678",
        "contact_email": "test@b2b.com",
        "total_amount": -500.0,  # 非法負數
        "items": [{"product_id": 1, "quantity": 1, "unit_price": -500.0}]
    }
    response = client.post("/api/v1/orders", json=payload)
    assert response.status_code == 422
```

---

## 🗣️ 口試題 (Interview Ready - Flashcard 模式)

### Q1：「在 FastAPI 裡面，`async def` 跟一般 `def` 路由有什麼本質區別？如果你在一個 `async def` 路由裡面寫了一個耗時 10 秒的純同步阻塞操作（例如 `time.sleep(10)` 或 Pandas 巨量計算），會發生什麼災難？」

<details>
<summary>🧠 自我挑戰回想清單（先在腦中整理 15 秒）</summary>

- [ ] FastAPI 主執行緒的 Event Loop 運作原理是什麼？
- [ ] 宣告為一般 `def` 時，FastAPI 會如何處理？
- [ ] 若在 `async def` 裡面呼叫同步阻塞代碼，對其他使用者連線的影響為何？
- [ ] 正確的處理解法有哪三種？
</details>

<details>
<summary>🎯 專家級標準答題話術（點擊展開）</summary>

> **面試官答題話術**：  
> 「在 FastAPI 中，`async def` 與一般 `def` 的執行環境有根本上的架構差異：  
> 1. **`async def`**：直接運行在主執行緒的 **Event Loop（事件循環）** 上。它適用於支援非同步 non-blocking 的操作（如 `await httpx.AsyncClient` 或 `await asyncpg`）。如果我們在 `async def` 內呼叫了耗時 10 秒的同步阻塞操作（如 `time.sleep(10)`、`requests.get` 或 Pandas 運算），這行代碼會**完全凍結主 Event Loop**，導致整個應用程式在此 10 秒內無法切換處理任何其他使用者的連線請求，造成全站併發崩潰！  
> 2. **一般 `def`**：FastAPI 會自動將它派發到外部的 **ThreadPoolExecutor（執行緒池）** 中執行。即使執行了阻塞代碼，也只會佔用執行緒池的一個 Worker，完全不影響主 Event Loop 處理其他請求。  
> 
> **解法標準實務**：  
> - 若使用傳統同步庫或密集 CPU 運算，直接使用一般 `def`；  
> - 若堅持使用 `async def`，則阻塞操作必須透過 `anyio.to_thread.run_sync()` 轉移至執行緒；  
> - 若是超長耗時任務，應交由 Background Tasks 或 Celery/Redis Queue 非同步背景佇列處理。」
</details>

---

### Q2：「RESTful API 中，`PUT` 與 `PATCH` 的差異是什麼？在資料冪等性（Idempotency）上有什麼不同？」

<details>
<summary>🧠 自我挑戰回想清單（先在腦中整理 15 秒）</summary>

- [ ] PUT 與 PATCH 的語意分別代表全量替換還是局部增量？
- [ ] 什麼是冪等性（Idempotence）？
- [ ] 在 FastAPI + Pydantic 中，實作 PATCH 時最關鍵的參數是什麼？
</details>

<details>
<summary>🎯 專家級標準答題話術（點擊展開）</summary>

> **面試官答題話術**：  
> 「1. **語意差異**：  
> - **PUT** 是『**全量替換（Full Replacement）**』。客戶端必須傳遞資源的完整欄位。若某個欄位未傳遞，服務端通常會將其重置為預設值或 null。  
> - **PATCH** 是『**局部更新（Partial Update）**』。客戶端僅需傳遞欲修改的異動欄位，未傳遞的欄位在資料庫中保持原值不變。在 FastAPI 中，通常搭配 Pydantic 的 `payload.model_dump(exclude_unset=True)` 來安全過濾出真正有傳遞的增量欄位。  
> 
> 2. **冪等性（Idempotency）差異**：  
> - **PUT 本質上是冪等的（Idempotent）**：連續發送 1 次與 10 次相同的 PUT 請求，系統的終態完全一致。  
> - **PATCH 規範上不一定是冪等的**：雖然常見的局部賦值（如 `{"status": "PAID"}`）具備冪等性，但若 PATCH 操作為增量指令（例如 `{"stock": "+5"}`），重複執行會導致庫存不斷累加，因此依 RFC 規範 PATCH 不保證冪等。」
</details>

---

## 📝 結業簽核 (Pass Criteria)

- [ ] 完成 API Contract 文件定義（輸入/輸出/狀態碼）
- [ ] 實作 Pydantic V2 嚴格驗證（統編正則、Email、正數限制）
- [ ] 撰寫 TestClient 單元測試，4 項測試（含非法邊界值）100% 通過
- [ ] 能以白話向面試官解釋 Event Loop 與 async 阻塞風險

> 通過本測驗，代表你具備 **Month 09 Job Ready** 的專業 API 設計與後端防禦實力！

---

## 🔗 章節導航

- **前一篇**：[03_FastAPI_Testing與API文件品質.md](./03_FastAPI_Testing與API文件品質.md)（TestClient 自動化單元測試與覆蓋率）
- **邁向下一月**：[Month 10 容器化與雲端部署](../10_Month10_容器化與部署_Docker/README.md)（Docker Compose 多容器編排與雲端部署）
- **回到目錄**：[Month 09 學習模組主導航](./README.md)

