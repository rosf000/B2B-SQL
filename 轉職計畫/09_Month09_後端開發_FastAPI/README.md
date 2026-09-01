# Month 09｜後端開發：使用 FastAPI 將 B2B 系統 API 化

> **本月核心目標**：從單純的資料腳本跨入「現代 Web 後端服務」，使用 Python 當紅的高效能非同步框架 FastAPI，為 Month 8 的 B2B 客戶與訂單數據系統構建標準 RESTful API，並利用自動產生的 Swagger UI 進行互動式測試。

---

## 🎯 本月技能檢核清單

- [ ] 理解 Client-Server 架構與 RESTful 設計規範
- [ ] 掌握 FastAPI 路由宣告 (`@app.get`, `@app.post`, `@app.put`, `@app.delete`)
- [ ] 掌握 Pydantic 2.0 進行請求資料驗證 (Validation) 與回傳格式定義 (Response Model)
- [ ] 掌握 HTTP 狀態碼與自訂例外拋出 (`HTTPException`)
- [ ] 掌握 SQLAlchemy ORM 與 FastAPI Dependency Injection (`Depends(get_db)`)
- [ ] 掌握自動化 API 文件 Swagger UI (`/docs`) 與 ReDoc (`/redoc`)
- [ ] 實作完整的客戶與訂單 CRUD (Create, Read, Update, Delete) 端點

---

## 📂 本模組教材與應用程式導航

1. [01_RESTful_API設計與FastAPI快速上手.md](./01_RESTful_API設計與FastAPI快速上手.md)
   - REST 原則、非同步 async/await 概念與路徑參數/查詢參數。
2. [02_Pydantic資料驗證與CRUD實作.md](./02_Pydantic資料驗證與CRUD實作.md)
   - BaseModel 宣告、Field 驗證規則、Schema 與 ORM 映射轉換。
3. [b2b_fastapi_app/](./b2b_fastapi_app/)
   - 完整的生產級 FastAPI 專案代碼（含 `main.py`, `models.py`, `schemas.py`, `crud.py`, `database.py`）。
