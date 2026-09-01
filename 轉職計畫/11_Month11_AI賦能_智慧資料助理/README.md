# Month 11｜AI × 資料庫：打造自然語言智慧商業數據助理 (Text-to-SQL)

> **本月核心目標**：在具備 Python + SQL + Database + FastAPI + Docker 的紮實工程底子下，切入生成式 AI (LLM) 落地應用。打造一個 **AI Business Data Assistant**，讓非技術業務或高階主管直接用口語提問（如：「今年台北哪 3 個客戶買最多？」），AI 自動將其轉化為安全可執行的 SQL，查詢資料庫後以繁體中文給出清晰的商業洞察。

---

## 🎯 本月技能檢核清單

- [ ] 理解 LLM API (OpenAI / Google Gemini / Anthropic) 呼叫機制與 Token 計價
- [ ] 掌握 Prompt Engineering（System Prompt, Few-Shot 範例提示）
- [ ] 掌握結構化輸出 (Structured Output) 與 Pydantic 整合
- [ ] 深入理解 Tool Use / Function Calling 原理
- [ ] 設計防禦 SQL 注入與惡意刪庫 (Read-Only SQL Validator) 的安全防護層
- [ ] 完成 **AI Text-to-SQL 智慧數據查詢助理專案 (Project 4)**

---

## 📂 本模組教材與應用程式導航

1. [01_LLM_API_Prompt工程與Structured_Output.md](./01_LLM_API_Prompt工程與Structured_Output.md)
   - Prompt 樣板設計、角色設定、防幻覺與 Schema 注入技術。
2. [02_Text_to_SQL與Function_Calling原理解析.md](./02_Text_to_SQL與Function_Calling原理解析.md)
   - 智慧 Agent 的運作迴圈 (Plan ➜ Tool Call ➜ Execute ➜ Synthesize)。
3. [ai_sql_assistant/](./ai_sql_assistant/)
   - 可直接執行的 AI 資料庫助理專案源碼（含互動式 CLI 介面與 Demo 範例）。
