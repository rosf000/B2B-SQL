"""
Tool 1: Excel / CSV 商業資料欄位清洗與格式化工具 (Excel Organizer)
解決痛點：
1. 去除欄位前後多餘空格
2. 統一電話號碼格式 (例如 0912-345-678 或 +886)
3. 統編長度檢查與防呆
4. 自動產出乾淨的 CSV 與清洗摘要報告
"""

import csv
import os
import re
from typing import List, Dict, Tuple

def clean_tax_id(tax_id: str) -> str:
    """清理統編：移除非數字字元並補齊檢查。"""
    digits = re.sub(r"\D", "", tax_id)
    return digits if len(digits) == 8 else "INVALID_TAX_ID"

def clean_phone(phone: str) -> str:
    """標準化台灣手機號碼格式為 09XX-XXX-XXX。"""
    digits = re.sub(r"\D", "", phone)
    if digits.startswith("886"):
        digits = "0" + digits[3:]
    if len(digits) == 10 and digits.startswith("09"):
        return f"{digits[:4]}-{digits[4:7]}-{digits[7:]}"
    return phone.strip()

def process_raw_customer_file(input_rows: List[Dict[str, str]]) -> Tuple[List[Dict[str, str]], Dict[str, int]]:
    """清洗整批客戶資料列。"""
    cleaned_rows = []
    stats = {"total": len(input_rows), "valid": 0, "invalid_tax_id": 0}

    for row in input_rows:
        company = row.get("company_name", "").strip()
        tax_id = clean_tax_id(row.get("tax_id", ""))
        phone = clean_phone(row.get("phone", ""))
        city = row.get("city", "").strip().title()

        if tax_id == "INVALID_TAX_ID":
            stats["invalid_tax_id"] += 1

        cleaned_rows.append({
            "company_name": company,
            "tax_id": tax_id,
            "phone": phone,
            "city": city,
            "credit_limit": row.get("credit_limit", "0").strip()
        })
        stats["valid"] += 1

    return cleaned_rows, stats

def run_demo():
    print("=== [Tool 1] Excel/CSV 資料清洗工具啟動 ===")
    sample_data = [
        {"company_name": "  Apex Tech Corp  ", "tax_id": " 2849-1023 ", "phone": "0912345678", "city": "taipei", "credit_limit": "500000"},
        {"company_name": "BlueSky Ltd", "tax_id": "543298", "phone": "886922333444", "city": "hsinchu", "credit_limit": "200000"},
        {"company_name": "CyberCore", "tax_id": "12984736", "phone": "02-23456789", "city": "taichung", "credit_limit": "300000"}
    ]
    
    cleaned, stats = process_raw_customer_file(sample_data)
    print(f"清洗統計：總數={stats['total']} 筆, 無效統編={stats['invalid_tax_id']} 筆")
    for item in cleaned:
        print("  清洗後結果:", item)

if __name__ == "__main__":
    run_demo()
