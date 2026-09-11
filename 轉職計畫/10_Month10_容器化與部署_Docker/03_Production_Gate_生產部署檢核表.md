# 🚀 M10 Production Gate：雲端部署與生產級檢核表 (Deployment Gate)

> **「在本地電腦跑得動叫玩具，能在雲端持續運行、金鑰不洩漏、容器可隨時銷毀重建、面試官點開 Demo URL 就能玩的，才叫 Production 軟體產品。」**

M10 是你在求職前將作品「公開上線」的最後一哩路。本檢核表不是選配，而是你向面試官展示 **現代 DevOps 與生產就緒素養（Production Readiness）** 的硬核通關閘門。

---

## 📋 測驗標準與三層完成度 (Three-Tier Mastery)

- 🟢 **Level 1 — Survival**：能在本地使用 Dockerfile 與 docker-compose 打包應用並啟動成功。
- 🔵 **Level 2 — Job Ready (80分晉級線)**：
  - 通過 **Production Checklist 10 大檢驗項**。
  - 完成 Multi-stage Build 鏡像瘦身，並以非 root 用戶運行。
  - 部署至雲端（Render / Railway / Fly.io / VPS），擁有可公開連線的 Swagger API 演示網址。
  - 撰寫自動化冒煙測試腳本（`smoke_test.sh`），驗證遠端端點可用性。
- 🔴 **Level 3 — Bonus (Interview Ready)**：
  - 實作 GitHub Actions CI/CD 流水線，代碼 push 到 main 分支時自動執行測試並建置 Docker Image。
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

## 🗣️ 口試題 (Interview Ready)

1. **「為什麼在 Dockerfile 裡面寫 `COPY . .` 然後直接 run root 是嚴重的資安地雷？」**
   - *答題要點*：若攻擊者利用應用漏洞（如 RCE 遠端代碼執行）攻破容器，以 root 運行的駭客可能透過 Container Escape（逃逸）直接取得宿主機的最高控制權！採用非 root 帳號能有效限縮攻擊面。
2. **「在雲端部署時，如果資料庫密碼不能放進 Git，你實務上怎麼讓 Docker 容器讀到？有哪幾種常見管理方案？」**
   - *答題要點*：雲端平台的 Secret Management（如 Render Environment Variables、AWS Secrets Manager、Vault）或 Docker Swarm / K8s Secrets。在 CI/CD 中透過 GitHub Actions Encrypted Secrets 注入。

---

## 📝 結業簽核 (Pass Criteria)

- [ ] Production Checklist 10 大項目全數通過
- [ ] 映像檔完成 Multi-stage 瘦身並以非 root 運行
- [ ] 雲端 Demo URL 正常對外服務
- [ ] 執行 `smoke_test.sh` 冒煙測試 100% 通過

> 通過本關卡，代表你已具備 **Month 10 Production Ready** 的現代雲端工程師部署實力！
