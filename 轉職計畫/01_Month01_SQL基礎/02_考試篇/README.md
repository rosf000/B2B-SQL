# 🎓 Month 01 — 考試篇 (Exit Exam Track)

> **「只會打 SELECT 不叫會 SQL，能在 15 分鐘內用數據回答總經理的商業問題，才叫合格的 Data Engineer。」**

---

## 🗺️ 考試模組目錄結構

```text
02_考試篇/
├── README.md                                  # 考試篇導覽與規則
├── 01_Exit_Exam_B2B商業數據偵探考題.md         # 結業考題目本 (實作題 1~5 + 口試 + AI 除錯)
├── 02_Exit_Exam_參考解答與詳解.md              # 參考解答與商業洞察範本 (考完後對答案)
├── database/                                  # 考試專屬資料庫
│   └── 01_b2b_exam_init.sql                   # 🌟 結業考專屬初始化腳本 (b2b_exit_exam 庫)
└── exam_submission/                           # 個人作答區
    └── my_exam_submission.sql                 # ✍️ 個人考卷作答本 (直接在 DBeaver 開啟)
```

---

## 🎯 考試通過標準 (Pass Criteria)

1. **實作題正確率達 80% 以上**：共 5 題，至少答對 4 題且計算結果正確。
2. **必須附帶「商業結論與行動建議」**：不能只有冷冰冰的查詢結果。
3. **通過 AI 陷阱除錯題**：指出 AI 程式碼的資料膨脹 (Fan-out) 漏洞並重構完成。
4. **口試題能白話解釋**：不看小抄能向非技術主管講清楚執行順序與 JOIN 陷阱。

---

## 🚀 考試三部曲快速上手

### 第一步：在 DBeaver 建立獨立考試資料庫
> 💡 透過獨立資料庫，絕對不會覆蓋或洗掉你前面 `b2b_learning` 學習資料庫的練習資料！

1. 開啟 DBeaver，在左側「資料庫 (Databases)」按右鍵 ➜ **「建立新資料庫 (Create New Database)」**。
2. 名稱輸入 **`b2b_exit_exam`** ➜ 點擊確定。

### 第二步：一鍵匯入考題資料表
1. 在 DBeaver 左側找到剛建好的 **`b2b_exit_exam`**，按右鍵 ➜ **「SQL 編輯器」➜「新增 SQL 腳本」**。
2. 開啟 [`database/01_b2b_exam_init.sql`](./database/01_b2b_exam_init.sql)，全選貼上至編輯器中。
3. 按下鍵盤 **`Alt + X`**（或點擊左側雙箭頭 ▶▶）執行整份腳本。
4. 看到下方印出 `🎓 b2b_exit_exam 結業考專屬資料庫初始化成功！` 即代表考場環境就緒。

### 第三步：開啟考卷作答
1. 在 DBeaver 中開啟 [`exam_submission/my_exam_submission.sql`](./exam_submission/my_exam_submission.sql)。
2. 仔細閱讀 [`01_Exit_Exam_B2B商業數據偵探考題.md`](./01_Exit_Exam_B2B商業數據偵探考題.md)，在作答本上填寫 SQL 與商業結論。
3. 答題完畢後，再開啟 [`02_Exit_Exam_參考解答與詳解.md`](./02_Exit_Exam_參考解答與詳解.md) 進行對答案與自我檢核！
