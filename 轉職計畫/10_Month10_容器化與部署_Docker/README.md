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

1. [01_Docker與Docker_Compose實戰教學.md](./01_Docker與Docker_Compose實戰教學.md)
   - Docker 核心概念、指令全集與網路隔離原理。
2. [02_雲端部屬策略指南_Render_Railway_VPS.md](./02_雲端部屬策略指南_Render_Railway_VPS.md)
   - 免費/低成本雲端部署步驟指南 (Render / Railway / Fly.io)。
3. [Dockerfile](./Dockerfile)：FastAPI 生產環境輕量化構建檔。
4. [docker-compose.yml](./docker-compose.yml)：一鍵啟動 FastAPI 後端 + PostgreSQL 16 + Adminer GUI。
