# 01. 工程師必備 Git 與 GitHub 企業級工作流

> **📌 本章定位**：Git 不僅僅是「備份代碼的工具」，而是現代軟體工程協作的**「時光機、分支平行宇宙與信任契約」**。其核心心智模型是「內容尋址鍵值快照（DAG）」，讓你隨心所欲穿梭於歷史節點。
>
> **⚠️ 痛點場景（職場三大 Git 職涯危機）**：
> 1. **洩漏金鑰傾家蕩產**：手滑把含有正式環境資料庫密碼的 `.env` 提交並 push 到公開 GitHub Repo，半小時內被黑客爬蟲掃描，雲端伺服器被用來挖礦，收到百萬帳單。
> 2. **強制覆蓋同事心血**：多人協作時遇到 rejection，無腦執行 `git push --force`，直接把同事花了三天辛苦寫好的程式碼抹殺消失。
> 3. **衝突排解現場癱瘓**：遇到 Merge Conflict 不懂原理，隨便在 VS Code 點 Accept Current Change，把主幹修好的重大 Hotfix 覆蓋掉，造成線上再次崩潰。
>
> **💡 學習策略**：先定位（DAG 與四區流轉）➔ 再理解（Merge vs Rebase 與分支保護）➔ 再操作（互動式 Rebase 壓縮與衝突排障）➔ 再回收（救命 reflog 與防坑清單）。

---

## 目錄
1. [Git 底層架構心智模型：不是檔案比對，而是快照流](#1-git-底層架構心智模型不是檔案比對而是快照流)
   - [1.1 四大物件：Blob, Tree, Commit, Tag](#11-四大物件blob-tree-commit-tag)
   - [1.2 四大區域生命週期：Working Directory 到 Remote](#12-四大區域生命週期working-directory-到-remote)
2. [日常高頻操作與 Conventional Commits 企業規範](#2-日常高頻操作與-conventional-commits-企業規範)
   - [2.1 精細化暫存：git add -p](#21-精細化暫存git-add--p)
   - [2.2 語意化 Commit 規範：feat, fix 與 breaking change](#22-語意化-commit-規範feat-fix-與-breaking-change)
3. [分支管理、合併策略與衝突排障](#3-分支管理合併策略與衝突排障)
   - [3.1 分支的本質：指向 Commit 的輕量指標](#31-分支的本質指向-commit-的輕量指標)
   - [3.2 Merge 三種策略：Fast-Forward, --no-ff, Squash](#32-merge-三種策略fast-forward---no-ff-squash)
   - [3.3 Rebase（變基）的藝術與黃金禁忌](#33-rebase變基的藝術與黃金禁忌)
   - [3.4 衝突解剖學：如何冷靜解決 Merge Conflict](#34-衝突解剖學如何冷靜解決-merge-conflict)
4. [時光機與災難恢復指南（工程師必修救命藥）](#4-時光機與災難恢復指南工程師必修救命藥)
   - [4.1 暫存工作進度：git stash 原理與技巧](#41-暫存工作進度git-stash-原理與技巧)
   - [4.2 歷史回退：reset (--soft / --mixed / --hard) 深度對比](#42-歷史回退reset---soft----mixed----hard-深度對比)
   - [4.3 遠端安全撤銷：git revert](#43-遠端安全撤銷git-revert)
   - [4.4 終極死者甦醒：git reflog 搶救失蹤 Commit](#44-終極死者甦醒git-reflog-搶救失蹤-commit)
5. [企業級 GitHub 協作工作流與分支保護](#5-企業級-github-協作工作流與分支保護)
6. [商業情境綜合練習題（含詳解）](#6-商業情境綜合練習題含詳解)

---

## 1. Git 底層架構心智模型：不是檔案比對，而是快照流

許多初學者誤以為 Git 儲存的是「每一版增加或刪除的文字差異（Diff）」，這種認知在遇到分支合併與衝突時會讓人陷入困惑。

### 1.1 四大物件：Blob, Tree, Commit, Tag

Git 底層本質上是一個**內容尋址的鍵值資料庫（Content-Addressable Key-Value Store）**，所有資料透過 SHA-1 / SHA-256 雜湊值（40 碼十六進位字串）進行存取：
- **Blob（Binary Large Object）**：僅儲存「檔案內容」，不包含檔名、權限或路徑。同內容檔案雜湊值完全相同。
- **Tree**：相當於「目錄」。記錄底下的檔名、檔案權限，以及對應的 Blob 或子 Tree 的雜湊值。
- **Commit**：包含特定頂層 Tree 的指標、父提交（Parent Commit）指標、作者（Author）、提交者（Committer）、時間戳與 Commit Message。
- **Tag**：指向特定 Commit 的永久具名書籤。

```
[ Commit: a1b2c3d ]
  |-- tree: e4f5g6...
  |-- parent: 09876a...
  |-- author: Jay <jay@example.com>
  \-- message: "feat: add B2B order checkout logic"
         |
         v
     [ Tree: 根目錄 ]
       |-- [ Blob: README.md ]
       \-- [ Tree: src/ ]
             |-- [ Blob: order_service.py ]
             \-- [ Blob: db_pool.py ]
```

### 1.2 四大區域生命週期：Working Directory 到 Remote

```
+------------------+         +---------------+         +----------------+         +----------------+
| 工作區           |         | 暫存區 (Index) |         | 本地版本庫      |         | 遠端版本庫     |
| Working Tree     |         | Staging Area  |         | Local Repo     |         | Remote (GitHub)|
+------------------+         +---------------+         +----------------+         +----------------+
         |                          |                          |                          |
         | --- git add ------------>|                          |                          |
         |                          | --- git commit --------->|                          |
         |                          |                          | --- git push ----------->|
         |                          |                          |                          |
         |<--- git checkout / restore -------------------------|                          |
         |<--- git pull (fetch + merge) --------------------------------------------------|
```

---

## 2. 日常高頻操作與 Conventional Commits 企業規範

### 2.1 精細化暫存：git add -p

在修改了一整天程式碼後，你可能在 `order_service.py` 裡同時改了「VIP 折扣計算」與「修復發票稅率 Bug」。
**千萬不要無腦 `git add .` 全部打包成一個巨大 Commit**！這會讓 Code Review 變得不可閱讀。

使用互動式暫存：
```bash
git add -p order_service.py
```
Git 會將檔案切分成多個程式碼塊（Hunk），並詢問你的意圖：
- `y`：暫存此程式碼塊
- `n`：不暫存此程式碼塊
- `s`：將此程式碼塊切得更小（Split）
- `e`：手動編輯此程式碼塊（Edit）

---

### 2.2 語意化 Commit 規範：feat, fix 與 breaking change

企業團隊普遍遵循 **Conventional Commits 規範**，這有助於自動生成 CHANGELOG、語意化版本號（SemVer）：

#### 格式模板：
```
<type>(<scope>): <subject>

[optional body]

[optional footer(s)]
```

| Type | 適用情境 | 範例 |
| :--- | :--- | :--- |
| **feat** | 新增功能（Feature） | `feat(order): 支援大額 B2B 訂單多期分期付款` |
| **fix** | 修復 Bug | `fix(inventory): 修復併發扣庫存時的超賣問題` |
| **refactor** | 重構（無新增功能亦無修復 Bug） | `refactor(db): 將原生 psycopg2 查詢改寫為 SQLAlchemy 2.0 ORM` |
| **perf** | 效能優化 | `perf(query): 為 customers.credit_limit 加入複合索引` |
| **docs** | 文件異動 | `docs(readme): 更新本機 Docker-compose 啟動指南` |
| **test** | 測試相關新增或修改 | `test(order): 新增信用額度超額拒絕單元測試` |
| **chore** | 建置工具、依賴項變更 | `chore(deps): 升級 pydantic 至 2.7.0` |

---

## 3. 分支管理、合併策略與衝突排障

### 3.1 分支的本質：指向 Commit 的輕量指標

在 Git 中，**建立分支是 0 成本的**。一個分支（Branch）本質上只是一個存放在 `.git/refs/heads/` 下的 41 位元文字檔，內容記錄著該分支最新 Commit 的 SHA-1 雜湊值。
切換分支（`git checkout` 或 `git switch`）只不過是讓 `HEAD` 指標指向不同的分支指標而已。

### 3.2 Merge 三種策略：Fast-Forward, --no-ff, Squash

假設我們在 `feature/b2b-invoice` 完成了功能開發，準備合併進 `main`：

1. **Fast-Forward Merge（快進合併，預設）**：
   - 條件：若 `main` 自切出分支以來**完全沒有任何新 Commit**。
   - 結果：Git 只是簡單地把 `main` 指標直接向前移動到 feature 的最新 Commit 上。沒有額外的 Merge Commit。
2. **3-Way Merge with `--no-ff`（強制建立合併提交）**：
   ```bash
   git checkout main
   git merge --no-ff feature/b2b-invoice -m "merge: 合併發票開立模組 (#102)"
   ```
   - 結果：無論是否能 Fast-Forward，都強制生成一個具備兩個 Parent 的「Merge Commit」，完整記錄此 Feature 何時合入主幹。**企業主幹管理最推薦策略**。
3. **Squash Merge（壓扁合併）**：
   ```bash
   git merge --squash feature/b2b-invoice
   ```
   - 結果：將 feature 分支上零散的 20 個 Commit 壓扁成一個單一變更暫存於暫存區，由開發者提交乾淨的一筆 Commit。適用於個人 Feature 開發過程中瑣碎的 WIP 提交。

---

### 3.3 Rebase（變基）的藝術與黃金禁忌

`merge` 會保留真實的時間分支分叉與會合歷史；而 `rebase` 則是將你的分支 Commit「拔起來」，移到目標分支的最新 Commit 後面重新播放（Re-apply），產生乾淨的線性歷史（Linear History）。

```
Rebase 流程圖解：
原本分叉：
      C---D  (feature)
     /
A---B---E    (main)

執行 git rebase main 後：
A---B---E---C'---D'  (feature，注意 C' 與 D' 雜湊值已改變！)
```

> ⚠️ **Git Rebase 黃金法則（The Golden Rule of Rebase）**：
> **「永遠不要對已經推送到公開共享遠端（如 main 或 develop）的 Commit 進行 Rebase！」**
> 因為 Rebase 會重新計算 SHA-1 雜湊值，徹底改寫歷史，這會導致協作隊友的本地倉庫分叉混亂，引發團隊災難。

---

### 3.4 衝突解剖學：如何冷靜解決 Merge Conflict

當兩個人在不同分支修改了同一個檔案的**同一行程式碼**時，Git 會停止合併並在檔案中標註衝突標記：

```python
<<<<<<< HEAD (當前分支的程式碼，例如 main)
def calculate_discount(amount: float) -> float:
    return amount * 0.95  # 全館 95 折
=======
def calculate_discount(amount: float) -> float:
    return amount * 0.90 if amount > 50000 else amount * 0.98 # 大額階梯折扣
>>>>>>> feature/tiered-discount (準備合併進來的程式碼)
```

#### 衝突拆彈標準 SOP：
1. 找出衝突檔案：`git status`（狀態顯示為 `both modified`）。
2. 打開編輯器（如 VSCode），與業務或原作者溝通確定保留哪一方，或者融合成全新邏輯。
3. 刪除所有 `<<<<<<<`、`=======`、`>>>>>>>` 標記。
4. 儲存檔案後加入暫存區：`git add <檔案路徑>`。
5. 完成合併：`git commit`（或若在 rebase 過程中則執行 `git rebase --continue`）。

---

## 4. 時光機與災難恢復指南（工程師必修救命藥）

### 4.1 暫存工作進度：git stash 原理與技巧

當你正在寫功能 A 寫到一半，主管突然說線上資料庫有緊急 Bug 需要切回 `main` 分支修復，但目前程式碼編譯不會過，不想 Commit：

```bash
# 1. 將當前未 Commit 的變更（含工作區與暫存區）存入堆疊
git stash save "WIP: 正在實作 B2B 多期付款邏輯"

# 2. 安全切換分支修復線上 Hotfix
git switch main
# ... 修復、測試、提交、推送 ...

# 3. 修完切回原分支，還原剛才的工作
git switch feature/payment
git stash pop  # 還原並從 stash 堆疊中彈出移除
```

---

### 4.2 歷史回退：reset (--soft / --mixed / --hard) 深度對比

這是面試最愛考的觀念，三者差異在於**回退時影響哪些區域**：

| 指令 | HEAD 指標移動 | 暫存區（Index） | 工作目錄（檔案內容） | 適用情境 |
| :--- | :--- | :--- | :--- | :--- |
| `git reset --soft HEAD~1` | **YES** | 保留不變 | 保留不變 | 剛 commit 完發現 message 打錯或少加一個檔案，退回暫存區重新 commit |
| `git reset --mixed HEAD~1` *(預設)*| **YES** | **被重置（清空）** | 保留不變 | 撤銷 commit 與暫存，程式碼留在工作目錄重新檢查 |
| `git reset --hard HEAD~1` | **YES** | **被重置** | **徹底抹除，回到該 commit** | **危險操作！** 徹底拋棄最近的提交與所有修改 |

---

### 4.3 遠端安全撤銷：git revert

若有問題的 Commit **已經 `git push` 到公司遠端 `main` 分支**，絕對不能使用 `git reset --hard` 然後強制推（`git push -f`），這會把別人的程式碼沖掉！

**正確作法：`git revert <commit-id>`**：
Git 會計算該 Commit 的「相反操作」（原本增加的變刪除，原本刪除的變增加），並產生一筆「全新 Commit」推上去。歷史記錄完整保留，隊友 pull 毫無衝突。

---

### 4.4 終極死者甦醒：git reflog 搶救失蹤 Commit

若你不小心手滑執行了 `git reset --hard HEAD~3`，甚至手滑 `git branch -D feature` 刪除了分支，你以為程式碼永遠消失了嗎？
**只要 Commit 曾經被提交過，Git 就絕不會立即刪除它！**

`git reflog`（Reference Logs）會詳細記錄你本地 `HEAD` 指標的所有移動歷史：

```bash
$ git reflog
1a2b3c4 HEAD@{0}: reset: moving to HEAD~3
8f9e0d1 HEAD@{1}: commit: feat(order): 寫了 500 行核心邏輯 (被你誤刪的那次！)
5c6d7e8 HEAD@{2}: checkout: moving from main to feature
```

#### 復活神技：
```bash
# 直接根據 reflog 記錄的 hash 建立新分支復活！
git branch recovery-branch 8f9e0d1
git switch recovery-branch
# 所有程式碼完好如初！
```

---

## 5. 企業級 GitHub 協作工作流與分支保護

### 標準 Pull Request（PR）生命週期

```
Fork / Clone 專案
   |
建立特性分支: git switch -c feat/b2b-credit-check
   |
本機開發、測試並 Commit
   |
推送到遠端: git push -u origin feat/b2b-credit-check
   |
在 GitHub 提出 Pull Request (PR) -> 指定 Reviewer
   |
CI 自動跑測試 (GitHub Actions)
   |
Code Review 討論與修改 (Review Comments)
   |
獲得 2 位同儕 Approve -> Squash & Merge 合入 main
   |
自動刪除遠端特性分支
```

### 企業級 Branch Protection Rules（分支保護策略）：
- **Require a pull request before merging**：禁止任何人直接 `git push origin main`。
- **Require approvals**：至少需要 1~2 位團隊資深成員審查同意。
- **Require status checks to pass before merging**：所有自動化單元測試、Linter 檢查必須為綠燈。
- **Include administrators**：即使是專案 Owner 或主管，也必須遵守 PR 規則，不可特權硬推。

---

## 6. 商業情境綜合練習題（實戰動腦自測）

> 💡 **自我檢驗規範**：請先不要展開解答，在你的本機 Git Repo 中動手操作指令，再點開參考擬答對照！

### 題目一：使用 Interactive Rebase 整理零散的 WIP 提交
**業務情境**：
你在 `feat/quote-export` 分支開發了報價單匯出功能，在開發除錯過程中產生了以下 4 筆凌亂的 Commit：
1. `8a12b3c` - `feat: 增加報價單 PDF 產生基礎框架`
2. `7b23c4d` - `fix: 修復 typo`
3. `6c34d5e` - `wip: 調整樣式到一半`
4. `5d45e6f` - `feat: 完成報價單 PDF 樣式與金額校驗`

在發起 PR 前，主管要求你將這 4 筆 Commit 整理成乾淨的 1 筆規範提交：
`feat(quote): 支援 B2B 報價單 PDF 匯出與格式校驗`。
請寫出完整的命令與互動式 Rebase 操作步驟。

<details>
<summary>🔍 點擊展開「思維引導」</summary>

- 使用 `git rebase -i HEAD~4`。
- 保留第一筆為 `pick`，後續三筆標記為 `squash` (或 `s`)。
- 儲存後在跳出的 Commit Message 編輯器中修改為合規的提交訊息。
</details>

<details>
<summary>🔑 點擊展開「題目一參考擬答」</summary>

```bash
# 1. 針對最近 4 筆 Commit 啟動互動式 Rebase
git rebase -i HEAD~4

# 2. 編輯器中將後續三筆指令改為 squash：
# pick 8a12b3c feat: 增加報價單 PDF 產生基礎框架
# squash 7b23c4d fix: 修復 typo
# squash 6c34d5e wip: 調整樣式到一半
# squash 5d45e6f feat: 完成報價單 PDF 樣式與金額校驗

# 3. 儲存關閉編輯器後，輸入合併後的最終 Commit Message：
# feat(quote): 支援 B2B 報價單 PDF 匯出與格式校驗

# 4. 檢查歷史紀錄
git log --oneline -n 2
```
</details>

---

### 題目二：誤刪未推送分支的絕境救援
**業務情境**：
你在本地分支 `feat/vip-tier-algorithm` 撰寫了整整兩天、高達 800 行的客戶 VIP 分級演算法，且剛在本地完成 `git commit -m "feat(vip): 實作動態分級運算模型"`。
隨後你原本想刪除廢棄的分支 `feat/temp`，卻手滑輸入了：
`git branch -D feat/vip-tier-algorithm`
終端機印出：`Deleted branch feat/vip-tier-algorithm (was d8e9f01).`
該分支從未 `git push` 到遠端。請描述搶救該分支的詳細步驟。

<details>
<summary>🔍 點擊展開「思維引導」</summary>

- 分支名稱被刪除，但指向的 Commit 物件依然存在於 Git 的底層資料庫中！
- 若終端機仍在，直接用印出的 SHA-1 Hash 重新建分支；若終端機已被清空，使用 `git reflog` 查詢 HEAD 移動日誌。
</details>

<details>
<summary>🔑 點擊展開「題目二參考擬答」</summary>

```bash
# 方法一：終端機若尚未關閉，剛剛的訊息已經明確印出 Hash 值: d8e9f01
git checkout -b feat/vip-tier-algorithm d8e9f01

# 方法二：若終端機已被清空，使用 reflog 查詢
git reflog
# 輸出中會找到一筆：
# d8e9f01 HEAD@{1}: commit: feat(vip): 實作動態分級運算模型

# 接著使用該 SHA-1 重新建立並切回該分支：
git branch feat/vip-tier-algorithm d8e9f01
git switch feat/vip-tier-algorithm

# 驗證程式碼是否完全復原
git status
git log -n 1
# 所有 800 行程式碼毫髮無傷，搶救成功！
```
</details>

---

### 題目三：生產環境線上 Hotfix 與特性分支的衝突排解
**業務情境**：
1. 生產環境 `main` 剛合入了一個緊急 Hotfix：修復了 `order.py` 裡的稅率計算從 `0.05` 改為 `tax_rate = Decimal('0.05')` 以避免浮點數誤差。
2. 你的特性分支 `feat/discount` 同時修改了同一段程式碼，加入了階梯折扣邏輯。
3. 當你在本地執行 `git checkout feat/discount` 並嘗試 `git rebase main` 時，發生了 Merge Conflict。
請列出在終端機中解決衝突、驗證程式碼並成功完成 Rebase 的完整工作流。

<details>
<summary>🔍 點擊展開「思維引導」</summary>

- `git rebase main` 遇衝突會暫停。
- 手動編輯衝突檔案，保留雙方需要的變更。
- 解決後 `git add order.py`，接著執行 `git rebase --continue`（切記不要執行 `git commit`）。
</details>

<details>
<summary>🔑 點擊展開「題目三參考擬答」</summary>

```bash
# 1. 執行 rebase 觸發衝突
git checkout feat/discount
git rebase main
# 終端機提示: CONFLICT (content): Merge conflict in order.py

# 2. 查看衝突狀態
git status

# 3. 打開 order.py 找到衝突區塊並融合兩者邏輯：
# <<<<<<< HEAD (來自 main 的 Hotfix)
#     tax_amount = total * Decimal('0.05')
# =======
#     discount = 0.1 if total > 10000 else 0
#     tax_amount = (total - discount) * 0.05
# >>>>>>> feat/discount

# 融合修改為：
#     discount = Decimal('0.10') if total > Decimal('10000') else Decimal('0.00')
#     tax_amount = (total - discount) * Decimal('0.05')

# 4. 標記解決
git add order.py

# 5. 繼續執行 Rebase (注意：此時千萬不要執行 git commit！)
git rebase --continue

# 6. 跑測試驗證
pytest tests/test_orders.py
```
</details>

---

## 🎯 本章收斂總結
> **💡 核心金句**：
> 「提交講究語意化，互動變基整歷史；衝突冷靜看兩端，死者甦醒靠 reflog。」

