# 03. FastAPI Testing 與 API 文件品質

> **模組目標**：為 M9 完成的 B2B FastAPI 加上自動化測試與完整 API 文件。這是讓旗艦作品從「能跑」升級到「工程品質」的關鍵一步，也是面試中越來越常被問到的能力。

---

## 目錄

1. [為什麼 API 需要測試？](#1-為什麼-api-需要測試)
2. [FastAPI 測試工具：TestClient + pytest](#2-fastapi-測試工具testclient--pytest)
3. [測試目錄結構](#3-測試目錄結構)
4. [基礎 API 測試範例](#4-基礎-api-測試範例)
5. [測試資料庫隔離（不污染正式 DB）](#5-測試資料庫隔離不污染正式-db)
6. [測試覆蓋率報告](#6-測試覆蓋率報告)
7. [Swagger UI 文件優化](#7-swagger-ui-文件優化)
8. [Checkpoint](#8-checkpoint)

---

## 1. 為什麼 API 需要測試？

```
沒有 API 測試的問題：

修改了 transform.py 的清洗邏輯
    ↓
POST /customers 的回傳格式悄悄變了
    ↓
前端/對接方不知道，資料默默進錯
    ↓
三週後才發現問題，而且很難追蹤

有 API 測試的世界：

修改了任何程式碼
    ↓
pytest 自動跑所有 API 測試（30秒）
    ↓
任何回傳格式改變 → 立即測試失敗 → 立即知道哪裡壞了
```

API 測試讓你「有信心修改程式碼」，這是工程品質的核心。

---

## 2. FastAPI 測試工具：TestClient + pytest

FastAPI 內建對測試的支援，透過 `httpx` 的 `TestClient` 可以在不啟動伺服器的情況下發送 HTTP 請求。

### 安裝

```bash
pip install pytest httpx pytest-cov
```

### 更新 requirements.txt

```txt
fastapi
uvicorn[standard]
sqlalchemy
psycopg2-binary
pydantic
python-dotenv

# Testing
pytest>=7.0
httpx>=0.24
pytest-cov>=4.0
```

---

## 3. 測試目錄結構

```
b2b_fastapi_app/
├── app/
│   ├── main.py
│   ├── routers/
│   │   ├── customers.py
│   │   ├── orders.py
│   │   └── analytics.py
│   ├── models.py
│   ├── schemas.py
│   └── database.py
├── tests/                    ← 測試目錄
│   ├── __init__.py
│   ├── conftest.py           ← 共用測試設定（Fixture）
│   ├── test_customers.py     ← 客戶 API 測試
│   ├── test_orders.py        ← 訂單 API 測試
│   └── test_analytics.py    ← 分析 API 測試
├── .env
├── .env.test                 ← 測試用環境變數
└── pytest.ini                ← pytest 設定
```

---

## 4. 基礎 API 測試範例

### conftest.py — 共用測試設定

```python
# tests/conftest.py
"""
共用測試設定與 Fixture
"""
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.main import app
from app.database import Base, get_db


# ── 建立測試用的記憶體資料庫（不影響正式 DB）────────────────────
TEST_DATABASE_URL = "sqlite:///:memory:"

engine = create_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)


def override_get_db():
    """替換正式 DB 連線，改用測試 DB"""
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture(scope="function")
def client():
    """
    每個測試函式都會獲得一個乾淨的 TestClient。
    測試完成後，資料庫會被清空（scope="function"）。
    """
    # 建立測試用的資料表
    Base.metadata.create_all(bind=engine)

    # 把 FastAPI 的 DB 依賴替換成測試 DB
    app.dependency_overrides[get_db] = override_get_db

    with TestClient(app) as test_client:
        yield test_client

    # 測試完成後清空資料表
    Base.metadata.drop_all(bind=engine)
    app.dependency_overrides.clear()


@pytest.fixture
def sample_customer_payload():
    """一份合法的客戶建立請求資料"""
    return {
        "company_name": "測試科技股份有限公司",
        "tax_id": "12345678",
        "industry": "科技",
        "city": "台北",
        "credit_limit": 500000.0,
        "status": "active"
    }
```

---

### test_customers.py — 客戶 API 完整測試

```python
# tests/test_customers.py
"""
客戶 API 測試套件

測試覆蓋範圍：
- GET  /customers     - 取得客戶清單
- GET  /customers/{id} - 取得單一客戶
- POST /customers     - 新增客戶
- PUT  /customers/{id} - 更新客戶
- 錯誤處理（404, 422, 409）
"""
import pytest
from fastapi.testclient import TestClient


class TestGetCustomers:
    """GET /customers 測試群組"""

    def test_get_empty_customer_list(self, client: TestClient):
        """初始狀態應該回傳空清單"""
        response = client.get("/customers")
        assert response.status_code == 200
        assert response.json() == []

    def test_get_customers_after_creation(
        self, client: TestClient, sample_customer_payload: dict
    ):
        """新增客戶後，清單應該包含該客戶"""
        # 先新增一筆
        client.post("/customers", json=sample_customer_payload)

        # 再查詢
        response = client.get("/customers")
        assert response.status_code == 200
        customers = response.json()
        assert len(customers) == 1
        assert customers[0]["company_name"] == sample_customer_payload["company_name"]

    def test_get_customers_pagination(self, client: TestClient, sample_customer_payload: dict):
        """分頁參數測試"""
        # 新增 3 筆客戶
        for i in range(3):
            payload = sample_customer_payload.copy()
            payload["tax_id"] = f"1234567{i}"
            payload["company_name"] = f"測試公司 {i}"
            client.post("/customers", json=payload)

        # 每頁 2 筆，取第 1 頁
        response = client.get("/customers?skip=0&limit=2")
        assert response.status_code == 200
        assert len(response.json()) == 2

        # 每頁 2 筆，取第 2 頁
        response = client.get("/customers?skip=2&limit=2")
        assert response.status_code == 200
        assert len(response.json()) == 1


class TestCreateCustomer:
    """POST /customers 測試群組"""

    def test_create_customer_success(
        self, client: TestClient, sample_customer_payload: dict
    ):
        """成功建立客戶，回傳 201 與正確資料"""
        response = client.post("/customers", json=sample_customer_payload)

        assert response.status_code == 201
        data = response.json()

        # 驗證回傳欄位
        assert "customer_id" in data           # 應該有自動產生的 ID
        assert data["company_name"] == sample_customer_payload["company_name"]
        assert data["tax_id"] == sample_customer_payload["tax_id"]
        assert data["status"] == "active"

    def test_create_customer_missing_required_field(self, client: TestClient):
        """缺少必填欄位應回傳 422 Unprocessable Entity"""
        incomplete_payload = {
            "company_name": "不完整公司"
            # 缺少 tax_id（必填）
        }
        response = client.post("/customers", json=incomplete_payload)
        assert response.status_code == 422

    def test_create_customer_duplicate_tax_id(
        self, client: TestClient, sample_customer_payload: dict
    ):
        """重複 tax_id 應回傳 409 Conflict"""
        # 第一次建立：成功
        client.post("/customers", json=sample_customer_payload)

        # 第二次建立相同 tax_id：應失敗
        response = client.post("/customers", json=sample_customer_payload)
        assert response.status_code == 409
        assert "已存在" in response.json()["detail"]  # 錯誤訊息要說清楚

    def test_create_customer_invalid_credit_limit(
        self, client: TestClient, sample_customer_payload: dict
    ):
        """負數的 credit_limit 應回傳 422"""
        payload = sample_customer_payload.copy()
        payload["credit_limit"] = -1000  # 不合法
        response = client.post("/customers", json=payload)
        assert response.status_code == 422


class TestGetCustomerById:
    """GET /customers/{id} 測試群組"""

    def test_get_existing_customer(
        self, client: TestClient, sample_customer_payload: dict
    ):
        """取得存在的客戶"""
        # 新增客戶
        create_resp = client.post("/customers", json=sample_customer_payload)
        customer_id = create_resp.json()["customer_id"]

        # 取得客戶
        response = client.get(f"/customers/{customer_id}")
        assert response.status_code == 200
        assert response.json()["customer_id"] == customer_id

    def test_get_nonexistent_customer(self, client: TestClient):
        """取得不存在的客戶應回傳 404"""
        response = client.get("/customers/99999")
        assert response.status_code == 404
        assert "找不到" in response.json()["detail"]


class TestUpdateCustomer:
    """PUT /customers/{id} 測試群組"""

    def test_update_customer_credit_limit(
        self, client: TestClient, sample_customer_payload: dict
    ):
        """成功更新 credit_limit"""
        create_resp = client.post("/customers", json=sample_customer_payload)
        customer_id = create_resp.json()["customer_id"]

        update_payload = {"credit_limit": 1000000.0}
        response = client.put(f"/customers/{customer_id}", json=update_payload)

        assert response.status_code == 200
        assert response.json()["credit_limit"] == 1000000.0

    def test_update_nonexistent_customer(self, client: TestClient):
        """更新不存在的客戶應回傳 404"""
        response = client.put("/customers/99999", json={"status": "inactive"})
        assert response.status_code == 404
```

---

### test_analytics.py — 分析 API 測試

```python
# tests/test_analytics.py
"""
分析 API 測試（重點在回傳結構，而非數字正確性）
"""


class TestSalesAnalytics:

    def test_sales_performance_returns_list(self, client):
        """業務績效 API 應回傳 list"""
        response = client.get("/sales/performance")
        assert response.status_code == 200
        assert isinstance(response.json(), list)

    def test_sales_performance_has_required_fields(self, client, sample_customer_payload):
        """業務績效每筆資料都應包含必要欄位"""
        # 建立測試資料（需要客戶 + 訂單）
        # ... (建立測試資料的邏輯)

        response = client.get("/sales/performance")
        if len(response.json()) > 0:
            first_item = response.json()[0]
            required_fields = ["salesperson_id", "name", "total_amount", "order_count"]
            for field in required_fields:
                assert field in first_item, f"回傳資料缺少欄位：{field}"

    def test_inactive_customers_query(self, client):
        """沉睡客戶查詢 API 應接受 days 參數"""
        response = client.get("/customers/inactive?days=90")
        assert response.status_code == 200
        assert isinstance(response.json(), list)

    def test_inactive_customers_invalid_days(self, client):
        """days 參數為負數應回傳 422"""
        response = client.get("/customers/inactive?days=-1")
        assert response.status_code == 422
```

---

## 5. 測試資料庫隔離（不污染正式 DB）

上面的 `conftest.py` 使用 **SQLite 記憶體資料庫**做測試隔離，這樣：
- 測試不會碰到正式的 PostgreSQL
- 每個測試函式都從空資料庫開始
- 測試完成後資料自動清空

```
測試執行流程：

pytest 開始
│
├── 測試 A 開始
│   ├── conftest: 建立乾淨的 SQLite 資料庫
│   ├── 執行測試（讀/寫 SQLite）
│   └── conftest: 清空 SQLite 資料庫
│
├── 測試 B 開始
│   ├── conftest: 建立乾淨的 SQLite 資料庫
│   ├── 執行測試（讀/寫 SQLite）
│   └── conftest: 清空 SQLite 資料庫
│
└── pytest 結束（正式 PostgreSQL 完全沒有被碰到）
```

---

## 6. 測試覆蓋率報告

```bash
# 執行測試並產生覆蓋率報告
pytest --cov=app --cov-report=term-missing

# 輸出範例：
# Name                      Stmts   Miss  Cover   Missing
# ─────────────────────────────────────────────────────────
# app/main.py                  12      0   100%
# app/routers/customers.py     45      5    89%   78-82
# app/routers/orders.py        38      8    79%   45-50, 63
# app/models.py                22      0   100%
# ─────────────────────────────────────────────────────────
# TOTAL                       117     13    89%

# 產生 HTML 報告（可在瀏覽器看視覺化結果）
pytest --cov=app --cov-report=html
# 然後開啟 htmlcov/index.html
```

### pytest.ini 設定

```ini
; pytest.ini
[pytest]
testpaths = tests
python_files = test_*.py
python_classes = Test*
python_functions = test_*

; 預設覆蓋率設定
addopts = -v --tb=short
```

### 執行方式

```bash
# 執行所有測試
pytest

# 只執行客戶相關測試
pytest tests/test_customers.py

# 執行特定測試類別
pytest tests/test_customers.py::TestCreateCustomer

# 執行特定測試函式
pytest tests/test_customers.py::TestCreateCustomer::test_create_customer_success

# 詳細輸出（失敗時顯示完整訊息）
pytest -v

# 失敗立即停止
pytest -x
```

---

## 7. Swagger UI 文件優化

FastAPI 自動生成的 Swagger UI（`/docs`）可以透過在程式碼加入說明來大幅提升品質。

### 在 Router 加入 OpenAPI 文件

```python
# app/routers/customers.py

from fastapi import APIRouter, Depends, HTTPException, status
from typing import Optional

router = APIRouter(prefix="/customers", tags=["Customers"])


@router.get(
    "/",
    summary="取得客戶清單",
    description="""
    取得所有客戶資料，支援分頁查詢。

    **使用場景：**
    - 業務員查看自己負責的客戶清單
    - 管理者瀏覽全部客戶

    **回傳說明：**
    - 依 `company_name` 字母順序排序
    """,
    response_description="客戶清單陣列",
)
async def get_customers(
    skip: int = 0,
    limit: int = 100,
    status: Optional[str] = None,
    db=Depends(get_db)
):
    ...


@router.post(
    "/",
    status_code=status.HTTP_201_CREATED,
    summary="新增客戶",
    responses={
        201: {"description": "客戶建立成功"},
        409: {"description": "統一編號重複"},
        422: {"description": "資料格式驗證失敗"},
    }
)
async def create_customer(...):
    ...
```

### main.py 的 API 元資料

```python
# app/main.py

from fastapi import FastAPI

app = FastAPI(
    title="B2B Data Platform API",
    description="""
    ## B2B 客戶數據與業務分析平台

    整合 B2B 商業實務的資料管理系統，提供：

    * **客戶管理**：客戶 CRUD、去重偵測
    * **訂單管理**：訂單查詢、狀態追蹤
    * **業務分析**：RFM 分群、績效報表
    * **AI 查詢**：自然語言轉 SQL（M11 功能）
    """,
    version="1.0.0",
    contact={
        "name": "Jay",
        "url": "https://github.com/your-username/b2b-platform",
    },
    license_info={
        "name": "MIT",
    },
)
```

---

## 8. Checkpoint

```
□ tests/ 目錄存在，有 conftest.py
□ test_customers.py 有至少 8 個測試（覆蓋成功/失敗/邊界情況）
□ pytest 全部通過（0 failures）
□ pytest --cov=app 覆蓋率達到 75% 以上
□ /docs 的 Swagger UI 每個 Endpoint 都有清楚的 summary 和 description
□ 錯誤情況（404, 409, 422）的回傳訊息是中文且說清楚原因
□ README 說明如何執行測試（pytest 指令）

進階（有時間再做）：
□ 加入 test_orders.py
□ 加入 test_analytics.py
□ 用 GitHub Actions 設定 CI（每次 push 自動跑測試）
```

---

## 連結旗艦作品

完成 M9 測試後，旗艦作品的技術文件可以這樣寫：

```markdown
## 測試

本專案使用 pytest + httpx TestClient 進行 API 自動化測試。

\```bash
# 安裝依賴
pip install -r requirements.txt

# 執行測試
pytest

# 執行測試（含覆蓋率報告）
pytest --cov=app --cov-report=term-missing
\```

測試覆蓋範圍：
- ✅ 客戶 CRUD（建立/查詢/更新）
- ✅ 欄位驗證（422 錯誤情況）
- ✅ 重複資料防護（409 衝突）
- ✅ 不存在資源（404 處理）
```

這段文字放進 GitHub README，面試官看到會知道你的 API 是有測試保護的。
