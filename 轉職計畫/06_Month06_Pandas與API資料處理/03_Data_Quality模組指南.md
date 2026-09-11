# Data Quality 模組指南

> M6 補強：B2B 資料最常見的問題就是資料品質。這個模組是你旗艦作品的核心元件。

## 什麼是資料品質（Data Quality）？

| 維度 | 說明 | B2B 例子 |
|:---|:---|:---|
| **Completeness** | 必填欄位不能是空的 | 客戶沒有 email / 公司名稱是空的 |
| **Uniqueness** | 不能有重複資料 | 同一家公司有 3 個帳號 |
| **Validity** | 格式必須正確 | email 格式錯誤、電話有中文字 |
| **Consistency** | 跨表資料要一致 | 訂單的 customer_id 在客戶表找不到 |
| **Freshness** | 資料是否過期 | 三年沒更新的聯絡人資料 |

---

## 資料夾結構

```
data_quality/
├── __init__.py
├── validators.py      ← 各種驗證函數
├── cleaners.py        ← 資料清洗函數
├── reports.py         ← 產生品質報告
└── README.md
```

---

## validators.py — 驗證函數庫

```python
"""
data_quality/validators.py
B2B 資料品質驗證函數庫
"""
import re
import pandas as pd
from typing import Tuple


# ─── Email 驗證 ────────────────────────────────────────────────
EMAIL_PATTERN = re.compile(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')

def is_valid_email(email: str) -> bool:
    """驗證 email 格式是否正確"""
    if not isinstance(email, str) or not email.strip():
        return False
    return bool(EMAIL_PATTERN.match(email.strip()))


# ─── 電話驗證 ──────────────────────────────────────────────────
PHONE_PATTERN = re.compile(r'^[\d\-\+\(\)\s]{7,20}$')

def is_valid_phone(phone: str) -> bool:
    """驗證電話格式（允許數字、-、+、()、空白）"""
    if not isinstance(phone, str) or not phone.strip():
        return False
    return bool(PHONE_PATTERN.match(phone.strip()))


# ─── 空值檢查 ──────────────────────────────────────────────────
def check_not_null(value) -> bool:
    """檢查值是否為有效值（非 None、非空字串）"""
    if value is None:
        return False
    if isinstance(value, str) and not value.strip():
        return False
    return True


# ─── 重複資料檢查 ──────────────────────────────────────────────
def check_duplicate(
    df: pd.DataFrame,
    subset: list[str]
) -> Tuple[pd.DataFrame, pd.DataFrame]:
    """
    找出重複資料
    回傳 (unique_df, duplicate_df)
    """
    is_dup = df.duplicated(subset=subset, keep='first')
    return df[~is_dup].copy(), df[is_dup].copy()


# ─── 完整性檢查 ────────────────────────────────────────────────
def check_completeness(
    df: pd.DataFrame,
    required_columns: list[str]
) -> dict:
    """
    檢查必填欄位的完整性
    回傳各欄位的完整率
    """
    report = {}
    total = len(df)
    for col in required_columns:
        if col not in df.columns:
            report[col] = {"completeness": 0.0, "missing_count": total}
            continue
        missing = df[col].isnull().sum() + (df[col] == '').sum()
        report[col] = {
            "completeness": round((total - missing) / total, 4),
            "missing_count": int(missing)
        }
    return report


# ─── 一致性檢查 ────────────────────────────────────────────────
def check_referential_integrity(
    df_child: pd.DataFrame,
    df_parent: pd.DataFrame,
    child_key: str,
    parent_key: str
) -> pd.DataFrame:
    """
    檢查 FK 一致性：child 表的 key 在 parent 表都找得到嗎？
    回傳找不到的記錄
    """
    valid_keys = set(df_parent[parent_key].dropna())
    orphans = df_child[~df_child[child_key].isin(valid_keys)]
    return orphans
```

---

## cleaners.py — 清洗函數庫

```python
"""
data_quality/cleaners.py
B2B 資料清洗函數庫
"""
import re
import pandas as pd


# 常見公司後綴（用於標準化）
COMPANY_SUFFIXES = [
    'co., ltd.', 'co.,ltd.', 'co.ltd.', 'ltd.', 'inc.',
    '股份有限公司', '有限公司', '公司'
]

def normalize_company_name(name: str) -> str:
    """
    標準化公司名稱：
    - 去除前後空白
    - 轉為小寫
    - 去除常見公司後綴
    """
    if not isinstance(name, str):
        return name
    name = name.strip().lower()
    for suffix in COMPANY_SUFFIXES:
        name = name.replace(suffix.lower(), '').strip()
    # 去除多餘空白
    name = re.sub(r'\s+', ' ', name)
    return name


def normalize_email(email: str) -> str:
    """標準化 email：去除空白、轉小寫"""
    if not isinstance(email, str):
        return email
    return email.strip().lower()


def normalize_phone(phone: str) -> str:
    """標準化電話：只保留數字和 +"""
    if not isinstance(phone, str):
        return phone
    return re.sub(r'[^\d+]', '', phone.strip())


def clean_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    """對整個 DataFrame 做基本清洗"""
    df = df.copy()

    # 去除字串欄位的前後空白
    str_columns = df.select_dtypes(include=['object']).columns
    for col in str_columns:
        df[col] = df[col].str.strip()

    # 標準化 email 欄位
    if 'email' in df.columns:
        df['email'] = df['email'].apply(
            lambda x: normalize_email(x) if pd.notna(x) else x
        )

    # 標準化公司名稱
    if 'company_name' in df.columns:
        df['company_name'] = df['company_name'].apply(
            lambda x: normalize_company_name(x) if pd.notna(x) else x
        )

    return df
```

---

## reports.py — 品質報告

```python
"""
data_quality/reports.py
產生資料品質報告
"""
import pandas as pd
from datetime import datetime
from .validators import check_completeness, check_duplicate, is_valid_email


def generate_quality_report(df: pd.DataFrame, required_cols: list[str]) -> dict:
    """
    產生完整的資料品質報告
    """
    total_records = len(df)
    report = {
        "timestamp": datetime.now().isoformat(),
        "total_records": total_records,
        "completeness": check_completeness(df, required_cols),
        "duplicates": {},
        "email_validity": {}
    }

    # 重複資料
    if 'email' in df.columns:
        _, dupes = check_duplicate(df, subset=['email'])
        report["duplicates"]["by_email"] = {
            "count": len(dupes),
            "rate": round(len(dupes) / total_records, 4) if total_records > 0 else 0
        }

    # Email 格式驗證
    if 'email' in df.columns:
        valid_count = df['email'].dropna().apply(is_valid_email).sum()
        invalid_count = total_records - valid_count
        report["email_validity"] = {
            "valid": int(valid_count),
            "invalid": int(invalid_count),
            "valid_rate": round(valid_count / total_records, 4) if total_records > 0 else 0
        }

    return report


def print_quality_report(report: dict) -> None:
    """格式化輸出品質報告"""
    print(f"\n{'='*50}")
    print(f"資料品質報告 — {report['timestamp']}")
    print(f"{'='*50}")
    print(f"總筆數：{report['total_records']}")

    print(f"\n【完整性】")
    for col, stats in report['completeness'].items():
        rate = stats['completeness'] * 100
        status = "✅" if rate >= 95 else "⚠️" if rate >= 80 else "❌"
        print(f"  {status} {col}: {rate:.1f}% ({stats['missing_count']} 筆缺失)")

    if report.get('duplicates'):
        print(f"\n【重複資料】")
        for key, stats in report['duplicates'].items():
            print(f"  重複筆數（{key}）：{stats['count']} 筆（{stats['rate']*100:.1f}%）")

    if report.get('email_validity'):
        stats = report['email_validity']
        print(f"\n【Email 格式】")
        print(f"  有效：{stats['valid']} / 無效：{stats['invalid']}")
    print(f"{'='*50}\n")
```

---

## 使用範例

```python
import pandas as pd
from data_quality.validators import check_completeness, check_duplicate
from data_quality.cleaners import clean_dataframe
from data_quality.reports import generate_quality_report, print_quality_report

# 載入資料
df = pd.read_excel("customers.xlsx")

# 清洗
df_clean = clean_dataframe(df)

# 產生報告
required = ["email", "company_name", "contact_name"]
report = generate_quality_report(df_clean, required)
print_quality_report(report)

# 分離乾淨資料和問題資料
unique_df, dupes_df = check_duplicate(df_clean, subset=["email"])
print(f"乾淨資料：{len(unique_df)} 筆")
print(f"重複資料：{len(dupes_df)} 筆（已排除）")
```

---

## Checkpoint

```
□ data_quality/ 資料夾建立
□ validators.py 完成（email / phone / null / duplicate 驗證）
□ cleaners.py 完成（email / company_name 標準化）
□ reports.py 完成（能產生品質報告）
□ 有至少 5 個 pytest 測試
□ 整合到 M5 的 ETL Pipeline（清洗後進 DB）
```
