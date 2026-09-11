# 04. Docker 入門：容器化概念與本機開發環境實作

> **模組目標**：理解 Docker 的核心思維，並在本機用 `docker-compose` 一鍵啟動 PostgreSQL + PgAdmin 開發環境。這是 M8 旗艦作品能順利啟動的前提，也是所有現代工程師的必備素養。

---

## 目錄

1. [為什麼需要 Docker？](#1-為什麼需要-docker)
2. [核心概念：Image、Container、Volume](#2-核心概念imagcontainervolume)
3. [安裝 Docker Desktop](#3-安裝-docker-desktop)
4. [你的第一個 Container](#4-你的第一個-container)
5. [撰寫 Dockerfile](#5-撰寫-dockerfile)
6. [docker-compose：多容器編排](#6-docker-compose多容器編排)
7. [實作：一鍵啟動 PostgreSQL + PgAdmin](#7-實作一鍵啟動-postgresql--pgadmin)
8. [常用指令速查表](#8-常用指令速查表)
9. [Checkpoint](#9-checkpoint)

---

## 1. 為什麼需要 Docker？

你一定遇過這個情況：

```
你（本機 Windows）：「程式跑得好好的！」
同事（Mac）：「我這邊跑不起來…」
面試官（Linux 伺服器）：「你的作品我怎麼啟動？」
```

**沒有 Docker 的世界：**
```
你的本機 → 手動安裝 PostgreSQL 14.2、Python 3.11、設定環境變數...
同事的電腦 → 重複一遍，版本不一定一樣 → 出錯
面試官的伺服器 → 再重複一遍 → 更多出錯
```

**有 Docker 的世界：**
```
git clone your-project
docker-compose up      ← 一行指令，所有人的環境都一樣
```

Docker 把你的程式和它需要的所有環境（OS、套件、設定）打包成一個**可移動的盒子（Container）**，在任何電腦上都能一模一樣地執行。

---

## 2. 核心概念：Image、Container、Volume

### 2.1 三個必懂名詞

| 概念 | 比喻 | 說明 |
|:---|:---|:---|
| **Image（映像檔）** | 蛋糕食譜 | 靜態的藍圖，定義了這個環境長什麼樣 |
| **Container（容器）** | 實際烤出來的蛋糕 | 根據 Image 啟動的執行中實例，可以有很多個 |
| **Volume（資料卷）** | 蛋糕放的盤子 | 讓資料在 Container 關掉後不消失 |

```
Docker Hub（雲端倉庫）
    │
    │  docker pull postgres:16
    ▼
Image（postgres:16）← 靜態的藍圖，存在你的硬碟
    │
    │  docker run ...
    ▼
Container（執行中的 PostgreSQL）← 活的實例
    │
    │  Volume 掛載
    ▼
資料持久化（即使 Container 重啟，資料不消失）
```

### 2.2 Image 從哪來？

```
來源 1：Docker Hub（官方/社群 Image）
  - docker pull postgres:16
  - docker pull python:3.11-slim
  - docker pull nginx:alpine

來源 2：自己的 Dockerfile 建構
  - 從基底 Image 開始（FROM python:3.11-slim）
  - 加入你的程式碼和設定
  - docker build -t my-app .
```

---

## 3. 安裝 Docker Desktop

### Windows 安裝步驟

1. 前往 [https://www.docker.com/products/docker-desktop/](https://www.docker.com/products/docker-desktop/)
2. 下載 **Docker Desktop for Windows**
3. 安裝時確認勾選 **Use WSL 2 instead of Hyper-V**（效能更好）
4. 安裝完成後重新啟動電腦

### 驗證安裝成功

```bash
docker --version
# 應該看到：Docker version 25.x.x, build ...

docker-compose --version
# 應該看到：Docker Compose version v2.x.x
```

> ⚠️ **注意**：如果 `docker-compose` 失敗，改試 `docker compose`（新版用空格，不用連字號）

---

## 4. 你的第一個 Container

不需要先安裝 PostgreSQL，直接用 Docker 跑一個：

```bash
# 啟動一個 PostgreSQL 容器
docker run \
  --name my-first-postgres \
  -e POSTGRES_USER=admin \
  -e POSTGRES_PASSWORD=secret123 \
  -e POSTGRES_DB=testdb \
  -p 5432:5432 \
  -d \
  postgres:16
```

**參數解釋：**

| 參數 | 說明 |
|:---|:---|
| `--name my-first-postgres` | 幫這個 Container 取名字，方便後續管理 |
| `-e POSTGRES_USER=admin` | 設定環境變數（這是 PostgreSQL 的帳號） |
| `-p 5432:5432` | 本機 port 5432 → Container 內部 port 5432 |
| `-d` | Detached mode，在背景執行，不佔用 Terminal |
| `postgres:16` | 使用的 Image（會自動從 Docker Hub 下載） |

```bash
# 確認 Container 在執行
docker ps

# 輸出類似：
# CONTAINER ID   IMAGE         COMMAND                  CREATED         STATUS         PORTS                    NAMES
# a1b2c3d4e5f6   postgres:16   "docker-entrypoint.s…"  2 minutes ago   Up 2 minutes   0.0.0.0:5432->5432/tcp   my-first-postgres

# 停止 Container
docker stop my-first-postgres

# 刪除 Container（資料也消失）
docker rm my-first-postgres
```

---

## 5. 撰寫 Dockerfile

Dockerfile 是建構你自己的 Image 的說明書。

### Python 應用的標準 Dockerfile

```dockerfile
# Dockerfile

# ── Step 1：選擇基底 Image ─────────────────────────────────────
# slim 版本比完整版小很多（~40MB vs ~900MB）
FROM python:3.11-slim

# ── Step 2：設定工作目錄 ──────────────────────────────────────
WORKDIR /app

# ── Step 3：先複製依賴清單（利用 Docker 快取加速建構）────────
COPY requirements.txt .

# ── Step 4：安裝 Python 套件 ─────────────────────────────────
RUN pip install --no-cache-dir -r requirements.txt

# ── Step 5：複製程式碼 ────────────────────────────────────────
COPY . .

# ── Step 6：定義啟動指令 ─────────────────────────────────────
CMD ["python", "src/main.py"]
```

**為什麼 COPY requirements.txt 和 COPY . 要分兩步？**

```
第一次 build：
  Step 3 COPY requirements.txt  → 建立快取層
  Step 4 RUN pip install        → 建立快取層
  Step 5 COPY .                 → 建立快取層

第二次 build（只改了 Python 程式碼）：
  Step 3 COPY requirements.txt  → ✅ 快取命中，直接跳過
  Step 4 RUN pip install        → ✅ 快取命中，直接跳過
  Step 5 COPY .                 → 程式碼改了，重新執行
```

這樣每次修改程式碼重 build 時，不需要重新安裝全部套件，速度快很多。

### 建構並執行

```bash
# 建構 Image（. 表示 Dockerfile 在目前目錄）
docker build -t my-python-app .

# 執行
docker run my-python-app
```

---

## 6. docker-compose：多容器編排

實際開發通常需要多個服務同時跑：Python 應用 + PostgreSQL + PgAdmin。
手動一個個 `docker run` 很麻煩，`docker-compose` 可以用一個 YAML 檔案管理所有服務。

### docker-compose.yml 基本結構

```yaml
# docker-compose.yml

version: "3.9"

services:        # 定義所有服務
  服務名稱:
    image: 或 build:
    environment:   # 環境變數
    ports:         # Port 映射
    volumes:       # 資料掛載
    depends_on:    # 依賴關係（這個服務要等哪個先啟動）

volumes:         # 定義 Named Volumes（讓資料持久化）
```

### 常用指令

```bash
# 啟動所有服務（背景執行）
docker-compose up -d

# 停止所有服務（Container 仍保留）
docker-compose stop

# 停止並刪除 Container
docker-compose down

# 停止並刪除 Container + Volume（資料也清掉）
docker-compose down -v

# 查看服務狀態
docker-compose ps

# 查看某服務的 log
docker-compose logs postgres

# 進入某個 Container 的 shell
docker-compose exec postgres bash
```

---

## 7. 實作：一鍵啟動 PostgreSQL + PgAdmin

這是 M8 旗艦作品的開發環境基礎。建立以下檔案：

### 目錄結構

```
my-dev-env/
├── docker-compose.yml
├── .env                  ← 放敏感設定（不能 git commit）
└── .gitignore
```

### .env 檔案

```bash
# .env（這個檔案不能 commit 到 Git！）
POSTGRES_USER=b2b_admin
POSTGRES_PASSWORD=your_secure_password_here
POSTGRES_DB=b2b_platform
PGADMIN_EMAIL=admin@b2b.com
PGADMIN_PASSWORD=pgadmin_password_here
```

### .gitignore 確認

```gitignore
# .gitignore（一定要有這行）
.env
```

### docker-compose.yml

```yaml
# docker-compose.yml

version: "3.9"

services:
  # ── PostgreSQL 資料庫 ──────────────────────────────────────
  postgres:
    image: postgres:16-alpine        # alpine 版本更輕量
    container_name: b2b_postgres
    restart: unless-stopped          # 電腦重開後自動啟動
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    ports:
      - "5432:5432"                  # 讓本機 DBeaver 可以連
    volumes:
      - postgres_data:/var/lib/postgresql/data   # 資料持久化
    healthcheck:                     # 健康檢查
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5

  # ── PgAdmin（資料庫 GUI 管理介面）─────────────────────────
  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: b2b_pgadmin
    restart: unless-stopped
    environment:
      PGADMIN_DEFAULT_EMAIL: ${PGADMIN_EMAIL}
      PGADMIN_DEFAULT_PASSWORD: ${PGADMIN_PASSWORD}
    ports:
      - "5050:80"                    # 瀏覽器開 http://localhost:5050
    depends_on:
      postgres:
        condition: service_healthy   # 等 PostgreSQL 健康後才啟動
    volumes:
      - pgadmin_data:/var/lib/pgadmin

volumes:
  postgres_data:    # PostgreSQL 的資料永久保存
  pgadmin_data:     # PgAdmin 的設定永久保存
```

### 啟動與驗證

```bash
# 1. 啟動所有服務
docker-compose up -d

# 2. 確認狀態（兩個服務都應該是 running）
docker-compose ps

# 輸出：
# NAME            IMAGE                   STATUS          PORTS
# b2b_pgadmin     dpage/pgadmin4:latest   Up 30 seconds   0.0.0.0:5050->80/tcp
# b2b_postgres    postgres:16-alpine      Up 35 seconds   0.0.0.0:5432->5432/tcp

# 3. 測試 PostgreSQL 連線
docker-compose exec postgres psql -U b2b_admin -d b2b_platform -c "\l"
```

### 連線 PgAdmin

1. 開啟瀏覽器：`http://localhost:5050`
2. 登入：`admin@b2b.com` / `pgadmin_password_here`
3. 右鍵 **Servers → Register → Server**
4. **General Tab** → Name: `B2B Dev`
5. **Connection Tab**：
   - Host: `postgres`（用 service 名稱，不是 localhost！）
   - Port: `5432`
   - Username: `b2b_admin`
   - Password: `your_secure_password_here`

> ⚠️ **重要**：在 docker-compose 網路中，服務之間用 **service 名稱**互相連線，不是 `localhost`。

### 連線 DBeaver（可選）

- Host: `localhost`（從電腦外部連就用 localhost）
- Port: `5432`
- Database: `b2b_platform`
- User/Password: 同 `.env` 設定

---

## 8. 常用指令速查表

### Container 管理

```bash
docker ps                    # 列出執行中的 Container
docker ps -a                 # 列出所有 Container（含已停止）
docker stop <名稱或ID>        # 停止 Container
docker start <名稱或ID>       # 啟動已停止的 Container
docker rm <名稱或ID>          # 刪除 Container
docker logs <名稱或ID>        # 查看 log
docker logs -f <名稱或ID>     # 持續追蹤 log（Ctrl+C 離開）
docker exec -it <名稱> bash   # 進入 Container 的 shell
```

### Image 管理

```bash
docker images                # 列出本機所有 Image
docker pull postgres:16      # 下載 Image
docker rmi <Image ID>        # 刪除 Image
docker build -t <名稱> .     # 根據 Dockerfile 建構 Image
```

### docker-compose 管理

```bash
docker-compose up -d         # 啟動（背景）
docker-compose down          # 停止並刪除 Container
docker-compose down -v       # 停止並刪除 Container + Volume
docker-compose ps            # 查看狀態
docker-compose logs -f       # 追蹤所有服務 log
docker-compose exec <服務> bash  # 進入服務的 shell
docker-compose restart <服務>    # 重新啟動某個服務
```

### 空間清理

```bash
docker system prune          # 清除所有未使用的資源（謹慎使用）
docker volume prune          # 清除未掛載的 Volume
```

---

## 9. Checkpoint

完成本章後，你應該能達成以下標準：

```
□ docker --version 能看到版本號
□ 理解 Image / Container / Volume 的差別（能向他人解釋）
□ 能用 docker run 啟動一個 Container，並用 docker ps 確認
□ 能撰寫一個基本的 Dockerfile（FROM, WORKDIR, COPY, RUN, CMD）
□ 能撰寫 docker-compose.yml 啟動 PostgreSQL + PgAdmin
□ docker-compose up -d 成功，兩個服務都是 running 狀態
□ 能用瀏覽器開啟 http://localhost:5050 並登入 PgAdmin
□ 能連線 PostgreSQL 並執行 \l 看到資料庫清單
□ .env 有加入 .gitignore（不能把密碼 commit 到 GitHub！）
```

---

## 連結下一步

M7 完成後，M8 旗艦作品的開發環境已經準備好了：

```
M7 完成 ✅
  ├── Git 工作流（分支、PR、Commit 規範）
  ├── Linux 基本指令
  ├── GitHub README 撰寫技巧
  └── Docker 本機開發環境 ← 本章

M8 開始 →
  └── 用 docker-compose up 啟動 PostgreSQL
  └── 把 M3 的 B2B Schema 匯入
  └── 整合 M5 的 ETL Pipeline
  └── 整合 M6 的 Data Quality 模組
  └── 完成旗艦作品 v1.0
```
