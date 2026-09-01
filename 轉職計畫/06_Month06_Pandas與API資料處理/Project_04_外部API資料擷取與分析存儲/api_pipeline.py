"""
外部 REST API 擷取、Pandas 清洗與入庫管線
示範：擷取開放 JSON API (以 JSONPlaceholder 模擬企業外部供應商/客戶資料)，
清洗後計算衍生指標並存入 PostgreSQL。
"""

import requests
import pandas as pd
from sqlalchemy import create_engine
import os

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql+psycopg2://postgres:postgres123@localhost:5432/b2b_db")
engine = create_engine(DATABASE_URL)

def fetch_external_partners() -> list:
    """模擬從外部供應商/客戶 API 抓取資料。"""
    url = "https://jsonplaceholder.typicode.com/users"
    print(f"正在從 {url} 抓取外部合作夥伴資料...")
    try:
        resp = requests.get(url, timeout=10)
        resp.raise_for_status()
        return resp.json()
    except Exception as e:
        print(f"API 請求失敗: {e}，改用內建模擬資料...")
        return [
            {"id": 1, "name": "Leanne Graham", "username": "Bret", "email": "Sincere@april.biz", "address": {"city": "Gwenborough"}, "phone": "1-770-736-8031", "company": {"name": "Romaguera-Crona"}},
            {"id": 2, "name": "Ervin Howell", "username": "Antonette", "email": "Shanna@melissa.tv", "address": {"city": "Wisokyburgh"}, "phone": "010-692-6593", "company": {"name": "Deckow-Crist"}}
        ]

def transform_data(raw_data: list) -> pd.DataFrame:
    """使用 Pandas 扁平化巢狀欄位並標準化。"""
    # 扁平化 address 與 company 巢狀字典
    df = pd.json_normalize(raw_data)
    
    # 選取並重新命名欄位
    cleaned_df = pd.DataFrame({
        "external_id": df["id"],
        "contact_name": df["name"].str.strip(),
        "email": df["email"].str.lower().str.strip(),
        "city": df["address.city"].str.strip(),
        "company_name": df["company.name"].str.strip(),
        "raw_phone": df["phone"]
    })
    
    cleaned_df["imported_at"] = pd.Timestamp.now()
    return cleaned_df

def save_to_db(df: pd.DataFrame):
    """將 DataFrame 存入 PostgreSQL。"""
    table_name = "external_partners"
    try:
        df.to_sql(table_name, engine, if_exists="replace", index=False)
        print(f"✅ 成功將 {len(df)} 筆外部資料寫入資料表 `{table_name}`！")
    except Exception as e:
        print(f"⚠️ 資料庫寫入提示 (請確認 Postgres 服務是否啟動): {e}")

def run():
    raw_json = fetch_external_partners()
    df = transform_data(raw_json)
    print("轉換後 DataFrame 預覽：")
    print(df.head())
    save_to_db(df)

if __name__ == "__main__":
    run()
