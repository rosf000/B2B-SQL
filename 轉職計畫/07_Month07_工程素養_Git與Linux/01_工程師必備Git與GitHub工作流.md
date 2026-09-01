# 01 工程師必備 Git 與 GitHub 協作工作流

## 一、專業 Conventional Commits 訊息規範

在 GitHub 上，凌亂的 `update`, `test`, `fix 1`, `fix 2` 會讓面試官扣分。請採用業界標準的前綴：

- `feat:` 新增功能 (Feature)，例如 `feat: add customer fuzzy deduplication algorithm`
- `fix:` 修復 Bug，例如 `fix: handle null tax_id in etl pipeline`
- `docs:` 修改文件，例如 `docs: update architecture diagram in README`
- `style:` 格式調整 (不影響代碼邏輯的縮排或空格)
- `refactor:` 代碼重構 (非新功能也非修 Bug)
- `perf:` 提升效能，例如 `perf: add composite index on orders table`
- `test:` 新增或修改測試用例

---

## 二、Git 實戰指令 Cheatsheet

```bash
# 1. 建立並切換至新功能分支
git checkout -b feat/add-fastapi-routes

# 2. 暫存並提交
git add .
git commit -m "feat: implement crud endpoints for b2b customers"

# 3. 推送至遠端分支
git push -u origin feat/add-fastapi-routes

# 4. 切回主分支並合併
git checkout main
git pull origin main
git merge feat/add-fastapi-routes

# 5. 遇到衝突時 (Merge Conflict)
# 打開衝突檔案保留正確代碼後:
git add .
git commit -m "fix: resolve merge conflicts in schema.sql"
```

---

## 三、標準 `.gitignore` 範本

```gitignore
# 虛擬環境
.venv/
env/
venv/

# Python 快取
__pycache__/
*.py[cod]
*$py.class

# 環境變數與機密金鑰
.env
.env.local
*.pem
*.key

# IDE 設定
.vscode/
.idea/

# 作業系統暫存檔
.DS_Store
Thumbs.db
```
