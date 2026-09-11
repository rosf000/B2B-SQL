# 02. 雲端部署策略指南：Render、Railway 與獨立 VPS 實戰

> **模組目標**：將你在本機打造的 B2B 資料庫與 FastAPI 微服務正式交付至網際網路。全面評估現代 PaaS（Render / Railway / Fly.io）與獨立 VPS（Ubuntu 雲端主機）的架構與成本選型矩陣；精通 Linux 伺服器安全加固 SOP（UFW 防火牆、Fail2ban、SSH 金鑰防護）；掌握 Nginx 反向代理配置與 Let's Encrypt 自動 HTTPS 憑證簽發；建立具備異地資料庫備份與健康監控的企業級生產環境。

---

## 目錄
1. [雲端部屬方案選型矩陣：PaaS vs 自建 VPS](#1-雲端部屬方案選型矩陣paas-vs-自建-vps)
   - [1.1 PaaS（Render / Railway / Fly.io）架構特性](#11-paasrender--railway--flyio架構特性)
   - [1.2 自建 VPS（DigitalOcean, Linode, AWS Lightsail）架構特性](#12-自建-vpsdigitalocean-linode-aws-lightsail架構特性)
   - [1.3 企業初期選型決策樹與成本精算](#13-企業初期選型決策樹與成本精算)
2. [PaaS 快速上線指南：以 Render / Railway 為例](#2-paas-快速上線指南以-render--railway-為例)
   - [2.1 GitHub 聯動自動持續整合與部署（CI/CD）](#21-github-聯動自動持續整合與部署cicd)
   - [2.2 雲端 PostgreSQL 託管與內外部連線字串管理](#22-雲端-postgresql-託管與內外部連線字串管理)
   - [2.3 免費/入門方案休眠問題（Spin-down）與保活心跳](#23-免費入門方案休眠問題spin-down與保活心跳)
3. [專業級獨立 VPS 部署實戰（Ubuntu + Docker + Nginx）](#3-專業級獨立-vps-部署實戰ubuntu--docker--nginx)
   - [3.1 VPS 安全加固四大標準 SOP](#31-vps-安全加固四大標準-sop)
   - [3.2 現代反向代理（Reverse Proxy）：Nginx 核心配置](#32-現代反向代理reverse-proxynginx-核心配置)
   - [3.3 自動簽發免費用戶端 HTTPS：Certbot 與 Let's Encrypt](#33-自動簽發免費用戶端-httpscertbot-與-lets-encrypt)
4. [高可用維運：異地備份與監控告警](#4-高可用維運異地備份與監控告警)
   - [4.1 PostgreSQL 異地定時備份至 S3 / Cloudflare R2](#41-postgresql-異地定時備份至-s3--cloudflare-r2)
   - [4.2 零成本服務監控：UptimeRobot 與 Sentry 整合](#42-零成本服務監控uptimerobot-與-sentry-整合)
5. [商業情境綜合練習題（含詳解）](#5-商業情境綜合練習題含詳解)

---

## 1. 雲端部屬方案選型矩陣：PaaS vs 自建 VPS

把程式碼部署到雲端，主要有兩大主流路線：

| 評估維度 | PaaS 平台 (Render / Railway) | 獨立 VPS (Ubuntu @ Lightsail / Linode) |
| :--- | :--- | :--- |
| **運維心智負擔** | **極低**（點幾下滑鼠即可上線） | **中至高**（需自行維護 Linux、防火牆、Docker） |
| **部署方式** | `git push` 後自動觸發 Webhook 建置 | 透過 SSH 登入拉取程式碼，或透過 GitHub Actions 部署 |
| **HTTPS 憑證** | 平台自動免費簽發與自動續期 | 需手動配置 Nginx 與 Certbot |
| **硬體資源性價比** | 較低（1GB RAM 方案約 $7~$15/月） | **極高**（$4~$6/月即可享有 1GB~2GB RAM, 獨立 IPv4） |
| **資料庫控制度** | 受限（備份通常依賴平台面板或付費加購） | **100% 完全掌控**（可客製化 pg_hba、延伸擴充模組） |
| **適用階段** | **求職展示、MVP 驗證、前導專案快速 Demo** | **企業正式生產環境、預算有限且追求高性價比的中小型系統** |

---

## 2. PaaS 快速上線指南：以 Render / Railway 為例

### 2.1 GitHub 聯動自動持續整合與部署（CI/CD）

現代 PaaS 平台最吸引人之處在於它的 **Git-Ops** 開發體驗：
1. 在 GitHub 建立專案倉庫，包含根目錄的 `Dockerfile`。
2. 登入 Render.com，點選 **New -> Web Service**，授權並連結你的 GitHub 倉庫。
3. 選擇 **Runtime: Docker**。
4. 每當你本地 `git push origin main`，Render 會自動檢測到變更、在雲端執行 `docker build` 並以無中斷（Rolling update）方式替換新舊容器！

---

### 2.2 雲端 PostgreSQL 託管與內外部連線字串管理

在 Render 建立 Managed PostgreSQL 時，它會提供兩個連線字串（Connection Strings）：
1. **Internal Database URL**（內部連線字串）：
   - 格式：`postgres://user:pass@dpg-xxxxx-a:5432/b2b_erp`
   - **特點**：流量走 Render 內網私有虛擬網路，**速度極快、且免收任何外網出流量費用（Egress Bandwidth Fee）**。你的 FastAPI 服務的環境變數 `DATABASE_URL` 務必填寫此內部字串！
2. **External Database URL**（外部連線字串）：
   - 格式：`postgres://user:pass@dpg-xxxxx-a.oregon-postgres.render.com:5432/b2b_erp`
   - **特點**：開放給公網存取，供你在本機透過 DBeaver、Navicat 進行資料庫管理維護使用。

---

### 2.3 免費/入門方案休眠問題（Spin-down）與保活心跳

在 Render 免費層級中，Web 服務若在 15 分鐘內沒有收到任何 HTTP 流量，會自動「休眠（Spin-down）」。
當下一個訪客進入時，伺服器需要重啟容器，導致首頁載入出現長達 **50 秒至 1 分鐘的白畫面冷啟動（Cold Start）**。這在面試官點開你的作品時是致命傷！

#### 企業級破解保活手段：
使用免費的監控服務（如 **UptimeRobot** 或 **Cron-job.org**），設定每 10 分鐘向你的 `/healthz` 端點發送一次 HTTP GET 探針，既能達成 7x24 避免休眠，又能即時監控伺服器存活率！

---

## 3. 專業級獨立 VPS 部署實戰（Ubuntu + Docker + Nginx）

### 3.1 VPS 安全加固四大標準 SOP

在購買一台全新的 Ubuntu VPS（如 AWS Lightsail $5/月）後，**絕不能直接放行上線**。公網上每秒都有數以萬計的自動化肉雞在掃描預設 22 埠進行暴力破解。

#### 步驟 1：建立專屬管理帳戶，禁止 root 登入
```bash
# 建立非 root 管理員
adduser deployer
usermod -aG sudo deployer

# 拷貝公鑰到 deployer
mkdir -p /home/deployer/.ssh
cp /root/.ssh/authorized_keys /home/deployer/.ssh/
chown -R deployer:deployer /home/deployer/.ssh
chmod 700 /home/deployer/.ssh
chmod 600 /home/deployer/.ssh/authorized_keys

# 修改 SSH 伺服器設定
sudo nano /etc/ssh/sshd_config
# 修改以下三項：
# Port 2222                 (修改預設 22 埠，避開 99% 的無腦掃描)
# PermitRootLogin no        (絕對禁止 root 帳號透過 SSH 登入)
# PasswordAuthentication no (絕對禁止密碼登入，僅允許 SSH Key 私鑰)

# 重啟 SSH 服務
sudo systemctl restart ssh
```

#### 步驟 2：配置 UFW（Uncomplicated Firewall）防火牆
```bash
# 預設拒絕所有進來流量，允許所有外出流量
sudo ufw default deny incoming
sudo ufw default allow outgoing

# 開放自定義 SSH 埠號、HTTP (80) 與 HTTPS (443)
sudo ufw allow 2222/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# 絕對不要對外開放 5432 (PostgreSQL)，只允許本機內部容器訪問！
# 啟動防火牆
sudo ufw enable
```

#### 步驟 3：安裝 Fail2ban（防暴力密碼猜測）
```bash
sudo apt update && sudo apt install -y fail2ban
# 若 10 分鐘內密碼猜錯 5 次，直接封鎖該 IP 24 小時！
sudo systemctl enable --now fail2ban
```

---

### 3.2 現代反向代理（Reverse Proxy）：Nginx 核心配置

**為什麼不在 Docker 中直接把 FastAPI 暴露在 80/443 埠？**
- **SSL 終端解密（SSL Termination）**：由專門優化過的 C 語言 Nginx 處理 TLS 加密與握手，卸載後端 Python 的 CPU 負擔。
- **靜態資源極速傳輸**：前端 HTML/CSS/JS 由 Nginx 直接發送，不經 Python。
- **統一路由轉發**：單一網域名稱可同時分發給多個容器（如 `/api` 導向 FastAPI，`/` 導向前端，`/pgadmin` 導向管理面板）。

---

### 3.3 自動簽發免費用戶端 HTTPS：Certbot 與 Let's Encrypt

```bash
# 1. 安裝 Certbot 與 Nginx 外掛
sudo apt install -y certbot python3-certbot-nginx

# 2. 自動申請憑證並由 Certbot 自動修改 Nginx 設定檔！
sudo certbot --nginx -d b2b.yourdomain.com

# 3. 測試自動續期定時任務 (Let's Encrypt 憑證效期 90 天，系統會自動在到期前 30 天排程續約)
sudo certbot renew --dry-run
```

---

## 4. 高可用維運：異地備份與監控告警

### 4.1 PostgreSQL 異地定時備份至 S3 / Cloudflare R2

若雲端機房發生硬碟損壞或機房大火，本地備份檔會隨主機一同陣亡。真正的生產級備份必須做到**異地保存（Off-site Backup）**。
利用 Cloudflare R2（提供每月 10GB 免費儲存與 100% 零出流量費用）是獨立工程師首選。

---

### 4.2 零成本服務監控：UptimeRobot 與 Sentry 整合

- **服務可用性監控（Uptime Monitoring）**：
  - 免費使用 **UptimeRobot**，設定每 5 分鐘探測一次 `https://b2b.yourdomain.com/healthz`。
  - 一旦伺服器掛掉，UptimeRobot 會在 1 分鐘內透過 Email 或 LINE / Telegram 發出即時警報。
- **應用異常追蹤（Application Performance Monitoring）**：
  - 安裝 `sentry-sdk`：`pip install sentry-sdk`
  - 當 FastAPI 發生未捕捉的 500 錯誤時，Sentry 自動將完整的錯誤堆疊、呼叫參數與客戶端請求資訊即時傳至儀表板。

---

## 5. 商業情境綜合練習題（含詳解）

### 題目一：生產級 Nginx 反向代理配置（含 HTTPS 強制重定向與 Gzip 壓縮）
**業務情境**：
請撰寫一個標準的 Nginx 設定檔 `/etc/nginx/sites-available/b2b_erp.conf`：
1. 監聽 80 埠號，將所有 HTTP 明文請求以 301 永久重定向導向 HTTPS。
2. 監聽 443 埠號，配置 SSL 憑證路徑。
3. 啟用 Gzip 壓縮，提升 API JSON 回傳效能。
4. 將 `/api/` 請求反向代理轉發至本地 Docker 容器 `http://127.0.0.1:8000`，並正確傳遞 `Host`、`X-Real-IP`、`X-Forwarded-For` 與 `X-Forwarded-Proto` 等標頭。

#### 【題目一解答 Nginx 設定檔】
```nginx
# 1. HTTP 80 自動強制導向 HTTPS 443
server {
    listen 80;
    listen [::]:80;
    server_name b2b.example.com;

    return 301 https://$host$request_uri;
}

# 2. HTTPS 443 核心反向代理伺服器
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name b2b.example.com;

    # SSL 憑證配置 (由 Let's Encrypt 自動產出)
    ssl_certificate /etc/letsencrypt/live/b2b.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/b2b.example.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # 啟用 Gzip 壓縮
    gzip on;
    gzip_types application/json text/plain text/css application/javascript;
    gzip_min_length 1024;

    # 上傳檔案大小上限 (供 Excel 批次匯入使用)
    client_max_body_size 20M;

    # 反向代理轉發至 FastAPI Docker 容器
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;

        # 傳遞真實客戶端網路資訊
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 支援 WebSocket 長連線升級 (若有即時通知需求)
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # 超時時間設定 (防止慢查詢掛死反向代理)
        proxy_connect_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

---

### 題目二：撰寫自動將 PostgreSQL B2B 核心資料庫備份加密上傳至 S3/R2 的維運腳本
**業務情境**：
公司營運的 B2B ERP 系統儲存著企業核心資產（包括 `customers` 客戶資料、`orders` 與 `order_items` 訂單明細、`products` 庫存與 `salespeople` 業績紀錄）。
身為獨立維運人員，為了防止機房災難性損毀導致客戶與交易歷史遺失，請撰寫一個 Bash 腳本 `/opt/scripts/backup_to_s3.sh`：
1. 使用 `docker exec` 執行容器內的 `pg_dump`，導出並壓縮 `b2b_erp` 資料庫。
2. 使用 OpenSSL AES-256 對備份檔進行軍規加密（防止上傳雲端時遭資料外洩）。
3. 使用 `aws-cli`（或 `rclone`）將加密檔推送至 S3 / Cloudflare R2 儲存槽 `s3://b2b-enterprise-backups/`。
4. 本地僅保留最近 3 天的暫存檔，清理歷史舊檔。

#### 【題目二解答腳本】
```bash
#!/usr/bin/env bash
set -euo pipefail

# 變數配置
CONTAINER_NAME="b2b_postgres"
DB_NAME="b2b_erp"
DB_USER="postgres"
BACKUP_DIR="/opt/backups"
S3_BUCKET="s3://b2b-enterprise-backups"
ENCRYPTION_PASS="YourSuperStrongEncryptionKey2026"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

RAW_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql.gz"
ENC_FILE="${RAW_FILE}.enc"

mkdir -p "${BACKUP_DIR}"

echo "[$(date)] >>> 開始導出資料庫備份..."
# 1. 從 Docker 容器內部導出並 gzip 壓縮
docker exec "${CONTAINER_NAME}" pg_dump -U "${DB_USER}" "${DB_NAME}" | gzip > "${RAW_FILE}"

echo "[$(date)] >>> 正在進行 AES-256 對稱式加密..."
# 2. 使用 openssl 進行加密
openssl enc -aes-256-cbc -salt -in "${RAW_FILE}" -out "${ENC_FILE}" -k "${ENCRYPTION_PASS}" -pbkdf2

echo "[$(date)] >>> 正在同步至雲端物件儲存 (S3/R2)..."
# 3. 透過 AWS CLI 推送至遠端 Storage (需先配置好 ~/.aws/credentials)
aws s3 cp "${ENC_FILE}" "${S3_BUCKET}/${DB_NAME}_${TIMESTAMP}.sql.gz.enc"

# 4. 清理本地明文檔案，僅保留加密檔案
rm -f "${RAW_FILE}"

# 5. 清理本地超過 3 天的加密備份檔
find "${BACKUP_DIR}" -name "*.enc" -type f -mtime +3 -delete

echo "[$(date)] <<< 異地備份加密上傳圓滿完成！"
```

---

### 題目三：伺服器遭受異常 SSH 暴力猜測時的現場排查與 Fail2ban 配置
**業務情境**：
維運日誌 `/var/log/auth.log` 頻繁噴出：
`Failed password for invalid user admin from 185.220.101.5 port 45122 ssh2`。
請寫出利用 Fail2ban 立即封鎖該 IP、檢查當前被黑名單封鎖清單、以及手動解鎖誤鎖同事 IP 的完整指令。

#### 【題目三解答】
```bash
# 1. 檢查當前 Fail2ban 的 SSH 監控監獄 (Jail) 狀態
sudo fail2ban-client status sshd

# 輸出範例：
# Status for the jail: sshd
# |- Filter
# |  |- Currently failed: 3
# |  `- Total failed:     482
# `- Actions
#    |- Currently banned: 5
#    `- Banned IP list:   185.220.101.5, 45.142.122.8 ...

# 2. 手動立即將特定惡意 IP 永久加入黑名單封鎖
sudo fail2ban-client set sshd banip 185.220.101.5

# 3. 若同事因為忘記密碼被誤鎖，手動解除特定 IP 封鎖 (Unban)
sudo fail2ban-client set sshd unbanip 192.168.1.50

# 4. 驗證 iptables 防火牆底層規則是否已成功注入 Drop 規則
sudo iptables -L f2b-sshd -v -n
```
