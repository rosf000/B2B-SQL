# 🤖 AI Business Data Assistant (Text-to-SQL 自然語言資料庫助理)

> **專案定位**：Month 11 成果專案。示範如何結合大型語言模型與資料庫，提供「自然語言提問 ➜ 安全產生 SQL ➜ 執行資料庫查詢 ➜ 產出中文商業解答」的智慧 AI Agent。

---

## ✨ 核心特性

1. **Schema-Aware Prompting**：精準提供 B2B 資料表結構，杜絕幻覺與不存在欄位。
2. **Read-Only Security Guardrails**：內建安全過濾器，自動攔截任何非 SELECT / WITH 的修改指令。
3. **支援多後端**：支援直接連線 PostgreSQL 或 SQLite 本機免配置資料庫，並提供 Mock Mode 供無 API Key 時進行離線測試與演示。

---

## 🚀 快速啟動

```bash
# 1. 安裝依賴
pip install -r requirements.txt

# 2. 設定 API Key (可選，若未設定則自動進入精采 Mock 展示模式)
# export OPENAI_API_KEY="your-key"

# 3. 啟動互動式 AI 助理
python app.py
```
