"""
生成用於測試 ETL 管線的模擬客戶 CSV 檔（包含故意設計的髒資料、空白、統編錯誤與正常資料）
"""

import pandas as pd
from config import INCOMING_DIR

def generate_mock_incoming_file():
    mock_records = [
        {"company_name": "  Apex Global Solutions  ", "tax_id": "28491023", "industry": "Software", "city": "Taipei", "credit_limit": "800000"},
        {"company_name": "BlueSky Data Systems", "tax_id": "54329871", "industry": "Cloud", "city": "Hsinchu", "credit_limit": "450000"},
        {"company_name": "Dirty Record Missing Tax", "tax_id": "ABC1234", "industry": "Unknown", "city": "Taichung", "credit_limit": "100000"}, # 統編錯誤
        {"company_name": "Quantum Precision", "tax_id": "98765432", "industry": "Manufacturing", "city": "Tainan", "credit_limit": "1200000"},
        {"company_name": "  ", "tax_id": "11223344", "industry": "Retail", "city": "Kaohsiung", "credit_limit": "50000"} # 空白公司名
    ]
    
    df = pd.DataFrame(mock_records)
    target_csv = INCOMING_DIR / "weekly_customer_upload_01.csv"
    df.to_csv(target_csv, index=False, encoding="utf-8-sig")
    print(f"✅ 已成功生成測試資料檔案: {target_csv.name}")

if __name__ == "__main__":
    generate_mock_incoming_file()
