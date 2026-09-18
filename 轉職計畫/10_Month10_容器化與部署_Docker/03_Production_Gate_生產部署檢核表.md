# 🚀 M10 Production Gate：雲端部署與生產級檢核表 (Deployment Gate)

> **「在本地電腦跑得動叫玩具，能在雲端持續運行、金鑰不洩漏、容器可隨時銷毀重建、面試官點開 Demo URL 就能玩的，才叫 Production 軟體產品。」**

M10 是你在求職前將作品「公開上線」的最後一哩路。本檢核表不是選配，而是你向面試官展示 **現代 DevOps 與生產就緒素養（Production Readiness）** 的硬核通關閘門。

---

## 📋 測驗標準與三層完成度 (Three-Tier Mastery)

- 🟢 **Level 1 — Survival**：能在本地使用 Dockerfile 與 docker-compose 打包應用並啟動成功。
- 🔵 **Level 2 — Job Ready (80分晉級線)**：
  - 通過 **Production Checklist 10 大檢驗項**。
  - 完成 Multi-stage Build 映像檔瘦身，並以非 root 用戶運行。
  - 部署至雲端（Render / Railway / Fly.io / VPS），擁有可公開連線的 Swagger API 演示網址。
  - 撰寫自動化冒煙測試腳本（`smoke_test.sh`），驗證遠端端點可用性。
- 🔴 **Level 3 — Bonus (Interview Ready)**：
  - 實作 GitHub Actions CI/CD 流水線，程式碼 push 到 main 分支時自動執行測試並建置 Docker Image。
  - 設計 PostgreSQL 定時自動備份腳本（`cron` + `pg_dump` 上傳至 S3/遠端存儲）。

---

## 🚀 生產環境上線 10 大黃金檢核表 (Production Checklist)

上線並向面試官展示前，請逐一打勾驗收：

### 🔒 1. 資訊安全與金鑰防護 (Security & Secrets)
- [ ] **Secrets 不進 Git**：`.env` 與私鑰檔案絕對未提交進 GitHub 歷史紀錄（以 `git log -p` 檢查）。
- [ ] **`.dockerignore` 完備**：排除 `.git`, `.venv`, `__pycache__`, `*.csv` 等雜質，不包進 Docker 映像檔。
- [ ] **Non-root User 運行**：Dockerfile 內建立專屬 `appuser`（如 `USER 1000:1000`），不以 root 最高權限運行應用。

### 📦 2. 映像檔瘦身與可重現性 (Reproducibility)
- [ ] **Multi-stage Build 瘦身**：使用 Builder 階段編譯依賴，最終映像檔體積小於 200MB（杜絕把編譯工具塞進執行環境）。
- [ ] **一鍵重建性 (Idempotent Build)**：在任何一台乾淨的新電腦上，只需 `docker compose up -d` 即可 100% 重建整套系統。

### 💓 3. 穩定性與健康檢查 (Health & Resilience)
- [ ] **存活探針 (Healthcheck)**：FastAPI 實作 `/health` 端點，Compose 設定 `HEALTHCHECK` 確保 DB 連線正常。
- [ ] **重啟策略 (Restart Policy)**：容器配置 `restart: unless-stopped`，伺服器重開機時自動復原。
- [ ] **優雅停機 (Graceful Shutdown)**：支援 `SIGTERM` 信號，等待既有 DB Transaction 提交後再結束行程。

### 🌐 4. 文件與公開演示 (Public Demo & Docs)
- [ ] **公開 Demo URL 可用**：提供面試官可直接點擊測試的公開 URL（如 `https://b2b-api.onrender.com/docs`）。
- [ ] **README 快速啟動說明**：GitHub 首頁附上清晰的 3 步驟啟動指令（Clone ➜ Copy .env ➜ Docker Compose Up）。

---

## 🧪 冒煙測試腳本 (Testing Mindset: Deployment Smoke Test)

部署完成後，執行這段自動化測試腳本，驗證雲端系統真實健康度：

```bash
#!/bin/bash
# smoke_test.sh - 雲端部署冒煙測試
TARGET_HOST="https://your-app-demo.onrender.com"

echo "🔍 正在對雲端環境發起冒煙測試: $TARGET_HOST"

# 1. 測試 Health 端點
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET_HOST/health")
if [ "$HTTP_CODE" -eq 200 ]; then
    echo "✅ [Healthcheck] 系統正常存活 (HTTP 200)"
else
    echo "❌ [Healthcheck] 伺服器異常 (HTTP $HTTP_CODE)"
    exit 1
fi

# 2. 測試 Swagger 文件端點
DOCS_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET_HOST/docs")
if [ "$DOCS_CODE" -eq 200 ]; then
    echo "✅ [Docs] Swagger UI 文件可正常訪問 (HTTP 200)"
else
    echo "❌ [Docs] 文件無法存取 (HTTP $DOCS_CODE)"
    exit 1
fi

# 3. 測試 API 數據查詢延遲 (需小於 1000ms)
TIME_TOTAL=$(curl -s -w "%{time_total}\n" -o /dev/null "$TARGET_HOST/api/v1/analytics/kpi")
echo "⚡ [Latency] 核心 KPI 查詢響應耗時: ${TIME_TOTAL}s"

echo "🎉 冒煙測試全數過關，生產就緒！"
```

---

## 🗣️ 口試題 (Interview Ready - Flashcard 模式)

### Q1：「為什麼在 Dockerfile 裡面寫 `COPY . .` 然後直接以預設 root 權限運行是嚴重的生產資安地雷？」

<details>
<summary>🧠 自我挑戰回想清單（先在腦中整理 15 秒）</summary>

- [ ] 容器內的 root 與主機宿主作業系統的 root 有何關聯？
- [ ] 什麼是容器逃逸（Container Escape）？
- [ ] 為什麼 `COPY . .` 未配置 `.dockerignore` 會外洩敏感資料？
- [ ] 工業級最佳實踐的兩個修復步驟是什麼？
</details>

<details>
<summary>🎯 專家級標準答題話術（點擊展開）</summary>

> **面試官答題話術**：  
> 「這會引發兩大嚴重的生產資安隱患：  
> 1. **容器逃逸（Container Escape）與主機控制權淪陷**：Docker 容器與宿主機共用 Linux 內核。如果容器以預設 root 權限運行，一旦應用程式爆發任意遠端代碼執行（RCE）或提權漏洞，攻擊者便擁有容器內的最高權限；搭配某些未嚴格限制的 Linux Capabilities 或掛載卷，攻擊者極容易穿透隔離屏障逃逸到宿主機，直接取得整台雲端伺服器的 root 控制權！因此生產環境必須遵循最小權限原則（PoLP），透過 `USER appuser` 進行降權運行。  
> 2. **敏感金鑰無差別外洩**：如果直接 `COPY . .` 且未撰寫完整的 `.dockerignore`，本機的 `.env`、AWS 金鑰、`.git` 目錄（包含歷史 commit 紀錄）會被完整封裝進映像檔層級中。只要映像檔被 push 至 Registry 或洩漏，任何拉取該 Image 的人都能輕易讀取全套生產機密。」
</details>

---

### Q2：「在雲端部署時，如果資料庫密碼不能放進 Git，你實務上怎麼讓 Docker 容器讀到？有哪幾種常見管理方案？」

<details>
<summary>🧠 自我挑戰回想清單（先在腦中整理 15 秒）</summary>

- [ ] PaaS（如 Render / Railway）是如何注入環境變數的？
- [ ] CI/CD 流水線（GitHub Actions）如何安全傳遞？
- [ ] 企業級雲端（AWS / GCP / HashiCorp）有哪些專屬 Secret 工具？
- [ ] 容器內部該如何讀取？（環境變數 vs 掛載檔案）
</details>

<details>
<summary>🎯 專家級標準答題話術（點擊展開）</summary>

> **面試官答題話術**：  
> 「在現代雲端架構中，我們絕不將敏感金鑰硬編碼在代碼或提交至 Git，業界常見依架構規模分為三個層次：  
> 1. **PaaS 輕量託管（Render / Railway / Fly.io）**：在平台控制台的 **Environment Variables / Secrets** 介面填入，平台在容器啟動時以安全環境變數自動注入容器內。  
> 2. **CI/CD 自動化整合（GitHub Actions）**：將生產資料庫連線字串存於 Repository 的 **Actions Secrets**，在部署工作流執行時動態注入 SSH / Docker Compose 的啟動命令中。  
> 3. **企業級金鑰保險庫（AWS Secrets Manager / HashiCorp Vault / K8s Secrets）**：應用程式啟動時透過 SDK 搭配 IAM Role 動態拉取短期憑證，或由外部 Orchestrator 將 Secret 掛載為記憶體暫存檔（Tmpfs RAM Disk），杜絕在硬碟或 Image 中留下任何明文痕跡。」
</details>

---

## 📝 結業簽核 (Pass Criteria)

- [ ] Production Checklist 10 大項目全數通過
- [ ] 映像檔完成 Multi-stage 瘦身並以非 root 運行
- [ ] 雲端 Demo URL 正常對外服務
- [ ] 執行 `smoke_test.sh` 冒煙測試 100% 通過

> 通過本關卡，代表你已具備 **Month 10 Production Ready** 的現代雲端工程師部署實力！

---

## 🔗 章節導航

- **前一篇**：[02_雲端部署策略_PaaS與VPS選型實戰.md](./02_雲端部署策略_PaaS與VPS選型實戰.md)（Render/Railway 免費部署、Nginx 反向代理與 HTTPS）
- **邁向下一月**：[Month 11 現代資料堆疊與AI賦能](../11_Month11_AI賦能_智慧資料助理/README.md)（雙軌分流：Airflow 自動化調度與 Text-to-SQL 智慧助理）
- **回到目錄**：[Month 10 學習模組主導航](./README.md)

