import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
INCOMING_DIR = BASE_DIR / "incoming_data"
ARCHIVE_DIR = BASE_DIR / "archive_data"
ERROR_DIR = BASE_DIR / "error_reports"

# 確保資料夾存在
INCOMING_DIR.mkdir(exist_ok=True)
ARCHIVE_DIR.mkdir(exist_ok=True)
ERROR_DIR.mkdir(exist_ok=True)

DATABASE_URL = os.getenv(
    "DATABASE_URL", 
    "postgresql+psycopg2://postgres:postgres123@localhost:5432/b2b_db"
)
