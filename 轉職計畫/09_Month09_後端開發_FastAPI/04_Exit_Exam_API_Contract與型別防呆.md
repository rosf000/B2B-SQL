# 🎓 M9 Exit Exam：API Contract 契約規範與 Pydantic 型別防呆 (API Design Gate)

> **「新手寫後端：看著教學拼出一個 `@app.get('/')` 就覺得自己會寫 API；工程師寫後端：在敲代碼前先定義好清晰的 API Contract（輸入、輸出、狀態碼、統一錯誤格式），並以 Pydantic 嚴防任何髒 Payload。」**

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

請在實作代碼前，明確規範以下兩個核心端點的契約結構：

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

在你的代碼中實現以下嚴格防呆規則：

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

## 🗣️ 口試題 (Interview Ready)

1. 「在 FastAPI 裡面，`async def` 跟一般 `def` 路由有什麼本質區別？如果你在一個 `async def` 路由裡面寫了一個耗時 10 秒的純同步阻塞操作（例如 `time.sleep(10)` 或 Pandas 巨量計算），會發生什麼災難？」
   - *答題要點*：FastAPI 的 `async def` 運行在主 Event Loop 上。若在其中執行同步阻塞代碼，會直接卡死整個伺服器的 Event Loop，導致所有其他用戶的並發請求全部排隊卡死！純計算或同步 I/O 應宣告為普通 `def`（FastAPI 會自動丟進外部 Threadpool 執行）或使用 Background Tasks / Celery。
2. 「RESTful API 中，`PUT` 與 `PATCH` 的差異是什麼？在資料冪等性（Idempotency）上有什麼不同？」

---

## 📝 結業簽核 (Pass Criteria)

- [ ] 完成 API Contract 文件定義（輸入/輸出/狀態碼）
- [ ] 實作 Pydantic V2 嚴格驗證（統編正則、Email、正數限制）
- [ ] 撰寫 TestClient 單元測試，4 項測試（含非法邊界值）100% 通過
- [ ] 能以白話向面試官解釋 Event Loop 與 async 阻塞風險

> 通過本測驗，代表你具備 **Month 09 Job Ready** 的專業 API 設計與後端防禦實力！
