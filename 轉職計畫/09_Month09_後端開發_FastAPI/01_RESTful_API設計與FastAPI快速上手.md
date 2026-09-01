# 01 RESTful API 設計原則與 FastAPI 快速上手

## 一、RESTful API 端點設計規範

以 B2B 客戶資源為例，遵循語意化的 HTTP 動詞：

| 動作 | HTTP 方法 | URI 路由 | 預期狀態碼 |
| :--- | :--- | :--- | :--- |
| 獲取所有客戶清單 (支援分頁) | `GET` | `/api/v1/customers?skip=0&limit=10` | 200 OK |
| 獲取單一指定客戶詳情 | `GET` | `/api/v1/customers/{customer_id}` | 200 OK / 404 |
| 建立新客戶 | `POST` | `/api/v1/customers` | 201 Created |
| 更新現有客戶全部/部分資料 | `PUT / PATCH` | `/api/v1/customers/{customer_id}` | 200 OK |
| 停用或刪除客戶 | `DELETE` | `/api/v1/customers/{customer_id}` | 204 No Content |

---

## 二、FastAPI 極簡 Hello World

```python
from fastapi import FastAPI

app = FastAPI(title="B2B Customer API", version="1.0.0")

@app.get("/")
def read_root():
    return {"message": "Welcome to B2B Data API", "status": "healthy"}

@app.get("/health")
def health_check():
    return {"status": "ok"}
```

啟動伺服器：
```bash
uvicorn main:app --reload --port 8000
```
打開瀏覽器查看自動生成的互動式文檔：`http://127.0.0.1:8000/docs`
