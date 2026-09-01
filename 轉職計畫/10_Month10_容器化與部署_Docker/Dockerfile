# 使用輕量級官方 Python 基礎映像檔
FROM python:3.11-slim

# 設定工作目錄
WORKDIR /app

# 設定環境變數：防止 Python 產生 .pyc 快取檔並開啟未緩衝輸出 (即時印出 log)
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# 安裝系統層級依賴 (psycopg2 構建所需之 libpq)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# 複製依賴清單並安裝
COPY ../09_Month09_後端開發_FastAPI/b2b_fastapi_app/requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# 複製應用程式代碼
COPY ../09_Month09_後端開發_FastAPI/b2b_fastapi_app/ /app/

# 開放 FastAPI 埠號
EXPOSE 8000

# 啟動命令
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
