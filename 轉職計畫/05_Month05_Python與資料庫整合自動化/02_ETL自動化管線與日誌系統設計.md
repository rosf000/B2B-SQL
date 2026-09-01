# 02 ETL 自動化管線架構與日誌監控設計

## 一、標準 ETL 三部曲

```text
┌─────────────────┐      ┌─────────────────────────┐      ┌──────────────────────────┐
│ 1. Extract 擷取 │ ───> │ 2. Transform 轉換與清洗 │ ───> │ 3. Load 寫入資料庫       │
│ CSV / Excel 檔案│      │ 格式標準化、型態轉換    │      │ 交易包覆、UPSERT 防重複  │
└─────────────────┘      └─────────────────────────┘      └──────────────────────────┘
```

---

## 二、UPSERT 機制（ON CONFLICT DO UPDATE）

在批次匯入時，如果某筆資料的統編或單號已存在，我們通常希望「更新既有欄位」而不是噴錯崩潰：

```sql
INSERT INTO b2b_customers (tax_id, company_name, city, credit_limit)
VALUES ('28491023', 'Apex Semiconductor TW', 'Hsinchu', 1500000)
ON CONFLICT (tax_id) 
DO UPDATE SET 
    company_name = EXCLUDED.company_name,
    credit_limit = EXCLUDED.credit_limit,
    updated_at = CURRENT_TIMESTAMP;
```
