# 01 SQLAlchemy 2.0 與 psycopg2 資料庫連線實務

## 一、psycopg2 參數化查詢（防範 SQL 注入）

切記：**絕對不要用 Python 的 `f-string` 或 `%s` 直接拼接 SQL 字串！**

### ❌ 致命危險寫法 (SQL Injection 漏洞)
```python
# 若 user_input 為 "'; DROP TABLE customers; --"
query = f"SELECT * FROM customers WHERE company_name = '{user_input}'"
cursor.execute(query) # 資料庫表被刪除！
```

### ✅ 安全參數化綁定寫法
```python
query = "SELECT * FROM customers WHERE company_name = %s AND status = %s"
cursor.execute(query, (user_input, "ACTIVE")) # 安全轉義處理
```

---

## 二、SQLAlchemy 2.0 連線與 Engine 範例

安裝依賴：
```bash
pip install sqlalchemy psycopg2-binary python-dotenv
```

```python
import os
from sqlalchemy import create_engine, text
from sqlalchemy.orm import declarative_base, sessionmaker

# 建議從環境變數讀取，避免硬編碼帳密
DB_URL = os.getenv("DATABASE_URL", "postgresql+psycopg2://postgres:postgres123@localhost:5432/b2b_db")

engine = create_engine(DB_URL, pool_size=10, max_overflow=20)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def test_connection():
    with engine.connect() as conn:
        result = conn.execute(text("SELECT version();"))
        print(f"Connected to DB: {result.fetchone()[0]}")

if __name__ == "__main__":
    test_connection()
```
