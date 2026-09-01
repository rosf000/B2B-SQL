# 02 雲端部署策略指南 (Render / Railway / VPS)

## 一、免費/低成本雲端 PaaS 平台推薦

對於轉職者建立作品集 Demo，**強烈建議使用現代 PaaS 平台**，省去繁重的 Linux 網路安全防火牆設定：

1. **Render (render.com)**：
   - 支援直接綁定 GitHub Repo，只要 Repo 內有 `Dockerfile` 或 `requirements.txt`，每次 Git Push 自動觸發 CI/CD 構建並更新線上網址。
   - 提供免費/低價的 Managed PostgreSQL 資料庫。
2. **Railway (railway.app)**：
   - 極佳的 UI 體驗，一鍵新增 Dockerized FastAPI 與 PostgreSQL 服務。

---

## 二、部署至 Render 標準步驟

1. 將專案推上個人的 GitHub 倉庫（確保根目錄有 `Dockerfile` 或 `render.yaml`）。
2. 登入 Render ➜ 點擊「New +」➜ 選擇 **Web Service**。
3. 連接你的 GitHub Repo。
4. 設定環境變數 (Environment Variables)：
   - `DATABASE_URL`: 填入 Render 提供的 Managed PostgreSQL 連線字串。
5. 點擊 **Deploy**，約 2~3 分鐘後即可獲得公網 HTTPS 專屬網址（例如：`https://b2b-api-demo.onrender.com/docs`）。
