# 05. B2B 工作情境 × Python 應用：從日常痛點到自動化工具

> **這篇是 M4 → M5 的橋樑。**
> M4 學了語法，M5 要接 PostgreSQL + ETL。
> 這篇用你熟悉的 B2B 工作場景，把 Python 語法變成真正有用的工具，
> 讓你在進入 M5 之前，對「Python 能解決什麼問題」有具體的感受。

---

## 你在 B2B 工作中一定遇過這些問題

```
😤 問題 1：業務給的 Excel 有重複客戶，手動找要花半小時
😤 問題 2：每週要把三個部門的報表合併統計，Copy-Paste 到崩潰
😤 問題 3：客戶 Email 格式很亂，有大寫有空格，難以做搜尋
😤 問題 4：老闆要看「本週哪些客戶 90 天沒下單」，要手動篩選
😤 問題 5：每次匯出訂單 CSV，欄位名稱都不一樣，要手動整理
```

這篇的目標：**把這五個問題，用 Python 寫成自動化工具。**

---

## 情境 1：Excel 客戶清單去重工具

### 場景

業務員從 CRM 匯出客戶名單，但同一家公司可能被建了多次（打錯字、大小寫不同、有沒有「股份有限公司」後綴）。你的任務：找出重複的，產出一份乾淨清單。

### 解法思路（先自己想，再看程式碼）

```
輸入：customers.csv（可能有重複）
目標：
  1. 標準化 email（全部轉小寫、去空白）
  2. 以 email 為主鍵找出重複
  3. 輸出：clean_customers.csv（唯一） + duplicates.csv（重複的）
```

### 程式碼

```python
# tools/customer_dedup.py
"""
客戶去重工具
使用方式：python tools/customer_dedup.py
"""
import pandas as pd
from pathlib import Path
from datetime import datetime


def normalize_email(email: str) -> str:
    """標準化 email：去空白、轉小寫"""
    if not isinstance(email, str):
        return ""
    return email.strip().lower()


def normalize_company_name(name: str) -> str:
    """標準化公司名稱：去後綴、去空白"""
    if not isinstance(name, str):
        return ""
    name = name.strip()
    # 去除常見後綴
    for suffix in ["股份有限公司", "有限公司", "公司", " Inc.", " Ltd.", " Co."]:
        name = name.replace(suffix, "").replace(suffix.lower(), "")
    return name.strip()


def find_duplicates(df: pd.DataFrame, key_col: str) -> tuple[pd.DataFrame, pd.DataFrame]:
    """
    根據指定欄位找出重複資料。

    Args:
        df: 輸入的 DataFrame
        key_col: 用來判斷重複的欄位名稱（例如 "email"）

    Returns:
        (clean_df, duplicate_df)：乾淨資料 和 重複資料
    """
    is_dup = df.duplicated(subset=[key_col], keep="first")
    clean_df = df[~is_dup].copy()
    duplicate_df = df[is_dup].copy()
    return clean_df, duplicate_df


def run_dedup(input_path: str, output_dir: str = "output") -> None:
    """主流程：讀取 → 清洗 → 去重 → 輸出"""
    # ── 讀取資料 ────────────────────────────────────────────
    print(f"讀取檔案：{input_path}")
    df = pd.read_csv(input_path, encoding="utf-8-sig")  # 支援 Excel 匯出的 BOM
    print(f"原始資料：{len(df)} 筆")

    # ── 標準化 ──────────────────────────────────────────────
    if "email" in df.columns:
        df["email"] = df["email"].apply(normalize_email)
    if "company_name" in df.columns:
        df["company_name"] = df["company_name"].apply(normalize_company_name)

    # ── 去重 ────────────────────────────────────────────────
    clean_df, duplicate_df = find_duplicates(df, key_col="email")
    print(f"乾淨資料：{len(clean_df)} 筆")
    print(f"重複資料：{len(duplicate_df)} 筆")

    # ── 輸出 ────────────────────────────────────────────────
    Path(output_dir).mkdir(parents=True, exist_ok=True)
    today = datetime.now().strftime("%Y%m%d")

    clean_path = f"{output_dir}/clean_customers_{today}.csv"
    dup_path = f"{output_dir}/duplicates_{today}.csv"

    clean_df.to_csv(clean_path, index=False, encoding="utf-8-sig")
    duplicate_df.to_csv(dup_path, index=False, encoding="utf-8-sig")

    print(f"\n✅ 完成！")
    print(f"   乾淨資料 → {clean_path}")
    print(f"   重複資料 → {dup_path}")


if __name__ == "__main__":
    run_dedup("data/customers.csv")
```

**學到的 Python 概念：**
- `pandas.read_csv` / `DataFrame.duplicated`
- Function 設計（單一職責、型別提示）
- `Path` 物件（跨平台路徑處理）
- `tuple` 的多值回傳

---

## 情境 2：業務週報自動彙整工具

### 場景

每週五，各區業務 email 過來一份 CSV（格式略有差異），你要把他們全部合併、計算各區總金額、找出本週最大單，給老闆一份彙整報告。

### 解法思路

```
輸入：reports/ 資料夾內的多份 CSV（北區.csv、南區.csv、中區.csv）
目標：
  1. 自動讀取資料夾內所有 CSV
  2. 合併成一張大表
  3. 計算各業務員本週業績總計
  4. 找出本週最大單（金額最高的一筆訂單）
  5. 輸出 weekly_summary.csv
```

### 程式碼

```python
# tools/weekly_report.py
"""
業務週報自動彙整工具
使用方式：python tools/weekly_report.py
"""
import pandas as pd
from pathlib import Path
from datetime import datetime


# 標準欄位名稱映射（應對各區業務命名不統一的問題）
COLUMN_MAPPING = {
    "業務員": "salesperson",
    "業務姓名": "salesperson",
    "負責業務": "salesperson",
    "客戶": "customer",
    "客戶名稱": "customer",
    "金額": "amount",
    "訂單金額": "amount",
    "總金額": "amount",
    "日期": "order_date",
    "訂單日期": "order_date",
}


def read_all_reports(reports_dir: str) -> pd.DataFrame:
    """讀取資料夾內所有 CSV，自動標準化欄位名稱"""
    all_dfs = []
    report_path = Path(reports_dir)

    csv_files = list(report_path.glob("*.csv"))
    if not csv_files:
        raise FileNotFoundError(f"在 {reports_dir} 找不到任何 CSV 檔案")

    for file in csv_files:
        print(f"  讀取：{file.name}")
        df = pd.read_csv(file, encoding="utf-8-sig")

        # 統一欄位名稱
        df = df.rename(columns=COLUMN_MAPPING)

        # 記錄來源
        df["source_file"] = file.stem

        all_dfs.append(df)

    merged = pd.concat(all_dfs, ignore_index=True)
    print(f"\n合併完成：共 {len(merged)} 筆，來自 {len(csv_files)} 個檔案")
    return merged


def generate_summary(df: pd.DataFrame) -> dict:
    """產生彙整統計"""
    # 確保 amount 是數字
    df["amount"] = pd.to_numeric(df["amount"], errors="coerce")
    df = df.dropna(subset=["amount"])  # 移除無法轉換的行

    summary = {
        "total_amount": df["amount"].sum(),
        "total_orders": len(df),
        "by_salesperson": (
            df.groupby("salesperson")["amount"]
            .agg(["sum", "count"])
            .rename(columns={"sum": "total", "count": "orders"})
            .sort_values("total", ascending=False)
        ),
        "top_order": df.loc[df["amount"].idxmax()],
    }
    return summary


def print_report(summary: dict) -> None:
    """輸出報告到 Terminal"""
    print("\n" + "=" * 50)
    print("📊 本週業務週報")
    print("=" * 50)
    print(f"總筆數：{summary['total_orders']} 筆")
    print(f"總金額：${summary['total_amount']:,.0f}")

    print("\n【各業務員業績排名】")
    print(summary["by_salesperson"].to_string())

    top = summary["top_order"]
    print(f"\n【本週最大單】")
    print(f"  業務：{top.get('salesperson', 'N/A')}")
    print(f"  客戶：{top.get('customer', 'N/A')}")
    print(f"  金額：${top.get('amount', 0):,.0f}")
    print("=" * 50)


def run_weekly_report(reports_dir: str = "reports") -> None:
    """主流程"""
    print(f"讀取資料夾：{reports_dir}/")
    df = read_all_reports(reports_dir)

    summary = generate_summary(df)
    print_report(summary)

    # 輸出 CSV
    today = datetime.now().strftime("%Y%m%d")
    output_path = f"output/weekly_summary_{today}.csv"
    Path("output").mkdir(exist_ok=True)
    summary["by_salesperson"].to_csv(output_path, encoding="utf-8-sig")
    print(f"\n✅ 報表已儲存至 {output_path}")


if __name__ == "__main__":
    run_weekly_report()
```

**學到的 Python 概念：**
- `Path.glob()` — 批次讀取檔案
- `pd.concat()` — 合併多個 DataFrame
- `groupby().agg()` — 分組統計
- `pd.to_numeric(errors="coerce")` — 容錯型態轉換
- `dict` 存放多種結果

---

## 情境 3：90 天未下單客戶偵測器

### 場景

老闆想知道：「哪些客戶超過 90 天沒有新訂單？他們上次消費了多少？」
你有兩份 CSV：`customers.csv` 和 `orders.csv`。

### 解法思路

```
輸入：customers.csv + orders.csv
目標：
  1. 找出每個客戶「最後一次下單日期」
  2. 計算距今天數
  3. 篩選出 > 90 天的客戶
  4. 加上「最後一次訂單金額」
  5. 輸出提醒清單
```

### 程式碼

```python
# tools/inactive_customer_detector.py
"""
90 天未下單客戶偵測工具
"""
import pandas as pd
from datetime import datetime, timedelta


INACTIVE_DAYS = 90  # 超過幾天算「沉睡客戶」


def detect_inactive_customers(
    customers_path: str,
    orders_path: str,
    days_threshold: int = INACTIVE_DAYS
) -> pd.DataFrame:
    """
    偵測超過指定天數沒有下單的客戶。

    Returns:
        包含「客戶名稱、最後下單日、距今天數、最後訂單金額」的 DataFrame
    """
    customers = pd.read_csv(customers_path, encoding="utf-8-sig")
    orders = pd.read_csv(orders_path, encoding="utf-8-sig")

    # 確保日期欄位是 datetime 型別
    orders["order_date"] = pd.to_datetime(orders["order_date"])

    # 計算每個客戶的最後下單資訊
    last_orders = (
        orders.sort_values("order_date", ascending=False)
        .groupby("customer_id")
        .first()
        .reset_index()[["customer_id", "order_date", "amount"]]
        .rename(columns={
            "order_date": "last_order_date",
            "amount": "last_order_amount"
        })
    )

    # 合併客戶資料
    result = customers.merge(last_orders, on="customer_id", how="left")

    # 計算距今天數
    today = datetime.now()
    result["days_since_last_order"] = (
        today - result["last_order_date"]
    ).dt.days

    # 篩選沉睡客戶（從未下單的也包含在內）
    inactive = result[
        (result["days_since_last_order"] > days_threshold) |
        result["last_order_date"].isna()
    ].copy()

    # 整理輸出欄位
    inactive = inactive.sort_values("days_since_last_order", ascending=False)

    return inactive[["customer_id", "company_name", "salesperson_id",
                     "last_order_date", "last_order_amount", "days_since_last_order"]]


def main():
    inactive_df = detect_inactive_customers(
        customers_path="data/customers.csv",
        orders_path="data/orders.csv",
        days_threshold=90
    )

    print(f"⚠️  發現 {len(inactive_df)} 位沉睡客戶（超過 90 天未下單）")
    print(inactive_df.to_string(index=False))

    # 儲存結果
    output_path = f"output/inactive_customers_{datetime.now().strftime('%Y%m%d')}.csv"
    inactive_df.to_csv(output_path, index=False, encoding="utf-8-sig")
    print(f"\n✅ 已儲存至 {output_path}")


if __name__ == "__main__":
    main()
```

**學到的 Python 概念：**
- `pd.to_datetime()` — 日期型別轉換
- `groupby().first()` — 取每組第一筆
- `datetime` 運算 — 計算天數差異
- 多條件 `|` 篩選
- 函式的 `days_threshold` 參數 — 讓工具可設定

---

## 三工具的共同架構模式

觀察以上三個工具，你會發現一個共同結構：

```python
def main():
    # 1. 讀取（Extract）
    data = read_data(input_path)

    # 2. 處理（Transform）
    result = process(data)

    # 3. 輸出（Load）
    save_result(result, output_path)
    print_summary(result)

if __name__ == "__main__":
    main()
```

**這就是 M5 ETL Pipeline 的雛形！**

M5 要做的事，就是把這個模式：
- 加上 **Logging**（不用 print）
- 加上 **Error Handling**（try/except + rollback）
- 加上 **Config 管理**（不 hardcode 路徑）
- 接上 **PostgreSQL**（不輸出 CSV，直接進 DB）

---

## M4 → M5 銜接 Checklist

```
□ 能讀取 CSV 並用 pandas 做基本操作（groupby, merge, filter）
□ 能寫出「讀取 → 處理 → 輸出」三段式函式
□ 理解 normalize_xxx 函式的設計模式（一個函式做一件事）
□ 能用 Path() 處理跨平台路徑
□ 三個工具至少完成其中兩個，並上傳 GitHub

進入 M5 的門檻：
□ 能不看文件寫出讀取 CSV + groupby 的完整程式
□ 理解 try/except 的基本用法（M4 第 2 篇已學）
```

---

## 延伸挑戰（有餘力再做）

**挑戰 1**：把工具 1 的去重邏輯升級，改用 `rapidfuzz` 做模糊比對（找出「蘋果公司」和「Apple 蘋果股份有限公司」是同一家）

**挑戰 2**：工具 3 的沉睡天數從 hardcode 的 90 天，改成讓使用者在執行時輸入：
```bash
python tools/inactive_customer_detector.py --days 60
```
提示：用 `argparse` 模組。

**挑戰 3**：把三個工具整合成一個 CLI：
```bash
python b2b_tools.py dedup       # 去重
python b2b_tools.py report      # 週報
python b2b_tools.py inactive    # 沉睡客戶
```
