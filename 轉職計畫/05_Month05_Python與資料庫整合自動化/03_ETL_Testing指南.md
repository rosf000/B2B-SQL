# Testing Guide — ETL Pipeline 測試實務

> M5 補強：你的 ETL Project 必須有測試，這是工程品質的最低標準。

## 為什麼 ETL 需要測試？

```
沒有測試的 ETL：
資料跑錯了 → 進了 Database → 分析結果錯了 → 決策錯了

有測試的 ETL：
資料跑錯了 → 測試失敗 → Alert → 修正 → 正確資料進 Database
```

---

## 最小測試架構

```
etl_project/
├── src/
│   ├── extract.py
│   ├── transform.py
│   ├── load.py
│   └── validation.py
├── tests/
│   ├── __init__.py
│   ├── test_extract.py      ← 測試資料讀取
│   ├── test_transform.py    ← 測試資料清洗邏輯
│   └── test_validation.py  ← 測試資料驗證規則
└── requirements.txt
```

---

## 核心測試範例

### test_transform.py

```python
import pytest
import pandas as pd
from src.transform import (
    clean_email,
    clean_company_name,
    remove_duplicates,
    validate_required_fields
)


class TestCleanEmail:
    def test_normal_email(self):
        assert clean_email("test@example.com") == "test@example.com"

    def test_uppercase_email(self):
        assert clean_email("TEST@EXAMPLE.COM") == "test@example.com"

    def test_email_with_spaces(self):
        assert clean_email("  test@example.com  ") == "test@example.com"

    def test_invalid_email_format(self):
        with pytest.raises(ValueError):
            clean_email("not-an-email")

    def test_empty_email(self):
        with pytest.raises(ValueError):
            clean_email("")

    def test_none_email(self):
        with pytest.raises(TypeError):
            clean_email(None)


class TestRemoveDuplicates:
    def test_removes_exact_duplicates(self):
        df = pd.DataFrame({
            "email": ["a@test.com", "a@test.com", "b@test.com"],
            "name": ["A", "A", "B"]
        })
        result = remove_duplicates(df, subset=["email"])
        assert len(result) == 2

    def test_keeps_first_occurrence(self):
        df = pd.DataFrame({
            "email": ["a@test.com", "a@test.com"],
            "name": ["First", "Second"]
        })
        result = remove_duplicates(df, subset=["email"])
        assert result.iloc[0]["name"] == "First"

    def test_no_duplicates_unchanged(self):
        df = pd.DataFrame({
            "email": ["a@test.com", "b@test.com"]
        })
        result = remove_duplicates(df, subset=["email"])
        assert len(result) == 2


class TestValidateRequiredFields:
    def test_valid_record(self):
        record = {"email": "test@test.com", "name": "Test"}
        assert validate_required_fields(record, ["email", "name"]) == True

    def test_missing_field(self):
        record = {"email": "test@test.com"}
        with pytest.raises(ValueError):
            validate_required_fields(record, ["email", "name"])

    def test_null_field(self):
        record = {"email": None, "name": "Test"}
        with pytest.raises(ValueError):
            validate_required_fields(record, ["email", "name"])
```

### test_validation.py

```python
import pytest
from src.validation import (
    is_valid_email,
    is_valid_phone,
    is_valid_date,
    check_not_null
)


def test_valid_email_formats():
    assert is_valid_email("user@example.com") == True
    assert is_valid_email("user.name+tag@domain.co.uk") == True


def test_invalid_email_formats():
    assert is_valid_email("not-an-email") == False
    assert is_valid_email("@no-local.com") == False
    assert is_valid_email("no-at-sign.com") == False
    assert is_valid_email("") == False


def test_check_not_null():
    assert check_not_null("value") == True
    assert check_not_null(0) == True      # 0 不算 null
    assert check_not_null(None) == False
    assert check_not_null("") == False    # 空字串算 null
```

---

## 如何執行測試

```bash
# 安裝 pytest
pip install pytest

# 執行所有測試
pytest

# 執行特定測試檔
pytest tests/test_transform.py

# 顯示詳細輸出
pytest -v

# 測試失敗立即停止
pytest -x
```

---

## Checkpoint：你的 ETL 測試完成標準

```
□ tests/ 目錄存在
□ test_transform.py 有至少 5 個測試
□ test_validation.py 有至少 5 個測試
□ pytest 全部通過（0 failures）
□ README 說明如何執行測試
```

---

## 進階（有時間再加）

```python
# conftest.py — 共用測試資料
import pytest
import pandas as pd

@pytest.fixture
def sample_customers():
    return pd.DataFrame({
        "email": ["alice@test.com", "bob@test.com", "invalid"],
        "company": ["Apple", "Google", ""],
        "amount": [1000, 2000, None]
    })
```

```python
# 使用 fixture
def test_validate_customers(sample_customers):
    valid, invalid = split_valid_invalid(sample_customers)
    assert len(valid) == 2
    assert len(invalid) == 1
```
