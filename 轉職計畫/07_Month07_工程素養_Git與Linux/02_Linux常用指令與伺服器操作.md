# 02 Linux 常用指令與伺服器運維排錯

## 一、目錄與檔案操作

```bash
pwd                   # 顯示當前目錄絕對路徑
ls -la                # 列出包含隱藏檔的詳細清單
mkdir -p app/src      # 遞迴建立多層目錄
cp -r src/ backup/    # 遞迴複製目錄
mv old.txt new.txt    # 移動或重新命名檔案
rm -rf temp_dir/      # 強制遞迴刪除 (注意謹慎使用)
```

---

## 二、文字檢視與日誌即時追蹤

```bash
cat app.log           # 印出全部日誌
head -n 20 app.log    # 檢視前 20 行
tail -n 50 app.log    # 檢視後 50 行
tail -f app.log       # 即時滾動監控最新日誌 (伺服器排錯必備)
grep -i "ERROR" app.log # 搜尋包含 ERROR (不區分大小寫) 的行
```

---

## 三、系統資源與進程 (Process) 監控

```bash
ps aux | grep python  # 查找正在運行的 Python 進程
top                   # 即時檢視 CPU 與記憶體佔用狀況 (或 htop)
kill -9 <PID>         # 強制終止指定 PID 進程
df -h                 # 檢視磁碟空間剩餘量
free -m               # 檢視記憶體使用狀況 (MB)
netstat -tulpn        # 檢視目前伺服器監聽中的 Port 埠號 (如 5432, 8000)
```
