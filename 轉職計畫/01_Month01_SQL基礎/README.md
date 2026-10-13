# Month 01｜SQL 基礎：看懂、查詢與篩選企業資料庫

> **本月核心目標**：克服對資料庫的陌生感，在電腦中建立起完整的企業資料庫環境，熟練使用 SQL 核心查詢語法（`SELECT`, `WHERE`, `GROUP BY`, `JOIN`），並能獨立解決 10+ 個真實 B2B 商業資料查詢問題。

---

## 🧭 全新架構規劃：學習一份、考試一份，完美整合 DBeaver

為了讓學習路徑最清晰、避免考題資料庫覆蓋日常練習表，本模組已全面重構為**「學習篇」與「考試篇」兩大獨立專區**：

```text
01_Month01_SQL基礎/
├── README.md                                    # 模組總覽與導覽手冊
├── DBeaver操作與連線指引.md                       # 🐬 DBeaver 連結本專案與雙庫隔離保姆級教學
│
├── 01_學習篇/                                   # 📘 【學習專區】：打底語法與 30 道實戰練習
│   ├── README.md                                # 學習篇導覽手冊
│   ├── 01_環境建置_PostgreSQL安裝與DBeaver連線.md
│   ├── 02_本月學習計畫與目標.md
│   ├── 03_讀懂陌生資料庫的五步驟.md
│   ├── 04_SQL核心語法_SELECT到JOIN全解析.md
│   ├── 05_SQL除錯方法論.md
│   ├── 06_JOIN陷阱與資料粒度問題.md
│   ├── 07_SQL商業問題拆解框架.md
│   ├── 08_AI協助SQL複習工作流.md
│   ├── 09_30道B2B商業SQL實戰練習題.md            # 30 道題庫（折疊解答）
│   ├── database/
│   │   ├── 01_b2b_learning_init.sql             # 🌟 學習專用資料庫初始化腳本 (b2b_learning 庫)
│   │   └── 02_b2b_learning_sample_v2.sql        # 進階備用版 (含 Trigger 與完整約束)
│   └── practice/
│       ├── my_learning_practice.sql             # ✍️ 個人練習作答本 (直接在 DBeaver 開啟)
│       └── week01_solutions.sql                 # 歷史參考解答備份
│
└── 02_考試篇/                                   # 🎓 【考試專區】：結業考驗收與認證
    ├── README.md                                # 考試篇導覽與通過標準
    ├── 01_Exit_Exam_B2B商業數據偵探考題.md       # 結業考考題 (5 實作 + 口試 + AI 除錯)
    ├── 02_Exit_Exam_參考解答與詳解.md            # 結業考詳解 (考後對答案)
    ├── database/
    │   └── 01_b2b_exam_init.sql                 # 🌟 考試專用資料庫初始化腳本 (b2b_exit_exam 庫)
    └── exam_submission/
        └── my_exam_submission.sql               # ✍️ 個人考卷作答本 (直接在 DBeaver 開啟)
```

---

## 🐬 DBeaver 3 步驟快速設定（隨點隨開，永不覆蓋）

> 完整詳細步驟請閱讀：👉 **[DBeaver操作與連線指引.md](./DBeaver操作與連線指引.md)**

### 步驟 1：將本資料夾連結到 DBeaver（免複製貼上！）
在 DBeaver 左側「專案 (Projects)」分頁 ➜ `General ➜ 腳本 (Scripts)` 按右鍵 ➜ 點選 **「連結資料夾 (Link Folder...)」** ➜ 選取本資料夾 `01_Month01_SQL基礎`。  
以後所有 `.sql` 檔都能直接在 DBeaver 側邊欄點開編輯！

### 步驟 2：在 DBeaver 建立兩個獨立資料庫
在左側「資料庫 (Databases)」按右鍵 ➜ **「建立新資料庫」**：
1. 建立 **`b2b_learning`**（學習用）
2. 建立 **`b2b_exit_exam`**（考試用）

### 步驟 3：一鍵執行初始化
- 學習庫：連線到 `b2b_learning`，開啟 `01_學習篇/database/01_b2b_learning_init.sql`，按 **`Alt + X`**。
- 考試庫：連線到 `b2b_exit_exam`，開啟 `02_考試篇/database/01_b2b_exam_init.sql`，按 **`Alt + X`**。

---

## 🗺️ 學習進度與章節導航

### 階段一：建立底層基礎與語法肌肉記憶
1. [01_環境建置指南](./01_學習篇/01_環境建置_PostgreSQL安裝與DBeaver連線.md)
2. [02_本月學習計畫與目標](./01_學習篇/02_本月學習計畫與目標.md)
3. [03_讀懂陌生資料庫的五步驟](./01_學習篇/03_讀懂陌生資料庫的五步驟.md)
4. [04_SQL核心語法全解析](./01_學習篇/04_SQL核心語法_SELECT到JOIN全解析.md)
5. [05_SQL除錯方法論](./01_學習篇/05_SQL除錯方法論.md)

### 階段二：高階防坑、商業思維與實戰大練兵
6. [06_JOIN陷阱與資料粒度問題](./01_學習篇/06_JOIN陷阱與資料粒度問題.md)
7. [07_SQL商業問題拆解框架](./01_學習篇/07_SQL商業問題拆解框架.md)
8. [08_AI協助SQL複習工作流](./01_學習篇/08_AI協助SQL複習工作流.md)
9. [09_30道B2B商業SQL實戰練習題](./01_學習篇/09_30道B2B商業SQL實戰練習題.md) ｜ [個人練習作答區](./01_學習篇/practice/my_learning_practice.sql)

### 階段三：結業驗收試煉 (Exit Exam)
10. [01_Exit_Exam_考題本](./02_考試篇/01_Exit_Exam_B2B商業數據偵探考題.md) ｜ [個人考卷作答區](./02_考試篇/exam_submission/my_exam_submission.sql)
11. [02_Exit_Exam_參考解答與詳解](./02_考試篇/02_Exit_Exam_參考解答與詳解.md)

---

## 🎯 本月技能檢核清單 (晉級 80 分線)

- [ ] 成功在 DBeaver 連結專案資料夾，並建好 `b2b_learning` 與 `b2b_exit_exam`。
- [ ] 能熟練使用快捷鍵 `Alt + X`（整份腳本一鍵執行）與 `Ctrl + Enter`（單行查詢）。
- [ ] 親手完成 30 道實戰練習題（不看解答先寫出）。
- [ ] 完成 M1 Exit Exam 結業考，正確率達 80% 以上，並附帶具體商業行動建議。
