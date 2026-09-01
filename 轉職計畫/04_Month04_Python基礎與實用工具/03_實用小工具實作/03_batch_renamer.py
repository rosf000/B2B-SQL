"""
Tool 3: 檔案批次重新命名與分類歸檔工具 (Batch File Renamer)
解決痛點：
1. 公司下載的大量合約/發票檔名雜亂 (例如 "scan_0012.pdf", "download (1).pdf")
2. 自動依照「日期_客戶名_單號.pdf」規範統一命名
3. 自動建立年度/月份資料夾並移動歸檔
"""

import os
import shutil
import re
import sys
from pathlib import Path
from typing import List, Dict

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


def parse_and_standardize_filename(old_name: str, meta: Dict[str, str]) -> str:
    """依照標準格式格式化檔案名稱: YYYYMMDD_[Customer]_[DocType]_[DocID].ext"""
    ext = Path(old_name).suffix
    date_str = meta.get("date", "20240101").replace("-", "")
    customer = meta.get("customer", "UnknownCust").replace(" ", "_")
    doc_type = meta.get("doc_type", "DOC")
    doc_id = meta.get("doc_id", "000")
    return f"{date_str}_{customer}_{doc_type}_{doc_id}{ext}"

def batch_organize_files(source_dir: str, target_dir: str, file_mappings: List[Dict[str, str]], dry_run: bool = True):
    """
    批次處理檔案重新命名與分類歸檔。
    dry_run=True 代表僅印出預覽，不實際移動檔案，安全防呆。
    """
    print(f"=== 批次歸檔作業模式: {'【模擬預覽 DRY-RUN】' if dry_run else '【正式執行】'} ===")
    
    for item in file_mappings:
        src_filename = item["source_filename"]
        new_filename = parse_and_standardize_filename(src_filename, item)
        
        # 依年度與月份自動建立目錄結構: target_dir / 2024 / 07 /
        year = item.get("date", "2024-01-01")[:4]
        month = item.get("date", "2024-01-01")[5:7]
        dest_folder = Path(target_dir) / year / month
        dest_filepath = dest_folder / new_filename
        
        print(f"  [規劃] {src_filename} ➜ {dest_filepath}")
        
        if not dry_run:
            dest_folder.mkdir(parents=True, exist_ok=True)
            src_path = Path(source_dir) / src_filename
            if src_path.exists():
                shutil.copy2(src_path, dest_filepath)
                print(f"    ✅ 歸檔成功: {dest_filepath.name}")

def run_demo():
    print("=== [Tool 3] 檔案批次重新命名與歸檔工具啟動 ===")
    mock_mappings = [
        {"source_filename": "scan_contract_01.pdf", "date": "2024-07-15", "customer": "Apex Semi", "doc_type": "CONTRACT", "doc_id": "CNT001"},
        {"source_filename": "invoice_tmp_99.pdf", "date": "2024-07-20", "customer": "BlueSky Cloud", "doc_type": "INV", "doc_id": "INV0701"},
        {"source_filename": "quote_draft.pdf", "date": "2024-08-01", "customer": "CyberCore", "doc_type": "QUOTE", "doc_id": "Q2024A"}
    ]
    batch_organize_files("./temp_incoming", "./archive_docs", mock_mappings, dry_run=True)

if __name__ == "__main__":
    run_demo()
