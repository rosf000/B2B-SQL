# 01. Docker 與 Docker Compose 容器化實戰教學

> 💡 **核心定位**：掌握現代軟體交付金牌標準——**Docker 容器化**。深入理解 Linux 底層隔離（Namespaces 視圖隔離、Cgroups 資源限額、UnionFS 寫時複製），精通多階段建置（Multi-stage Builds）與非 root 安全規範，實現跨環境 100% 一致性部署。  
> ⚠️ **新手常見痛點**：Dockerfile 一把抓把 gcc 等編譯工具全留在生產映像檔造成 1.5GB 臃腫怪獸；直接用 root 帳號跑容器引爆資安逃逸風險；或在 `docker-compose.yml` 僅寫 `depends_on: [db]` 卻未配置 `service_healthy`，導致 API 服務因 DB 尚未完成初始化直接閃退崩潰！  
> 📌 **收斂口訣**：「**多階段分離編譯與運行，非 root 帳號加固防逃逸；相依啟動必綁健康檢查，持久儲存鎖定 Named Volume！**」

---

## 目錄
1. [容器化本質與底層隔離技術](#1-容器化本質與底層隔離技術)
   - [1.1 虛擬機（VM）vs 容器（Container）架構對比](#11-虛擬機vm-vs-容器container架構對比)
   - [1.2 Linux 兩大核心支柱：Namespaces 與 Cgroups](#12-linux-兩大核心支柱namespaces-與-cgroups)
   - [1.3 映像檔分層存儲與 Copy-on-Write（CoW）機制](#13-映像檔分層存儲與-copy-on-writecow機制)
2. [工業級 Dockerfile 撰寫實戰](#2-工業級-dockerfile-撰寫實戰)
   - [2.1 核心指令解析：COPY, RUN, ENTRYPOINT vs CMD](#21-核心指令解析copy-run-entrypoint-vs-cmd)
   - [2.2 構建快取（Build Cache）最大化命中原則](#22-構建快取build-cache最大化命中原則)
   - [2.3 多階段建置（Multi-stage Builds）映像檔瘦身大法](#23-多階段建置multi-stage-builds映像檔瘦身大法)
   - [2.4 容器資安防線：以非 root 專屬用戶運行](#24-容器資安防線以非-root-專屬用戶運行)
3. [資料持久化與容器虛擬網路](#3-資料持久化與容器虛擬網路)
   - [3.1 資料庫持久化首選：Named Volume](#31-資料庫持久化首選named-volume)
   - [3.2 本地熱重載開發神器：Bind Mount](#32-本地熱重載開發神器bind-mount)
   - [3.3 容器內部 DNS 解析機制與 Bridge 網路](#33-容器內部-dns-解析機制與-bridge-網路)
4. [微服務協同編排：Docker Compose 實務](#4-微服務協同編排docker-compose-實務)
   - [4.1 docker-compose.yml 語法解析](#41-docker-composeyml-語法解析)
   - [4.2 依賴健康檢查：depends_on 與 service_healthy](#42-依賴健康檢查depends_on-與-service_healthy)
   - [4.3 高頻維運指令手冊](#43-高頻維運指令手冊)
5. [常見陷阱與企業防坑指南](#5-常見陷阱與企業防坑指南)
6. [商業情境綜合練習題（含詳解）](#6-商業情境綜合練習題含詳解)

---

## 1. 容器化本質與底層隔離技術

### 1.1 虛擬機（VM）vs 容器（Container）架構對比

很多初學者把 Docker 當成輕量化的 VirtualBox，這在觀念上是有偏差的：
- **虛擬機（Virtual Machine）**：透過 Hypervisor 軟體虛擬出完整的「硬體層（Virtual Hardware）」，每個虛擬機都必須運行一個完整的「客體作業系統（Guest OS）」。開機需要數十秒至數分鐘，記憶體開銷動輒數 GB。
- **容器（Container）**：**沒有自己的獨立 OS 核心**，所有容器**直接共享主機宿主作業系統的 Linux 內核（Shared Host Kernel）**。容器本質上只是一個「被 Linux 隔離限制的一般行程（Isolated Process）」，啟動僅需幾十毫秒，額外記憶體開銷幾乎為零。

```
虛擬機架構 (VM):
[ 應用 A ]    [ 應用 B ]
[ Guest OS ]  [ Guest OS ]  <-- 龐大負擔 (數 GB)
[ Hypervisor (VMware/VBox)]
[ 宿主作業系統 Host OS ]
[ 實體伺服器硬體 Server ]

容器架構 (Docker):
[ 應用 A (獨立視圖)]   [ 應用 B (獨立視圖)]
[ Docker Engine (管理行程)]
[ 宿主作業系統 Host OS Kernel (共用核心！)]
[ 實體伺服器硬體 Server ]
```

---

### 1.2 Linux 兩大核心支柱：Namespaces 與 Cgroups

Docker 並非一種全新的作業系統，它巧妙地組合了 Linux 核心的兩大原生功能：
1. **Namespaces（命名空間 - 視圖隔離）**：
   - 讓容器內的程式「誤以為」自己是整台機器唯一的主人。
   - `PID Namespace`：容器內看不到宿主機的其他行程，容器主程式永遠是 PID 1。
   - `NET Namespace`：擁有獨立的虛擬網卡（eth0）、路由表與通訊埠。
   - `MNT Namespace`：擁有獨立掛載的根檔案系統 `/`。
2. **Cgroups（Control Groups 控制群組 - 資源配額）**：
   - 限制容器能使用的 CPU 核心數、記憶體上限（如 `mem_limit: 1G`）。
   - 防止某個記憶體洩漏的容器將整台實體伺服器擠死。

---

### 1.3 映像檔分層存儲與 Copy-on-Write（CoW）機制

Docker 映像檔是以「**層（Layers）**」為單位堆疊的。Dockerfile 中的每一行指令（如 `RUN`, `COPY`）都會生成一個**只讀層（Read-Only Layer）**：
- 當多個容器基於同一個 `python:3.13-slim` 啟動時，它們在硬碟中共用相同的底層 Layer，不會重複佔用磁碟。
- 當容器啟動時，Docker 會在頂層加上一個極薄的「**可寫層（Container R/W Layer）**」。
- 當應用要修改底層檔案時，Docker 採用 **Copy-on-Write（寫時複製）**：將底層檔案複製一份到頂層可寫層進行修改，底層原始映像檔始終乾淨完好。

---

## 2. 工業級 Dockerfile 撰寫實戰

### 2.1 核心指令解析：COPY, RUN, ENTRYPOINT vs CMD

- `WORKDIR /app`：設定工作目錄（相當於進入容器後的預設 `cd /app`）。
- `COPY src dest`：將宿主機檔案複製進映像檔。
- `RUN command`：在**映像檔構建階段（Build time）**執行指令（例如 `pip install`）。
- `EXPOSE 8000`：僅為文檔聲明，提示該映像檔預期監聽的埠號。
- `CMD ["python", "main.py"]`：容器**啟動階段（Run time）**的預設指令，可被 `docker run` 後面的參數輕鬆覆蓋。
- `ENTRYPOINT ["python", "main.py"]`：固化執行檔，後面的參數會被當成引數傳遞給它。

---

### 2.2 構建快取（Build Cache）最大化命中原則

Docker 在構建映像檔時，如果發現指令及輸入檔案自上次構建以來沒有改變，會直接重用「快取層（Cached Layer）」。

#### ❌ 菜鳥寫法（每次修改程式碼，整台重裝 10 分鐘）：
```dockerfile
COPY . /app               # 致命錯誤！只要修改一行 main.py，這層快取就失效！
RUN pip install -r requirements.txt  # 下方所有步驟快取全爆，每次都要重新下載上百個套件！
```

#### ✅ 資深工程師寫法（分離依賴項與業務程式碼）：

> [!TIP]
> **Docker Layer Cache 命中聖經**：
> Dockerfile 每一行指令都會生成一個唯讀層（Layer）。變動頻率越低的指令要放越前面！將 `requirements.txt` 與 `pip install` 獨立拆在前，只要套件清單未改，每次修改業務 Python 程式碼重構映像檔時，就能 100% 命中快取，構建時間從 3 分鐘驟降至 2 秒！

```dockerfile
# 1. 優先單獨 COPY 依賴項清單
COPY requirements.txt /app/
# 2. 安裝依賴（只要 requirements.txt 沒改，此層直接 100% 命中快取，1 秒跳過！）
RUN pip install --no-cache-dir -r requirements.txt
# 3. 最後才 COPY 經常頻繁變動的業務程式碼
COPY . /app/
```

---

### 2.3 多階段建置（Multi-stage Builds）映像檔瘦身大法

傳統 Python 專案若需要安裝 C 語言擴充庫（如 `gcc`, `libpq-dev` 來編譯 psycopg2），編譯完後這些巨大的編譯工具留在映像檔中，會讓 Image 膨脹到 **800MB ~ 1.2GB**，且暗藏資安漏洞。

**多階段建置（Multi-stage Build）** 允許我們在一個 Dockerfile 中使用多個 `FROM`：
- **Stage 1 (Builder)**：下載編譯器，把 Wheel 安裝打包好。
- **Stage 2 (Final Runner)**：使用純淨的 Slim 映像檔，只把 Stage 1 編譯好的 `.venv` 複製過來，丟棄所有無用的編譯工具。映像檔瞬間縮小至 **80MB ~ 120MB**！

---

### 2.4 容器資安防線：以非 root 專屬用戶運行

> [!CAUTION]
> **資安致命雷區：以 root 運行容器**  
> 預設情況下，容器內的進程是以 `root`（UID 0）身份執行的！若你的 API 存在依賴套件漏洞或遠端程式碼執行（RCE），攻擊者攻破容器後可能利用 Linux 內核漏洞進行「容器逃逸 (Container Escape)」，直接掌控整台雲端主機。生產環境務必使用 `USER appuser` 降權運行！

**生產級必備準則**：建立並切換為非特權用戶：
```dockerfile
RUN groupadd -r appgroup && useradd -r -g appgroup -s /sbin/nologin appuser
USER appuser
```

---

## 3. 資料持久化與容器虛擬網路

### 3.1 資料庫持久化首選：Named Volume

> [!IMPORTANT]
> **資料持久化鐵律**：
> 容器本質是短暫無狀態的（Ephemeral）。如果你 `docker rm` 刪除了一個 PostgreSQL 容器，若沒有將 `/var/lib/postgresql/data` 掛載至 Named Volume，裡面的全部資料庫數據會瞬間永久滅失！生產環境一律由 Docker Engine 統一託管 Named Volume。

對於資料庫等關鍵資產，**必須使用 Named Volume** 將資料掛載到宿主機受保護的安全區塊：

```yaml
services:
  db:
    image: postgres:18-alpine
    volumes:
      - pgdata:/var/lib/postgresql/data # 具名磁碟區持久化

volumes:
  pgdata: # 定義持久化儲存卷，容器刪除後資料依舊完好！
```

---

### 3.2 本地熱重載開發神器：Bind Mount

在本地開發時，如果每次改一行程式碼都要重新 `docker build`，開發體驗會極差。
透過 **Bind Mount** 將本機專案目錄直接掛載進容器，搭配 Uvicorn `--reload`，實現本機存檔、容器即刻自動熱重載：

```yaml
services:
  api:
    build: .
    command: uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
    volumes:
      - .:/app  # 將本機當前目錄映射進容器內 /app
```

---

### 3.3 容器內部 DNS 解析機制與 Bridge 網路

初學者最常犯的連線錯誤：在容器中的 FastAPI 程式碼寫 `DATABASE_URL = "postgres://...@localhost:5432/..."`。
**在容器內部，`localhost` 指的是「該容器自己」！**

在 Docker Compose 建立的自定義 Bridge 網路中，內建了 **自動 DNS 服務發現**：
- 容器之間**直接使用 Compose 中的服務名稱（Service Name）互聯**！
- 例如資料庫服務名為 `postgres_db`，連線字串就是：
  `postgresql://user:pass@postgres_db:5432/b2b_erp`

---

## 4. 微服務協同編排：Docker Compose 實務

### 4.1 docker-compose.yml 語法解析

Docker Compose 用宣告式 YAML 檔案定義多個容器的拓撲關係、連接埠映射、環境變數與儲存卷。

### 4.2 依賴健康檢查：depends_on 與 service_healthy

光設定 `depends_on: [db]` 是不夠的！因為 Docker 只知道「PostgreSQL 容器啟動了」，但此時 PostgreSQL 內部的資料庫引擎可能還在重放日誌、並未開放 5432 接受連線。FastAPI 搶先啟動會直接連線被拒閃退。

**最佳實踐：結合 Healthcheck 機制**：
```yaml
services:
  postgres_db:
    image: postgres:18-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 3s
      timeout: 3s
      retries: 5

  fastapi_app:
    build: .
    depends_on:
      postgres_db:
        condition: service_healthy  # 嚴格等待 PostgreSQL 通過健康檢查才啟動！
```

---

### 4.3 高頻維運指令手冊

```bash
# 1. 於後台構建並啟動所有服務
docker compose up -d --build

# 2. 檢視所有執行中容器狀態
docker compose ps

# 3. 即時追蹤特定容器日誌 (-f 滾動追蹤)
docker compose logs -f api

# 4. 進入容器內部執行 Bash 排查問題
docker compose exec api bash

# 5. 停止並刪除所有容器與網路 (保留磁碟卷)
docker compose down

# 6. 停止並連同磁碟卷（Volume）徹底清除重置
docker compose down -v
```

---

## 5. 常見陷阱與企業防坑指南

1. **千萬不要忘記 `.dockerignore`**：
   - 若根目錄沒有 `.dockerignore`，Docker 會將本機龐大的 `.git/`、`.venv/`（包含與 Linux 容器架構不相容的 Windows 二進位檔）、`__pycache__/` 一併打包傳遞給 Docker Daemon，導致 Context 傳輸高達數 GB！
2. **時區問題（Timezone）**：
   - 預設容器均為 UTC 零時區。若業務邏輯需要台灣時間，在 Dockerfile 或 Compose 加入：
     `ENV TZ=Asia/Taipei`。
3. **宿主機 Port 衝突**：
   - 若本機原本就安裝了 PostgreSQL 佔用了 5432，容器映射可改為 `ports: ["5433:5432"]`。

---

## 6. 商業情境綜合練習題（含詳解）

### 題目一：撰寫生產級多階段建置 FastAPI Dockerfile
**業務情境**：
請為 B2B FastAPI 專案撰寫一個生產級的 `Dockerfile`：
1. 第一階段（Builder）：基於 `python:3.13-slim`，安裝編譯必備的 gcc 與 libpq-dev，建立虛擬環境 `.venv` 並安裝 `requirements.txt`。
2. 第二階段（Runner）：同樣基於 `python:3.13-slim`，只安裝執行時必備的 `libpq5`，將 Builder 階段產出的 `.venv` 拷貝過來。
3. 安全規範：建立系統專用帳戶 `b2buser`（UID 10001），禁止使用 root 運行。
4. 設定工作目錄為 `/app`，暴露 8000 埠，並以 Uvicorn 啟動。

<details>
<summary>💡 思維導引與步驟提示（點擊展開）</summary>

1. **分層快取心智**：先複製 `requirements.txt` 再執行 pip 安裝，最後才複製程式碼。
2. **多階段隔離**：Builder 承擔 gcc/headers 等編譯重擔；Runner 僅複製產物 `/opt/venv`，產出乾淨極小的輕量映像檔。
3. **安全降權**：透過 `groupadd` 與 `useradd` 建立非特權帳戶，並宣告 `USER b2buser`。
</details>

<details>
<summary>🎯 參考實作代碼（自我檢測完成後再看）</summary>

```dockerfile
# ==========================================
# 階段一：構建階段 (Builder Stage)
# ==========================================
FROM python:3.13-slim AS builder

WORKDIR /build

# 安裝編譯 C 擴充套件所需的工具
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# 建立獨立虛擬環境
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# 構建快取最佳化：優先複製依賴清單
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# ==========================================
# 階段二：生產運行階段 (Final Runner Stage)
# ==========================================
FROM python:3.13-slim AS runner

WORKDIR /app

# 僅安裝生產執行時期的底層動態連結庫 (不含編譯器)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 設定時區為台北時間
ENV TZ=Asia/Taipei
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# 從 builder 複製已編譯完成的虛擬環境
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# 建立非特權專屬系統帳戶
RUN groupadd -g 10001 b2bgroup && \
    useradd -u 10001 -g b2bgroup -s /sbin/nologin -M b2buser && \
    chown -R b2buser:b2bgroup /app

# 複製應用程式碼並切換擁有者
COPY --chown=b2buser:b2bgroup . /app

# 切換為安全非 root 使用者執行
USER b2buser

EXPOSE 8000

# 啟動命令
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
```
</details>

---

### 題目二：設計編排 FastAPI + PostgreSQL 具備 Healthcheck 的 docker-compose.yml
**業務情境**：
請撰寫一個標準的 `docker-compose.yml`，協同編排：
1. `postgres_db`：使用 `postgres:18-alpine`，設定資料庫名稱為 `b2b_erp`、帳號密碼，配置具名磁碟區 `postgres_data` 持久化，並將包含 `customers`、`orders`、`order_items`、`products`、`salespeople` 表綱要的初始化腳本 `./init_b2b_schema.sql` 掛載至容器內的 `/docker-entrypoint-initdb.d/` 目錄以實現初次啟動自動建表；並配置每 3 秒一次的 `pg_isready` 健康檢查。
2. `api_service`：使用當前目錄 Dockerfile 構建，映射埠號 `8000:8000`，環境變數動態注入資料庫連線字串，並設定 `depends_on` 嚴格等待 `postgres_db` 健康檢查通過後方可啟動。
3. 自定義內部網路 `b2b_network`。

<details>
<summary>💡 思維導引與步驟提示（點擊展開）</summary>

1. **網路與磁碟宣告**：最頂層定義 `networks` 與 `volumes`。
2. **健康檢查配合**：Postgres 服務使用 `pg_isready` 探測；API 服務的 `depends_on` 指定 `condition: service_healthy`。
3. **初始化腳本唯讀掛載**：加入 `:ro` 權限防止容器意外修改本地 SQL 檔案。
</details>

<details>
<summary>🎯 參考實作代碼（自我檢測完成後再看）</summary>

```yaml
version: '3.8'

networks:
  b2b_network:
    driver: bridge

volumes:
  postgres_data:
    driver: local

services:
  postgres_db:
    image: postgres:18-alpine
    container_name: b2b_postgres
    restart: unless-stopped
    networks:
      - b2b_network
    environment:
      POSTGRES_DB: b2b_erp
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: enterprise_secure_password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      # 掛載 B2B 核心表 (customers, orders, products 等) 初始化腳本
      - ./init_b2b_schema.sql:/docker-entrypoint-initdb.d/init_b2b_schema.sql:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d b2b_erp"]
      interval: 3s
      timeout: 3s
      retries: 5
      start_period: 5s

  api_service:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: b2b_fastapi
    restart: unless-stopped
    networks:
      - b2b_network
    ports:
      - "8000:8000"
    environment:
      DATABASE_URL: postgresql+psycopg2://postgres:enterprise_secure_password@postgres_db:5432/b2b_erp
      APP_ENV: production
    depends_on:
      postgres_db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/healthz"]
      interval: 10s
      timeout: 5s
      retries: 3
```
</details>

---

### 題目三：容器連線資料庫故障排查與現場探測 SOP
**業務情境**：
剛執行 `docker compose up -d` 後，發現 `api_service` 頻繁閃退，日誌顯示：
`OperationalError: could not translate host name "postgres_db" to address: Name or service not known`。
請寫出利用 Docker 指令快速定位並修復問題的完整 SOP。

<details>
<summary>💡 思維導引與步驟提示（點擊展開）</summary>

1. **狀態檢查**：先 `docker compose ps` 確認是否有容器重啟或退出。
2. **日誌確認**：`docker compose logs` 看具體崩潰堆疊。
3. **網路探測**：透過 `docker network inspect` 檢查容器是否在同一個 Bridge Network，並臨時執行 `ping` 或 `nc -zv`。
</details>

<details>
<summary>🎯 參考實作代碼（自我檢測完成後再看）</summary>

```bash
# 步驟 1：檢查容器是否都處於 running 狀態
docker compose ps
# 若看到 postgres_db 是 Restarting 或 Exit 狀態，代表資料庫根本沒成功起來！

# 步驟 2：查看資料庫啟動日誌找出崩潰原因
docker compose logs postgres_db
# 常見原因：密碼太短、磁碟空間不足或 Volume 權限衝突

# 步驟 3：檢查網路是否在同一命名空間
# 若兩個 service 未指定相同的 networks，彼此之間是無法透過 DNS 解析名稱的！
docker network inspect <專案名>_b2b_network
# 檢視 "Containers" 列表，確認 api_service 與 postgres_db 的 IP 是否都在該網路內

# 步驟 4：臨時進入 API 容器進行 DNS 解析測試
docker compose run --rm api_service ping -c 2 postgres_db
# 或使用 nc 探測通訊埠:
docker compose run --rm api_service nc -zv postgres_db 5432

# 步驟 5：若確認是設定檔打錯名稱，修改 docker-compose.yml 後重新編排啟動
docker compose up -d --force-recreate
```
</details>

---

## 🎯 本章重點彙整 (Key Takeaways)

```text
┌───────────────────┬──────────────────────────────────────────────────────────┐
│ 核心觀念          │ 工程實踐重點與面試得分點                                 │
├───────────────────┼──────────────────────────────────────────────────────────┤
│ 隔離原理          │ Namespaces 隔離資源視圖、Cgroups 限制硬體資源、UnionFS 分層│
│ 快取優化          │ 先 COPY requirements.txt 再 pip install，最小化構建時間  │
│ 多階段建置        │ Builder 編譯與 Runner 運行分離，映像檔從 1GB 瘦身至 100MB │
│ 非 root 資安      │ 生產容器必須宣告 USER appuser 降權，防範容器逃逸 (Escape) │
│ 持久化與網路      │ 資料庫必掛 Named Volume；微服務依賴 DNS Service Name 互聯 │
└───────────────────┴──────────────────────────────────────────────────────────┘
```

---

## 🔗 章節導航

- **前一篇**：[00_本月學習計畫與目標.md](./00_本月學習計畫與目標.md)（Docker 4 週學習排程與交付成果）
- **下一篇**：[02_雲端部署策略_PaaS與VPS選型實戰.md](./02_雲端部署策略_PaaS與VPS選型實戰.md)（Render/Railway 免費部署、Nginx 反向代理與 HTTPS）
- **部署檢核**：[03_Production_Gate_生產部署檢核表.md](./03_Production_Gate_生產部署檢核表.md)（10 大生產檢核標準與冒煙測試）
- **回到目錄**：[Month 10 學習模組主導航](./README.md)

