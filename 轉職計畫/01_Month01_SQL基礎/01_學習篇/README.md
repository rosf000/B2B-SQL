# 📘 Month 01 — 學習篇 (Learning Track)

> **「從零開始建立資料庫思維，打通 SELECT 到 JOIN 的完整肌肉記憶。」**

---

## 🗺️ 學習模組目錄結構

```text
01_學習篇/
├── 01_環境建置_PostgreSQL安裝與DBeaver連線.md   # PostgreSQL 與 DBeaver 安裝起手式
├── 02_本月學習計畫與目標.md                     # 4 週 28 天學習日程與每日任務
├── 03_讀懂陌生資料庫的五步驟.md                 # 探索 Schema 與資料表的工程師起手式
├── 04_SQL核心語法_SELECT到JOIN全解析.md        # 5 大關卡語法與 SQL 實際執行順序
├── 05_SQL除錯方法論.md                         # 常見 7 大報錯與除錯心法
├── 06_JOIN陷阱與資料粒度問題.md                 # 笛卡兒積、Fan-out 膨脹與粒度控制
├── 07_SQL商業問題拆解框架.md                   # 4 步將模糊商業需求轉為 SQL
├── 08_AI協助SQL複習工作流.md                   # 如何用 AI 當家教而不喪失思考力
├── 09_30道B2B商業SQL實戰練習題.md              # 30 題實戰題庫（思考優先・折疊解答）
├── database/                                   # 學習資料庫專區
│   ├── 01_b2b_learning_init.sql                # 🌟 學習用初始化腳本 (b2b_learning 庫)
│   └── 02_b2b_learning_sample_v2.sql           # 進階版備用腳本 (含 Trigger 與約束)
└── practice/                                   # 個人練習區
    ├── my_learning_practice.sql                # ✍️ 30 題個人作答草稿本 (直接在 DBeaver 開啟)
    └── week01_solutions.sql                    # 舊版練習參考備份
```

---

## 🚀 學習三部曲快速上手

### 第一步：在 DBeaver 建立學習資料庫
1. 開啟 DBeaver，在左側「資料庫 (Databases)」按右鍵 ➜ **「建立新資料庫 (Create New Database)」**。
2. 名稱輸入 **`b2b_learning`** ➜ 點擊確定。

### 第二步：一鍵匯入學習資料表
1. 在 DBeaver 左側找到剛建好的 **`b2b_learning`**，按右鍵 ➜ **「SQL 編輯器」➜「新增 SQL 腳本」**。
2. 開啟 [`database/01_b2b_learning_init.sql`](./database/01_b2b_learning_init.sql)，全選貼上至編輯器中。
3. 按下鍵盤 **`Alt + X`**（或點擊左側雙箭頭 ▶▶）執行整份腳本。
4. 看到下方印出 `🎉 b2b_learning 學習資料庫初始化成功！` 即完成。

### 第三步：開啟練習作答本進行刻意練習
1. 在 DBeaver 中開啟 [`practice/my_learning_practice.sql`](./practice/my_learning_practice.sql)。
2. 對照 [`09_30道B2B商業SQL實戰練習題.md`](./09_30道B2B商業SQL實戰練習題.md)，親手寫下每一道題目的查詢。
3. 單行執行請按 **`Ctrl + Enter`**，即時驗證產出結果！

---

## 🔗 下一步
當你完成 01~09 的全部講義並親手寫完 30 道練習題後，請前往：
👉 **[02_考試篇 (Exit_Exam)](../02_考試篇/README.md)** 挑戰結業考核！
