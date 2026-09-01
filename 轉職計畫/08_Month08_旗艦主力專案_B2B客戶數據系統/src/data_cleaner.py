"""
B2B 客戶去重與資料品質清洗演算法 (Customer Hygiene & Fuzzy Deduplication)
"""

import re
import sys
from typing import List, Dict
from difflib import SequenceMatcher

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


def normalize_company_name(name: str) -> str:
    """去除公司名稱常見法定稱謂，取得純核心商業字串。"""
    cleaned = name.lower().strip()
    suffixes = [
        "股份有限公司", "有限公司", "科技", "企業", "集團", "台灣", 
        "co., ltd.", "corp.", "inc.", "ltd.", "llc"
    ]
    for s in suffixes:
        cleaned = cleaned.replace(s, "")
    return re.sub(r"[^\w\s]", "", cleaned).strip()

def calculate_name_similarity(name1: str, name2: str) -> float:
    """計算正規化後的名稱相似度。"""
    norm1 = normalize_company_name(name1)
    norm2 = normalize_company_name(name2)
    return SequenceMatcher(None, norm1, norm2).ratio()

def audit_customer_records(records: List[Dict]) -> Dict:
    """全面審計客戶清單：找出統編衝突與名稱高度疑似重複者。"""
    seen_tax_map = {}
    tax_conflicts = []
    fuzzy_matches = []

    for rec in records:
        tax = rec.get("tax_id")
        if tax and tax in seen_tax_map:
            tax_conflicts.append({
                "original": seen_tax_map[tax],
                "duplicate": rec,
                "reason": "統編完全相同"
            })
        elif tax:
            seen_tax_map[tax] = rec

    n = len(records)
    for i in range(n):
        for j in range(i + 1, n):
            if records[i].get("tax_id") != records[j].get("tax_id"):
                sim = calculate_name_similarity(records[i]["company_name"], records[j]["company_name"])
                if sim >= 0.75:
                    fuzzy_matches.append({
                        "company_a": records[i]["company_name"],
                        "company_b": records[j]["company_name"],
                        "similarity_score": round(sim, 2)
                    })

    return {
        "tax_conflicts_count": len(tax_conflicts),
        "fuzzy_matches_count": len(fuzzy_matches),
        "tax_conflicts": tax_conflicts,
        "fuzzy_matches": fuzzy_matches
    }

if __name__ == "__main__":
    test_data = [
        {"customer_id": 101, "company_name": "Apex Semiconductor Inc", "tax_id": "28491023"},
        {"customer_id": 102, "company_name": "Apex Semi Taiwan Co.", "tax_id": "99112233"},
        {"customer_id": 103, "company_name": "Apex Semiconductor 股份有限公司", "tax_id": "28491023"},
        {"customer_id": 104, "company_name": "BlueSky Cloud Systems", "tax_id": "54329871"}
    ]
    
    report = audit_customer_records(test_data)
    print("=== 客戶資料庫去重審計結果 ===")
    print(f"統編衝突數: {report['tax_conflicts_count']}")
    print(f"名稱高度疑似重複數: {report['fuzzy_matches_count']}")
    for fm in report["fuzzy_matches"]:
        print(f"  [疑似重複] {fm['company_a']} <==> {fm['company_b']} (相似度: {fm['similarity_score']})")
