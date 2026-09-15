# 🎓 M7 Exit Exam：Docker 網路與容器除錯實戰 (Docker Failure Lab)

> **「幾乎所有初學者第一次把 Python 連上 Docker 資料庫時，都會卡在『為什麼在容器裡連 localhost:5432 會 Connection Refused？明明本機能連啊！』能把 Docker 網路與隔離原理講得透徹的，才是合格的 Junior DE。」**

本測驗不是單純叫你敲 `docker compose up`，而是透過一組 **故意埋下網路與設定炸彈的 Compose 環境**，考察你的排錯診斷能力與 Linux 系統素養。

---

## 📋 測驗標準與三層完成度 (Three-Tier Mastery)

- 🟢 **Level 1 — Survival**：能熟練使用 `docker ps`, `docker logs`, `docker compose down -v` 等基本指令啟動與關閉環境。
- 🔵 **Level 2 — Job Ready (80分晉級線)**：
  - 成功破解並修復以下「localhost 網路陷阱」與「Volume 掛載丟失」地雷。
  - 能使用 `docker exec` 進入容器進行 `ping`、`curl` 與網路連通性診斷。
  - 在 Compose 中配置 Docker 容器存活健康檢查（`HEALTHCHECK`），確保 App 在 DB 完全 Ready 後才啟動。
- 🔴 **Level 3 — Bonus (Interview Ready)**：
  - 深刻解釋 Container 與 VM（虛擬機）在底層架構（Linux Namespace、Cgroups、Shared Kernel）上的本質區別。
  - 解釋 Docker Bridge Network 底層內建的 DNS Service Discovery（服務發現）機制。

---

## 🚨 挑戰案例：一個充滿地雷的 `docker-compose.broken.yml`

某實習生寫了一份 Compose 想要一鍵啟動「FastAPI 應用 + PostgreSQL 資料庫」，但一執行就 Crash：

```yaml
# docker-compose.broken.yml (地雷重重)
version: '3.8'

services:
  database:
    image: postgres:18-alpine
    environment:
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: secretpassword
      POSTGRES_DB: b2b_dw
    ports:
      - "5432:5432"
    # 地雷 1: 缺少 Volume 掛載，容器重啟資料全部蒸發！

  api_service:
    build: .
    environment:
      # 地雷 2: 致命錯誤！Container 裡的 localhost 指向誰？
      DATABASE_URL: "postgresql://admin:secretpassword@localhost:5432/b2b_dw"
    ports:
      # 地雷 3: Port Mapping 顛倒或混淆
      - "80:8000"
    # 地雷 4: 缺少 depends_on 與健康檢查，DB 還在初始化時 App 就搶先連線崩潰
```

---

## 💻 任務一：排錯命令列實戰 (CLI Diagnostics)

請依序執行並回答以下診斷操作：

1. **查閱崩潰原因**：
   - 執行什麼指令能查閱 `api_service` 退出的最後 50 行 Error Traceback？
   - ➜ 答案：`docker compose logs --tail=50 api_service`。
2. **進入容器驗證網路**：
   - 寫出指令透過 `docker exec` 進入執行中的 `api_service`，並嘗試連線 `database` 服務。
3. **檢查容器內部 IP 與網路橋接**：
   - 如何使用 `docker inspect` 找出該容器被分配到的內部 IP 與所屬的 Docker Network？

---

## 🛠️ 任務二：重構為健全的生產級 Compose

請修復上述問題，產出符合工業標準的 `docker-compose.yml`：

### 核心修復要求：
1. **修復資料庫連線網址 (Service Discovery)**：
   - 將 `localhost` 改為 Docker 網路中的服務名 `database`：
     `DATABASE_URL: "postgresql://admin:secretpassword@database:5432/b2b_dw"`
2. **資料持久化 (Named Volume)**：
   - 掛載具名卷冊 `postgres_data:/var/lib/postgresql/data`，保證容器銷毀後重啟資料不遺失。
3. **容器啟動相依性與健康檢查 (Healthcheck & depends_on)**：
   - 為 `database` 增加 `pg_isready` 健康檢查，並讓 `api_service` 設定 `condition: service_healthy`，徹底杜絕 Race Condition。

---

## 🧪 任務三：容器測試 (Testing Mindset)

撰寫一個測試腳本 `verify_docker.sh` 驗證以下 3 點：
1. 啟動後執行 `docker compose ps`，`database` 狀態必須為 `(healthy)`。
2. 在宿主機執行 `curl http://localhost:80/health`，收到 HTTP 200 回應。
3. 執行 `docker compose down` 再重啟，資料庫中的測試資料依然完好如初。

---

## 🗣️ 口試題 (Interview Ready)

1. **「為什麼 Container 裡的 localhost 不等於另一個 Container？也不等於宿主機的 localhost？」**
   - *答題要點*：每個 Docker 容器擁有獨立的 Linux Network Namespace（包含獨立的 loopback 介面 `lo`）。容器內的 `localhost (127.0.0.1)` 永遠只會迴環發給容器自己。要跨容器通訊，必須透過 Docker 建立的虛擬網橋（Bridge Network），藉由 Docker 內置的 DNS 伺服器將服務名稱（如 `database`）解析為容器內部私有 IP。
2. **「Container 和 VM (虛擬機) 差在哪裡？為什麼 Docker 啟動只要 1 秒，VM 卻要 1 分鐘？」**
   - *答題要點*：VM 包含了完整的客體作業系統（Guest OS）與 Hypervisor 硬體虛擬化層；Docker 容器則共享宿主機的作業系統核心（Shared Host Kernel），僅透過 Linux 的 Cgroups 做資源限制、Namespaces 做環境隔離，本質上只是宿主機上的一個受隔離行程（Process），因此啟動極快且極輕量。

---

## 📝 結業簽核 (Pass Criteria)

- [ ] 清楚指出 `docker-compose.broken.yml` 的 4 大地雷並完成修復
- [ ] 成功運行具備 `HEALTHCHECK` 與具名 Volume 的 Compose 環境
- [ ] 能以白話向面試官精確解釋 Container Network Namespace 與 localhost 原理

> 通過本測驗，代表你具備 **Month 07 Job Ready** 的現代容器化排錯實戰能力！
