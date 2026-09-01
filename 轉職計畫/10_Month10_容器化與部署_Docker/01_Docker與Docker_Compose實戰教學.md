# 01 Docker 與 Docker Compose 實戰教學

## 一、Docker 核心四大天王

1. **Dockerfile**：自動化建置 Image 的食譜配方。
2. **Image (映像檔)**：只讀的應用程式打包範本（包含 OS 系統底層、Python 環境、依賴庫與程式代碼）。
3. **Container (容器)**：Image 運行起來的實例（動態、隔離、輕量）。
4. **Volume (資料卷)**：將容器內的檔案目錄掛載至主機硬碟，確保資料庫重啟後資料不遺失。

---

## 二、常用 Docker 指令全集

```bash
# 1. 構建映像檔
docker build -t b2b-api:latest .

# 2. 運行單一容器
docker run -d -p 8000:8000 --name my-api b2b-api:latest

# 3. 檢視運行中的容器
docker ps

# 4. 檢視容器內部日誌
docker logs -f my-api

# 5. 進入容器內部終端機 (Bash)
docker exec -it my-api /bin/bash

# 6. Docker Compose 一鍵操作
docker compose up -d      # 背景啟動所有服務
docker compose down        # 停止並移除所有容器與虛擬網路
docker compose down -v     # 停止並同時清空資料卷 (危險！會清空 DB)
```
