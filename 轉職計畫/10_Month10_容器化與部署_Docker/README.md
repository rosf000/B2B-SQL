# Month 10｜容器化與雲端部署：讓所有人都能使用你的服務

> **本月核心目標**：擺脫「在我電腦上可以跑，在你電腦上會壞掉」的窘境。掌握 Docker 映像檔建置、Docker Compose 多容器編排（FastAPI + PostgreSQL + pgAdmin），並將作品一鍵部署至雲端平台（如 Render / Railway / AWS VPS），產出一個有即時線上網址的 Live Demo。

---

## 🎯 本月技能檢核清單

- [ ] 理解 Image (映像檔) vs Container (容器) 的本質差異
- [ ] 撰寫多階段或生產級 `Dockerfile`（基於 python:3.11-slim）
- [ ] 掌握容器埠號映射 (`-p 8000:8000`) 與資料持久化卷軸 (`Volume`)
- [ ] 掌握環境變數注入 (`-e` 與 `.env` 檔案)
- [ ] 掌握 `docker-compose.yml` 編排多服務並設定 Container Networking
- [ ] 掌握容器生命週期指令：`docker compose up -d`, `docker compose down`, `docker logs`
- [ ] 將專案部署至雲端 PaaS / VPS 平台並在履歷附上線上 Live Demo 連結

---

## 📂 本模組教材與容器配置導航

1. [01_Docker進階_多階段建置與容器安全.md](./01_Docker進階_多階段建置與容器安全.md)
   - Docker 核心概念深化（M7 入門的延伸）、Multi-stage Build 鏡像瘦身、非 root 容器安全、指令全集與網路隔離原理。
2. [02_雲端部署策略_PaaS與VPS選型實戰.md](./02_雲端部署策略_PaaS與VPS選型實戰.md)
   - PaaS（Render / Railway / Fly.io）vs 自建 VPS 選型矩陣、Nginx 反向代理、HTTPS 自動憑證、異地備份。
3. [Dockerfile](./Dockerfile)：FastAPI 生產環境輕量化構建檔。
4. [docker-compose.yml](./docker-compose.yml)：一鍵啟動 FastAPI 後端 + PostgreSQL 16 + Adminer GUI。

> **📌 前置知識**：本月的 Docker 內容是 [M7/04_Docker入門_本機開發環境建置.md](../07_Month07_工程素養_Git與Linux/04_Docker入門_本機開發環境建置.md) 的進階延伸，請確認已完成 M7 的 Docker 入門章節。
