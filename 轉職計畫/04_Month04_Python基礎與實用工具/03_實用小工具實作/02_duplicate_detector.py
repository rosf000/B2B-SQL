"""
Tool 2: 重複資料檢查與相似度比對工具 (Duplicate Detector)
解決痛點：
1. 業務手殘建立類似名稱客戶 (例如 "台積電" vs "台灣積體電路製造股份有限公司")
2. 統編相同但公司名略有差異的重複建檔
3. 自動識別並輸出重複可疑名單
"""

from typing import List, Dict, Set
from difflib import SequenceMatcher
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


def similarity_ratio(a: str, b: str) -> float:
    """計算兩字串的相似度 (0.0 ~ 1.0)。"""
    return SequenceMatcher(None, a.strip().lower(), b.strip().lower()).ratio()

def find_duplicates(records: List[Dict[str, str]], sim_threshold: float = 0.75) -> Dict[str, List[Dict]]:
    """比對統編精確重複與公司名稱高度相似的紀錄。"""
    seen_tax_ids: Dict[str, Dict] = {}
    exact_duplicates = []
    fuzzy_duplicates = []

    # 1. 精確比對統編
    for rec in records:
        tax_id = rec.get("tax_id")
        if tax_id:
            if tax_id in seen_tax_ids:
                exact_duplicates.append({
                    "original": seen_tax_ids[tax_id],
                    "duplicate": rec,
                    "reason": f"統編相同: {tax_id}"
                })
            else:
                seen_tax_ids[tax_id] = rec

    # 2. 名稱模糊相似度比對
    n = len(records)
    for i in range(n):
        for j in range(i + 1, n):
            name_a = records[i].get("company_name", "")
            name_b = records[j].get("company_name", "")
            ratio = similarity_ratio(name_a, name_b)
            if ratio >= sim_threshold and records[i].get("tax_id") != records[j].get("tax_id"):
                fuzzy_duplicates.append({
                    "record_a": records[i],
                    "record_b": records[j],
                    "similarity": round(ratio, 2)
                })

    return {
        "exact_tax_id_duplicates": exact_duplicates,
        "fuzzy_name_duplicates": fuzzy_duplicates
    }

def run_demo():
    print("=== [Tool 2] 重複資料檢查工具啟動 ===")
    sample_records = [
        {"customer_id": 1, "company_name": "Apex Semiconductor Co., Ltd.", "tax_id": "28491023"},
        {"customer_id": 2, "company_name": "Apex Semiconductor Taiwan", "tax_id": "99887766"},
        {"customer_id": 3, "company_name": "Apex Semi Tech", "tax_id": "28491023"}, # 統編重複
        {"customer_id": 4, "company_name": "BlueSky Cloud Systems", "tax_id": "54329871"},
        {"customer_id": 5, "company_name": "CyberCore Technologies", "tax_id": "12984736"}
    ]

    report = find_duplicates(sample_records, sim_threshold=0.7)
    print(f"發現統編重複筆數: {len(report['exact_tax_id_duplicates'])}")
    for item in report["exact_tax_id_duplicates"]:
        print(f"  🚨 {item['reason']} -> {item['original']['company_name']} 與 {item['duplicate']['company_name']}")

    print(f"發現高度疑似重複筆數: {len(report['fuzzy_name_duplicates'])}")
    for item in report["fuzzy_name_duplicates"]:
        print(f"  ⚠️ 相似度 {item['similarity']*100}%: {item['record_a']['company_name']} vs {item['record_b']['company_name']}")

if __name__ == "__main__":
    run_demo()
