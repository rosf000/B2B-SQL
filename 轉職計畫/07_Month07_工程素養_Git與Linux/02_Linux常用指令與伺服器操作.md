# 02. Linux 常用指令與伺服器維運實務

> **📌 本章定位**：Linux 是所有資料庫、容器（Docker）、Kubernetes 與雲端伺服器的**「作業系統地基」**。本篇的核心心智模型是：掌握「萬物皆檔案」與「文字串流管線（Pipe）」，讓你脫離對 GUI 圖形介面的依賴，在黑底白字的終端機中自信排障。
>
> **⚠️ 痛點場景（伺服器維運三大血淚事故）**：
> 1. **Cat 巨大檔案終端機假死**：想排查錯誤，隨手打了 `cat production_access.log`（檔案有 80GB），終端機瘋狂刷屏把本機 SSH 卡死，伺服器 CPU 瞬間飆高。
> 2. **幽靈佔用空間未釋放**：磁碟 100% 爆滿，工程師手滑執行 `rm big.log`，結果因為後台 Python 程序仍抓著檔案句柄，檔案在目錄消失但磁區**完全沒有釋放**，資料庫依然處於唯讀狀態無法重啟。
> 3. **隨手 chmod 777 引狼入室**：遇到「Permission Denied」圖省事直接 `sudo chmod -R 777 /opt`，讓伺服器上的任何惡意進程甚至 Web 漏洞能隨意覆蓋二進位檔，遭到勒索軟體全盤加密。
>
> **💡 學習策略**：先定位（目錄樹與權限機制）➔ 再理解（管線串流、信號與 systemd）➔ 再操作（一行 Shell 析日誌與空間搶救 SOP）➔ 再回收（伺服器排障指令清單）。

---

## 目錄
1. [Linux 哲學與檔案階層標準（FHS）](#1-linux-哲學與檔案階層標準fhs)
   - [1.1 萬物皆檔案（Everything is a file）](#11-萬物皆檔案everything-is-a-file)
   - [1.2 伺服器核心目錄職責地圖](#12-伺服器核心目錄職責地圖)
2. [權限控制與系統安全防線](#2-權限控制與系統安全防線)
   - [2.1 檔案屬性解密：rwx 與 9 位元二進位](#21-檔案屬性解密rwx-與-9-位元二進位)
   - [2.2 chmod、chown 實務與 777 禁忌](#22-chmodchown-實務與-777-禁忌)
3. [日誌排障與文字串流處理神器](#3-日誌排障與文字串流處理神器)
   - [3.1 串流重定向：標準輸出、錯誤輸出與管線（Pipe）](#31-串流重定向標準輸出錯誤輸出與管線pipe)
   - [3.2 即時追蹤：tail -f 與 head](#32-即時追蹤tail--f-與-head)
   - [3.3 文字三劍客實戰：grep, awk, sed](#33-文字三劍客實戰grep-awk-sed)
4. [系統資源監控與行程（Process）管理](#4-系統資源監控與行程process管理)
   - [4.1 行程查找與信號（Signals）：SIGTERM vs SIGKILL](#41-行程查找與信號signalssigterm-vs-sigkill)
   - [4.2 資源健檢：htop, free, df, du 與 Load Average](#42-資源健檢htop-free-df-du-與-load-average)
   - [4.3 簡易背景執行：nohup 與 & 的侷限](#43-簡易背景執行nohup-與--的侷限)
5. [現代伺服器守護神：systemd 服務自動化管理](#5-現代伺服器守護神systemd-服務自動化管理)
   - [5.1 為什麼生產環境嚴禁使用 nohup？](#51-為什麼生產環境嚴禁使用-nohup)
   - [5.2 撰寫生產級 .service 單元設定檔](#52-撰寫生產級-service-單元設定檔)
   - [5.3 systemctl 與 journalctl 日誌追蹤](#53-systemctl-與-journalctl-日誌追蹤)
6. [網路排障與 SSH 遠端維運安全實踐](#6-網路排障與-ssh-遠端維運安全實踐)
   - [6.1 SSH Key 免密碼公私鑰認證配置](#61-ssh-key-免密碼公私鑰認證配置)
   - [6.2 網路連線與通訊埠檢查：ss, curl, nc](#62-網路連線與通訊埠檢查ss-curl-nc)
7. [商業情境綜合練習題（含詳解）](#7-商業情境綜合練習題含詳解)

---

## 1. Linux 哲學與檔案階層標準（FHS）

### 1.1 萬物皆檔案（Everything is a file）

在 Unix / Linux 架構中，**幾乎所有硬體、周邊、網路通訊（Socket）與處理序間通訊（Pipe）都被抽象為檔案**：
- 硬碟被抽象為 `/dev/sda` 或 `/dev/nvme0n1`
- 記憶體資訊可透過 `/proc/meminfo` 讀取
- 系統黑洞垃圾桶是 `/dev/null`

---

### 1.2 伺服器核心目錄職責地圖

Linux 沒有 Windows 的 `C:\`, `D:\` 磁碟機概念，一切皆從單一根目錄 `/` 出發：

```
/
|-- bin / sbin       (系統核心二進位執行檔，如 ls, cp, ip)
|-- etc              (系統全域設定檔，如 etc/nginx/, /etc/systemd/, /etc/passwd)
|-- home             (一般使用者的家目錄，如 /home/jay/)
|-- root             (最高管理員 root 的家目錄)
|-- var
|   \-- log          (企業日誌聚集地！如 /var/log/syslog, /var/log/nginx/)
|-- opt              (第三方大型專案放置目錄，如 /opt/b2b_erp/)
|-- tmp              (臨時檔案，重開機時系統會自動清空)
\-- proc             (虛擬檔案系統，反映內核與執行中行程即時狀態)
```

---

## 2. 權限控制與系統安全防線

### 2.1 檔案屬性解密：rwx 與 9 位元二進位

在終端機輸入 `ls -l`，第一欄會顯示 10 個字元，例如 `-rwxr-xr--`：

```
-    rwx    r-x    r--
^     ^      ^      ^
|     |      |      |
型態  Owner  Group  Others
```

- **第 1 位**：`-` 代表一般檔案；`d` 代表目錄（Directory）；`l` 代表軟連結（Symbolic link）。
- **權限三位元組**：`r` (Read=4), `w` (Write=2), `x` (Execute=1)。
  - `rwx` = 4 + 2 + 1 = **7**（擁有者可讀、可寫、可執行）
  - `r-x` = 4 + 0 + 1 = **5**（同群組使用者可讀、不可寫、可執行）
  - `r--` = 4 + 0 + 0 = **4**（其他外部人員僅可讀）
  - 合成數值權限：`754`

> **注意**：對於「目錄」而言，`x`（執行）權限意味著「能否 `cd` 進入該目錄並存取其內部檔案」。若目錄沒有 `x`，即便有 `r` 權限也無法存取內容！

---

### 2.2 chmod、chown 實務與 777 禁忌

- **修改權限**：`chmod 755 run_etl.sh`（擁有者具備全部權限，其餘人可讀可執行）。
- **修改擁有者與群組**：`sudo chown -R appuser:appgroup /opt/b2b_erp`。

> ⚠️ **企業絕對禁忌：千萬不可因為權限報錯（Permission Denied）就無腦執行 `chmod 777`！**
> `777` 意味著系統上任何受限處理序甚至駭客都能隨意竄改或替換你的執行檔。正確作法是透過 `chown` 將檔案擁有者指定給專屬的系統服務帳戶（如 `www-data` 或 `appuser`）。

---

## 3. 日誌排障與文字串流處理神器

### 3.1 串流重定向：標準輸出、錯誤輸出與管線（Pipe）

- `0`: stdin（標準輸入）
- `1`: stdout（標準輸出）
- `2`: stderr（標準錯誤）

| 指令 | 說明 |
| :--- | :--- |
| `cmd > output.txt` | 將 stdout 覆寫存入檔案 |
| `cmd >> output.txt` | 將 stdout 以追加（Append）方式寫入檔案 |
| `cmd 2> error.log` | 僅將 stderr 寫入錯誤日誌 |
| `cmd > app.log 2>&1` | **標準企業寫法**：將 stdout 與 stderr 合流寫入同一檔案 |
| `cmd1 \| cmd2` | **管線（Pipe）**：將 cmd1 的 stdout 直接串接到 cmd2 的 stdin |

---

### 3.2 即時追蹤：tail -f 與 head

線上系統發生異常時，工程師進機台的第一個動作：

```bash
# 即時滾動追蹤最後 100 行，螢幕隨新日誌動態更新
tail -f -n 100 /var/log/b2b_etl/b2b_etl.log

# 僅讀取大型 CSV 檔的前 5 列以確認欄位表頭
head -n 5 raw_customers_2026.csv
```

---

### 3.3 文字三劍客實戰：grep, awk, sed

#### 1. Grep（正則文字搜尋）
```bash
# 在整個日誌目錄中，遞迴搜尋包含 "CRITICAL" 的行，並顯示檔案名稱與行號
grep -rn "CRITICAL" /var/log/b2b_etl/

# 忽略大小寫，並列印匹配行的前後各 3 行（提供上下文 Context）
grep -i -C 3 "connection refused" /var/log/b2b_etl/b2b_etl.log
```

#### 2. Awk（結構化欄位運算與報表統計）
預設以「空白或 Tab」為分隔符號，`$1`, `$2` 分別代表第 1、第 2 欄位，`$NF` 代表最後一欄。

```bash
# 假設 Web 訪問日誌格式：IP - - [日期] "METHOD URI PROTOCOL" 狀態碼 傳輸位元組
# 提取狀態碼為 500 的訪問 IP 與請求 URI：
awk '$9 == 500 { print "異常IP:", $1, "端點:", $7 }' /var/log/nginx/access.log
```

#### 3. Sed（串流文字替換）
```bash
# 將設定檔中的連線字串批量替換（s/舊/新/g），-i 代表直接修改原檔案（In-place）
sed -i 's/localhost:5432/db-prod.internal:5432/g' config.yaml
```

---

## 4. 系統資源監控與行程（Process）管理

### 4.1 行程查找與信號（Signals）：SIGTERM vs SIGKILL

```bash
# 1. 查找名為 python 的所有行程
ps aux | grep python

# 輸出範例：
# appuser  18452  2.5  8.1 458920 168204 ?  S  14:30  0:15 python main.py
# (第二欄 18452 即為 PID 行程代號)
```

#### 殺死行程的兩個等級：
- **`kill -15 18452`（SIGTERM，預設信號）**：
  - **溫柔終止**：通知程式「請準備關閉」。Python 程式可捕捉此信號，完成目前這筆資料庫交易、釋放連線池、儲存快取後再正常退出。**生產環境永遠優先使用 -15！**
- **`kill -9 18452`（SIGKILL）**：
  - **暴力摧毀**：作業系統內核直接中斷處理序並回收記憶體。程式無法捕捉此信號，極易導致資料庫寫到一半交易損壞或 lock 鎖死。僅在程式完全卡死無反應時使用。

---

### 4.2 資源健檢：htop, free, df, du 與 Load Average

- **`top` / `htop`**：
  - **Load Average（負載平均值）**：顯示 1 分鐘、5 分鐘、15 分鐘系統負載。若為 4 核心 CPU，Load Average 超過 4.0 代表已經在排隊塞車！
- **`free -h`**：檢查記憶體使用量（特別注意 `available` 是否過低）。
- **`df -h`**：檢查硬碟磁區剩餘容量（`Mounted on /` 若達到 100% 系統會直接罷工）。
- **`du -sh /var/log/*`**：找出 `/var/log/` 目錄下哪個子資料夾肥大佔用空間。

---

### 4.3 簡易背景執行：nohup 與 & 的侷限

```bash
# 讓腳本在登出終端機後持續運行（忽略 SIGHUP 信號）
nohup python run_etl.py > etl.log 2>&1 &
```
> **為什麼不建議在生產環境長期使用 nohup？**
> 因為若伺服器重啟、或者 Python 發生記憶體洩漏閃退，`nohup` **不會自動拉起服務**；且難以監控健康狀態與統一管理。

---

## 5. 現代伺服器守護神：systemd 服務自動化管理

在現代 Linux（Ubuntu 20.04+, Debian, CentOS 7+, RHEL）上，**所有常駐後端服務（FastAPI, Celery, 排程腳本）都必須註冊為 systemd Service**。

### 5.1 systemd 帶來的企業級好處
1. **開機自動啟動**（Auto-start on boot）。
2. **行程異常終止自動重啟**（`Restart=always`）。
3. **隔離執行環境**：以特定受限系統使用者執行，保障主機安全。
4. **統一日誌收集**：自動將 stdout/stderr 彙整到 `journald`。

---

### 5.2 撰寫生產級 .service 單元設定檔

建立服務設定檔：`sudo nano /etc/systemd/system/b2b_etl.service`

```ini
[Unit]
Description=B2B Order ETL Pipeline Service
After=network.target postgresql.service
Wants=postgresql.service

[Service]
# 以專用系統帳號執行，絕不使用 root！
Type=simple
User=appuser
Group=appgroup
WorkingDirectory=/opt/b2b_etl

# 使用 Poetry 或 venv 的專屬 Python 解譯器路徑
ExecStart=/opt/b2b_etl/.venv/bin/python main.py
ExecReload=/bin/kill -HUP $MAINPID

# 崩潰後 5 秒自動重啟，確保高可用
Restart=always
RestartSec=5s

# 環境變數設定
Environment="ENV=production"
EnvironmentFile=/opt/b2b_etl/.env

# 限制最大資源佔用，防止單一服務擠爆伺服器
MemoryMax=2G
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

---

### 5.3 systemctl 與 journalctl 常用指令速查

```bash
# 1. 重新載入設定檔（每次修改 .service 後必跑）
sudo systemctl daemon-reload

# 2. 啟動、停止、重啟服務
sudo systemctl start b2b_etl
sudo systemctl stop b2b_etl
sudo systemctl restart b2b_etl

# 3. 檢查服務健康狀態
sudo systemctl status b2b_etl

# 4. 設定為開機自啟動
sudo systemctl enable b2b_etl

# 5. 查看服務日誌（-f 即時滾動，-u 指定單元名稱）
journalctl -u b2b_etl -f -n 50
```

---

## 6. 網路排障與 SSH 遠端維運安全實踐

### 6.1 SSH Key 免密碼公私鑰認證配置

```bash
# 1. 在開發本機生成 ed25519 金鑰對（比傳統 RSA 更安全小巧）
ssh-keygen -t ed25519 -C "jay@enterprise.com"

# 2. 將公鑰安全拷貝至雲端伺服器 (將公鑰注入伺服器 ~/.ssh/authorized_keys)
ssh-copy-id -i ~/.ssh/id_ed25519.pub appuser@192.168.1.100

# 3. 登入伺服器（無需輸入密碼）
ssh appuser@192.168.1.100
```

---

### 6.2 網路連線與通訊埠檢查：ss, curl, nc

當你的 Python 應用說「無法連線到資料庫」時，該如何證明是資料庫沒開，還是防火牆擋住？

```bash
# 1. 檢查本機是否有監聽 5432 (PostgreSQL) 或 8000 (FastAPI) 埠號
# -t (TCP), -u (UDP), -l (Listening), -p (Process), -n (Numeric)
sudo ss -tulpn | grep 5432

# 2. 測試目標主機通訊埠是否暢通（不送任何 HTTP 請求，只探測 TCP 握手）
# 若回傳 succeeded 代表網路與防火牆皆放行！
nc -zv 10.0.0.5 5432

# 3. 發送詳細 HTTP 請求排障（-I 僅抓取 Header，-v 顯示握手細節）
curl -Iv https://api.b2b-gateway.example.com/health
```

---

## 7. 商業情境綜合練習題（實戰動腦自測）

> 💡 **自我檢驗規範**：請先不要展開解答，在 Linux 終端機（或 WSL / 雲端 VM）中親自測試管線指令與 Shell 腳本，再點開參考擬答對照！

### 題目一：使用 Shell 指令分析 Nginx 訪問日誌 Top 5 異常 IP
**業務情境**：
公司 B2B API 伺服器遭受異常大流量爬蟲攻擊，伺服器發出警報。
請使用一整行 Linux 管線指令（組合 `grep`, `awk`, `sort`, `uniq`, `head`），分析 `/var/log/nginx/access.log`：
1. 篩選出所有 HTTP 狀態碼為 `4xx` 或 `5xx` 的請求紀錄。
2. 提取其來源 IP（日誌第 1 個欄位）。
3. 統計每個異常 IP 出現的次數，依出現次數由大到小排序。
4. 僅印出前 5 名惡意攻擊 IP 與其發動請求的總次數。

<details>
<summary>🔍 點擊展開「思維引導」</summary>

- `grep -E` 正則匹配狀態碼 `' "(4[0-9]{2}|5[0-9]{2}) '`。
- `awk '{print $1}'` 取出 IP。
- 注意：使用 `uniq -c` 之前**必須先執行 `sort`**，否則不相鄰的相同 IP 無法被歸併計數。
- 最後使用 `sort -nr | head -n 5` 取前五大。
</details>

<details>
<summary>🔑 點擊展開「題目一參考擬答」</summary>

```bash
grep -E ' "(4[0-9]{2}|5[0-9]{2}) ' /var/log/nginx/access.log | awk '{print $1}' | sort | uniq -c | sort -nr | head -n 5
```

**步驟解析說明**：
1. `grep -E ' "(4[0-9]{2}|5[0-9]{2}) '`：正則比對 HTTP 狀態碼為 400~599 的列。
2. `awk '{print $1}'`：取出日誌列的第一個欄位（即訪客 Client IP）。
3. `sort`：將 IP 排序（使相鄰列相同）。
4. `uniq -c`：計算相鄰重複 IP 的出現次數。
5. `sort -nr`：以數值大小倒序排序。
6. `head -n 5`：僅擷取前 5 名。
</details>

---

### 題目二：伺服器硬碟空間 100% 爆滿緊急排查與修復 SOP
**業務情境**：
週日清晨系統發出 CRITICAL 告警：`Filesystem /dev/sda1 is 100% full`，導致 PostgreSQL 資料庫無法寫入 WAL 日誌而崩潰。
請寫出排查出罪魁禍首目錄、找出大型垃圾檔案並安全釋放空間的完整指令步驟。

<details>
<summary>🔍 點擊展開「思維引導」</summary>

- `df -h` 看分區，`du -h --max-depth=1` 往下鑽取。
- `find /var/log -type f -size +500M` 揪出大檔。
- **核心避坑**：不要直接 `rm` 正在被寫入的日誌檔（會造成空間不釋放的幽靈佔用），應使用 `truncate -s 0 file.log` 或 `> file.log` 清空。
</details>

<details>
<summary>🔑 點擊展開「題目二參考擬答」</summary>

```bash
# 步驟 1：確認掛載點使用狀況
df -h

# 步驟 2：由淺入深找出佔用容量最大的前 5 大目錄
sudo du -h --max-depth=1 /var | sort -hr | head -n 5

# 步驟 3：進入目錄，找出超過 500MB 的巨大日誌檔
find /var/log -type f -size +500M -exec ls -lh {} \;

# 步驟 4：【安全清空】大型日誌檔（避免 rm 造成 File Descriptor 殘留無法釋放）
sudo truncate -s 0 /var/log/app_debug.log

# 步驟 5：若檔案已被誤 rm，找出抓著 deleted 句柄的 PID 並重啟
sudo lsof | grep deleted
# 找到 PID 後重啟該服務: sudo systemctl restart <service_name>

# 步驟 6：確認磁碟空間恢復
df -h
```
</details>

---

### 題目三：撰寫自動備份 PostgreSQL 並定時清理過期檔的 Shell 腳本
**業務情境**：
身為維運工程師，請撰寫一個 Bash 腳本 `/opt/scripts/backup_b2b_db.sh`：
1. 每天將資料庫 `b2b_erp` 透過 `pg_dump` 匯出壓縮備份至 `/opt/backups/db/`。
2. 檔名格式包含精確日期時間：`b2b_erp_YYYYMMDD_HHMMSS.sql.gz`。
3. 備份完成後，自動掃描並刪除超過 14 天的歷史舊備份檔，避免磁碟空間被撐爆。
4. 整個備份過程記錄執行時間與結果到 `/var/log/db_backup.log`。

<details>
<summary>🔍 點擊展開「思維引導」</summary>

- 腳本開頭加上 `set -euo pipefail` 嚴格防呆。
- 使用 `pg_dump | gzip > backup.sql.gz` 管線串流。
- 使用 `find ... -mtime +14 -delete` 自動清理 14 天前舊檔。
</details>

<details>
<summary>🔑 點擊展開「題目三參考擬答」</summary>

```bash
#!/usr/bin/env bash
# /opt/scripts/backup_b2b_db.sh
set -euo pipefail

# 設定變數
DB_NAME="b2b_erp"
DB_USER="postgres"
BACKUP_DIR="/opt/backups/db"
LOG_FILE="/var/log/db_backup.log"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql.gz"

mkdir -p "${BACKUP_DIR}"

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

log_msg "===== 開始資料庫備份任務: ${DB_NAME} ====="

if PGPASSWORD="your_db_password" pg_dump -U "${DB_USER}" -h "localhost" "${DB_NAME}" | gzip > "${BACKUP_FILE}"; then
    BACKUP_SIZE=$(ls -lh "${BACKUP_FILE}" | awk '{print $5}')
    log_msg "備份成功生成: ${BACKUP_FILE} (大小: ${BACKUP_SIZE})"
else
    log_msg "❌ 資料庫備份失敗！"
    exit 1
fi

log_msg "正在清理超過 14 天之過期歷史備份檔..."
DELETED_COUNT=$(find "${BACKUP_DIR}" -name "${DB_NAME}_*.sql.gz" -type f -mtime +14 -delete -print | wc -l)
log_msg "過期清理完成，共刪除 ${DELETED_COUNT} 個歷史備份。"

log_msg "===== 資料庫備份任務圓滿結束 ====="
```
</details>

---

## 🎯 本章收斂總結
> **💡 核心金句**：
> 「管線組合三劍客，排查日誌快如飛；清空大檔用截斷，服務守護靠 systemd。」

