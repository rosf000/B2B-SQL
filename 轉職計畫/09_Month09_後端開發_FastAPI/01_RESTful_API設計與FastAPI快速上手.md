# 01. RESTful API 設計與 FastAPI 快速上手指南

> **模組目標**：掌握現代 Python 後端開發之王——**FastAPI**。深入剖析 ASGI 與非同步（Asyncio）底層運行機制，打破「`async def` 一律比較快」的迷思；熟練運用 FastAPI 強大的依賴注入系統（Dependency Injection / `Depends`）實現資料庫連線生命週期管理與安全認證；掌握模組化 `APIRouter` 設計原則與全域統一例外處理器（Global Exception Handler），打造具備高併發、自帶 Swagger 文件的企業級 B2B 微服務。

---

## 目錄
1. [現代後端技術演進：為什麼 FastAPI 取代了傳統框架？](#1-現代後端技術演進為什麼-fastapi-取代了傳統框架)
   - [1.1 WSGI vs ASGI 底層通訊架構對比](#11-wsgi-vs-asgi-底層通訊架構對比)
   - [1.2 FastAPI 兩大基石：Starlette 與 Pydantic v2](#12-fastapi-兩大基石starlette-與-pydantic-v2)
2. [非同步並行核心心智模型：async def vs def](#2-非同步並行核心心智模型async-def-vs-def)
   - [2.1 Event Loop 事件循環運行機制](#21-event-loop-事件循環運行機制)
   - [2.2 什麼時候該用 async def？什麼時候用一般 def？](#22-什麼時候該用-async-def什麼時候用一般-def)
   - [2.3 致命陷阱：在 async 函式中呼叫阻塞式代碼](#23-致命陷阱在-async-函式中呼叫阻塞式代碼)
3. [RESTful 路由設計與參數解析全攻略](#3-restful-路由設計與參數解析全攻略)
   - [3.1 路徑參數（Path）與型別約束](#31-路徑參數path與型別約束)
   - [3.2 查詢參數（Query）與分頁機制](#32-查詢參數query與分頁機制)
   - [3.3 模組化路由結構：APIRouter 企業目錄組織](#33-模組化路由結構apirouter-企業目錄組織)
4. [FastAPI 靈魂核心：依賴注入系統（Depends）](#4-fastapi-靈魂核心依賴注入系統depends)
   - [4.1 什麼是依賴注入？IoC 控制反轉解耦思維](#41-什麼是依賴注入ioc-控制反轉解耦思維)
   - [4.2 資料庫 Session 注入器設計模式](#42-資料庫-session-注入器設計模式)
   - [4.3 權限與 API-Key 安全驗證依賴項](#43-權限與-api-key-安全驗證依賴項)
5. [全域例外處理器與企業統一 API 響應結構](#5-全域例外處理器與企業統一-api-響應結構)
6. [商業情境綜合練習題（含詳解）](#6-商業情境綜合練習題含詳解)

---

## 1. 現代後端技術演進：為什麼 FastAPI 取代了傳統框架？

### 1.1 WSGI vs ASGI 底層通訊架構對比

過去十餘年間，Python Web 開發以 Django 與 Flask 為主，遵循 **WSGI（Web Server Gateway Interface, PEP 3333）** 標準：
- **同步阻塞模型（Synchronous & Blocking）**：每個連線請求佔用一個工作行程/執行緒（Worker Thread）。當請求在等待資料庫查詢或外部 API 時，該執行緒會被完全卡死（Block），無法處理下一個請求。
- **高併發瓶頸**：當同時有 1,000 個連線進入時，伺服器必須開 1,000 個執行緒，造成龐大的 Context Switch 開銷與記憶體枯竭。

現代 FastAPI 全面擁抱 **ASGI（Asynchronous Server Gateway Interface）** 標準（搭配 Uvicorn 伺服器）：
- **非同步事件循環（Async Event Loop）**：單一執行緒內可同時維護數萬個活躍連線（Concurrent Connections）。當某個連線在等待 I/O 時，CPU 立即切換去處理其他連線的運算，達到極致的吞吐量。

```
WSGI (Flask / Django 同步):
Request 1: [==處理==][......等待資料庫 50ms......][==返回==] (佔用 Thread 1)
Request 2: -----------> [必須排隊等待 Thread 釋放...]

ASGI (FastAPI + Uvicorn 非同步):
Thread 1:  [R1 開始] -> [R1 等待 DB] -> [立即處理 R2] -> [R1 完成返回] -> [R2 完成返回]
```

### 1.2 FastAPI 兩大基石：Starlette 與 Pydantic v2

- **Starlette**：提供極速的非同步 HTTP 路由、Websocket 支援與 Middleware 中介軟體層。
- **Pydantic v2**：其核心驗證邏輯完全以 **Rust 語言重寫**，資料校驗與序列化效能相較 v1 暴增 5 到 15 倍。
- **自動化 OpenAPI (Swagger) 文檔**：透過 Python Type Hints，FastAPI 自動推導出完整的 OpenAPI 規範，開發者**無需手寫任何一行 API 文檔**即可在 `/docs` 享有即時互動式測試介面。

---

## 2. 非同步並行核心心智模型：async def vs def

這是轉職工程師面試中必被「靈魂拷問」的技術細節。

### 2.1 Event Loop 事件循環運行機制

Node.js 與 Python Asyncio 的核心思想相同：單執行緒事件循環。
當你在程式碼中使用 `await some_async_io()` 時，程式會暫停該協程（Coroutine），並將執行權交還給 Event Loop，由 Event Loop 排程其他已就緒的任務。

### 2.2 什麼時候該用 async def？什麼時候用一般 def？

| 宣告方式 | FastAPI 內部執行方式 | 適用情境 |
| :--- | :--- | :--- |
| **`async def`** | 直接由主執行緒的 **Event Loop** 執行 | **真正支援非同步的非阻塞操作**：<br>- `await httpx.AsyncClient().get(...)`<br>- `await asyncpg.connect(...)`<br>- 非同步 Redis / Celery |
| **一般 `def`** | FastAPI 自動將該函式放進外部的 **獨立執行緒池（ThreadPoolExecutor）** 執行 | **傳統同步阻塞函式**：<br>- 原生 `psycopg2` 查詢<br>- 同步 `SQLAlchemy` ORM 操作<br>- `requests.get(...)`<br>- 大量運算（如 Pandas 清洗、圖片處理） |

---

### 2.3 致命陷阱：在 async 函式中呼叫阻塞式代碼

⚠️ **這是新人最容易搞垮伺服器的災難性錯誤！**

```python
# 致命錯誤示範！
@app.get("/api/v1/bad-endpoint")
async def bad_endpoint():
    # 在 async 函式中執行了同步阻塞操作 (例如 time.sleep 或 psycopg2 同步查詢)
    time.sleep(5)  # 這行會把整個伺服器的 Event Loop 凍結 5 秒！
    # 這 5 秒內，全公司所有其他用戶的所有請求全都無法被處理！
    return {"message": "done"}

# 正確寫法 A：若使用同步庫，宣告為一般 def
@app.get("/api/v1/good-sync-endpoint")
def good_sync_endpoint():
    # FastAPI 自動將其派發至 ThreadPool，完全不影響主 Event Loop
    time.sleep(5) 
    return {"message": "done"}

# 正確寫法 B：若宣告為 async def，內部一律使用 non-blocking await
@app.get("/api/v1/good-async-endpoint")
async def good_async_endpoint():
    await asyncio.sleep(5)  # 釋放控制權，其他連線順暢運行
    return {"message": "done"}
```

---

## 3. RESTful 路由設計與參數解析全攻略

### 3.1 路徑參數（Path）與型別約束

FastAPI 自動根據型別標註進行型別轉換與校驗，若客戶端傳入非法格式，自動回傳 `422 Unprocessable Entity`：

```python
from fastapi import FastAPI, Path

app = FastAPI(title="B2B ERP System API", version="1.0.0")

@app.get("/api/v1/customers/{customer_id}")
def get_customer_by_id(
    customer_id: str = Path(
        ..., 
        description="客戶專屬唯一識別碼",
        regex=r"^CUST_[0-9]{3,6}$", # 正則表達式校驗格式 (如 CUST_001)
        example="CUST_001"
    )
):
    return {"customer_id": customer_id, "company_name": "台積電商務"}
```

---

### 3.2 查詢參數（Query）與分頁機制

查詢參數通常用於篩選、排序與分頁：

```python
from typing import Optional
from fastapi import Query

@app.get("/api/v1/orders")
def list_orders(
    page: int = Query(1, ge=1, description="頁碼，從 1 開始"),
    page_size: int = Query(20, ge=1, le=100, description="每頁筆數，上限 100 筆"),
    status: Optional[str] = Query(None, regex="^(PENDING|APPROVED|SHIPPED|CANCELLED)$", description="訂單狀態"),
    min_amount: Optional[float] = Query(None, ge=0, description="最低訂單金額")
):
    offset = (page - 1) * page_size
    # 根據參數拼接 SQL 或 ORM 查詢
    return {
        "page": page,
        "page_size": page_size,
        "filter": {"status": status, "min_amount": min_amount},
        "offset": offset
    }
```

---

### 3.3 模組化路由結構：APIRouter 企業目錄組織

大型專案不可能把所有端點塞在一個 `main.py` 裡。標準企業目錄架構：

```
b2b_fastapi_app/
├── app/
│   ├── main.py                # 應用實例建立、中介軟體、全域設定
│   ├── core/                  # 系統設定檔 config.py, 安全 security.py
│   ├── db/                    # 資料庫連線 session.py, models.py
│   ├── schemas/               # Pydantic 驗證模型
│   ├── api/                   # API 路由層
│   │   ├── v1/
│   │   │   ├── api_router.py  # 彙整所有子路由
│   │   │   └── endpoints/
│   │   │       ├── customers.py
│   │   │       ├── orders.py
│   │   │       └── products.py
│   └── services/              # 商業邏輯層
└── tests/
```

#### 在子模組中使用 APIRouter
```python
# app/api/v1/endpoints/orders.py
from fastapi import APIRouter

router = APIRouter(prefix="/orders", tags=["B2B 訂單管理模組"])

@router.get("/")
def get_orders():
    return [{"order_id": "ORD_001", "amount": 50000}]

@router.post("/")
def create_order():
    return {"status": "created"}
```

#### 在主路由中統一掛載
```python
# app/main.py
from fastapi import FastAPI
from app.api.v1.endpoints import orders, customers

app = FastAPI(title="B2B Microservice")

# 掛載模組化路由
app.include_router(orders.router, prefix="/api/v1")
app.include_router(customers.router, prefix="/api/v1")
```

---

## 4. FastAPI 靈魂核心：依賴注入系統（Depends）

### 4.1 什麼是依賴注入？IoC 控制反轉解耦思維

當你的端點需要「資料庫連線」、「解析當前登入使用者」、「檢查 API Token 權限」時：
- **糟糕作法**：在每個端點函式內部重複撰寫連線建立、關閉與權限校驗代碼。
- **優雅作法**：透過 FastAPI 的 `Depends`，由框架在呼叫端點前**自動準備好依賴物件**，並在請求結束後**自動執行清理資源**（如釋放連線回連線池）。

---

### 4.2 資料庫 Session 注入器設計模式

結合生成器（Generator）與 `yield`，FastAPI 能確保每次 HTTP 請求分配獨立 Session，並在請求結束（無論成功或拋出異常）自動關閉：

```python
from typing import Generator
from fastapi import Depends
from sqlalchemy.orm import Session
from app.db.session import SessionLocal

def get_db() -> Generator[Session, None, None]:
    """資料庫工作單元依賴項：生命週期與單次 HTTP 請求精確綁定"""
    db = SessionLocal()
    try:
        yield db
        # 請求順利完成時不在此 commit，由 service 明確控制
    finally:
        db.close() # 保證連線一定歸還連線池，防範連線池耗盡！

@app.get("/api/v1/customers")
def list_customers(db: Session = Depends(get_db)):
    # 直接使用乾淨的 db 物件
    customers = db.query(Customer).limit(10).all()
    return customers
```

---

### 4.3 權限與 API-Key 安全驗證依賴項

```python
from fastapi import Security, HTTPException, status
from fastapi.security.api_key import APIKeyHeader

API_KEY_NAME = "X-B2B-API-KEY"
api_key_header = APIKeyHeader(name=API_KEY_NAME, auto_error=False)

VALID_API_KEYS = {"enterprise-secret-key-9988", "partner-token-1122"}

def verify_api_key(api_key: str = Security(api_key_header)):
    """安全檢驗依賴項：未授權請求直接阻擋於 Router 之外"""
    if not api_key or api_key not in VALID_API_KEYS:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="無效或缺失之 X-B2B-API-KEY 憑證，拒絕訪問！"
        )
    return api_key

# 套用至敏感端點
@app.delete("/api/v1/orders/{order_id}", dependencies=[Depends(verify_api_key)])
def cancel_order(order_id: str):
    return {"message": f"訂單 {order_id} 已成功註銷"}
```

---

## 5. 全域例外處理器與企業統一 API 響應結構

前端或外部串接團隊最痛恨的事情，是 API 一下回傳 JSON、一下回傳 HTML 報錯字串、一下回傳 500 堆疊資訊。
我們需要建立**全域異常攔截器**，規範統一的回應格式：

```python
from fastapi import Request, status
from fastapi.responses import JSONResponse

class B2BBusinessException(Exception):
    """自定義商業邏輯異常"""
    def __init__(self, message: str, error_code: str = "BIZ_RULE_VIOLATION"):
        self.message = message
        self.error_code = error_code

@app.exception_handler(B2BBusinessException)
async def business_exception_handler(request: Request, exc: B2BBusinessException):
    """將自定義業務例外統一轉換為標準 400 JSON 回應"""
    return JSONResponse(
        status_code=status.HTTP_400_BAD_REQUEST,
        content={
            "success": False,
            "error_code": exc.error_code,
            "message": exc.message,
            "path": str(request.url.path)
        }
    )

@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    """全域 500 錯誤兜底：防禦性避免伺服器敏感日誌洩漏給外界"""
    # 這裡打系統日誌: logger.critical(...)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "success": False,
            "error_code": "INTERNAL_SERVER_ERROR",
            "message": "系統內部發生非預期錯誤，維運團隊已接獲通報。",
            "path": str(request.url.path)
        }
    )
```

---

## 6. 商業情境綜合練習題（含詳解）

### 題目一：設計分頁、金額區間與狀態複合過濾的訂單查詢 API
**業務情境**：
請在 `endpoints/orders.py` 中實作一個 GET 端點 `/api/v1/orders/search`：
1. 支援查詢參數：`page`（預設 1）、`limit`（預設 10, 上限 50）、`status`（可選枚舉值：`PENDING`, `APPROVED`, `CANCELLED`）、`min_total`（可選浮點數）、`max_total`（可選浮點數）。
2. 若 `min_total` 大於 `max_total`，端點必須主動拋出 400 錯誤並說明原因。
3. 注入資料庫 Session 依賴項 `get_db`。
4. 返回結果必須包含總筆數 `total`、當前頁碼 `page`、以及資料列表 `items`。

#### 【題目一解答程式碼】
```python
from typing import Optional, List
from fastapi import APIRouter, Depends, Query, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import select, func, and_

router = APIRouter(prefix="/orders", tags=["訂單模組"])

@router.get("/search")
def search_orders(
    page: int = Query(1, ge=1, description="頁碼"),
    limit: int = Query(10, ge=1, le=50, description="每頁筆數"),
    status: Optional[str] = Query(None, regex="^(PENDING|APPROVED|CANCELLED)$"),
    min_total: Optional[float] = Query(None, ge=0),
    max_total: Optional[float] = Query(None, ge=0),
    db: Session = Depends(get_db)
):
    # 商業邏輯檢驗
    if min_total is not None and max_total is not None and min_total > max_total:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="參數錯誤：最低金額 min_total 不得大於最高金額 max_total！"
        )
        
    # 動態建構查詢條件
    filters = []
    if status:
        filters.append(Order.status == status)
    if min_total is not None:
        filters.append(Order.total_amount >= min_total)
    if max_total is not None:
        filters.append(Order.total_amount <= max_total)
        
    base_query = select(Order).where(and_(*filters))
    
    # 計算符合條件之總筆數
    count_query = select(func.count()).select_from(base_query.subquery())
    total_count = db.scalar(count_query) or 0
    
    # 分頁切片查詢
    offset = (page - 1) * limit
    paginated_query = base_query.order_by(Order.order_date.desc()).offset(offset).limit(limit)
    orders = db.scalars(paginated_query).all()
    
    return {
        "success": True,
        "pagination": {
            "page": page,
            "limit": limit,
            "total_records": total_count,
            "total_pages": (total_count + limit - 1) // limit
        },
        "data": orders
    }
```

---

### 題目二：實作具備 RBAC 角色權限檢查的自定義依賴項
**業務情境**：
公司 API 分為不同操作角色：`VIEWER`（只讀）、`OPERATOR`（可建立更新）、`ADMIN`（可刪除）。
請實作一個工廠式相依性函式 `require_role(allowed_roles: List[str])`：
- 從請求 Header `X-User-Role` 讀取發起者的角色。
- 若角色不在 `allowed_roles` 之中，立即拋出 `403 Forbidden`。

#### 【題目二解答程式碼】
```python
from typing import List
from fastapi import Header, HTTPException, status, Depends

def require_role(allowed_roles: List[str]):
    """角色彩工廠依賴項 (Role-Based Access Control)"""
    def role_checker(x_user_role: str = Header(..., description="操作者角色")) -> str:
        if x_user_role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"權限不足！此操作僅限角色 [{', '.join(allowed_roles)}] 執行，當前角色為: {x_user_role}"
            )
        return x_user_role
    return role_checker

# 套用範例：只有 ADMIN 才能執行永久刪除客戶
@router.delete("/customers/{customer_id}", dependencies=[Depends(require_role(["ADMIN"]))])
def purge_customer(customer_id: str, db: Session = Depends(get_db)):
    return {"message": f"客戶 {customer_id} 已由管理員永久自系統移除。"}
```

---

### 題目三：整合全域健康檢查端點與資料庫探活（Liveness & Readiness Probe）
**業務情境**：
在雲端容器環境（如 Kubernetes、Render、AWS ECS）中，維運系統會每 10 秒發送探活請求。
若資料庫斷線，健康檢查端點必須返回 HTTP 503 Service Unavailable，通知負載平衡器暫停將流量分發至該實例。
請撰寫一個標準的 `/healthz` 端點。

#### 【題目三解答程式碼】
```python
from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.orm import Session
from sqlalchemy import text

router = APIRouter(tags=["系統探活監控"])

@router.get("/healthz")
def health_check(response: Response, db: Session = Depends(get_db)):
    """
    K8s / 負載平衡器探針專用端點
    執行 SELECT 1 心跳檢測
    """
    health_status = {
        "status": "UP",
        "database": "CONNECTED",
        "timestamp": datetime.utcnow().isoformat()
    }
    
    try:
        # 發送輕量心跳查詢
        db.execute(text("SELECT 1;"))
        response.status_code = status.HTTP_200_OK
    except Exception as e:
        health_status["status"] = "DOWN"
        health_status["database"] = f"DISCONNECTED: {str(e)}"
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        
    return health_status
```
