# 01. SQLAlchemy 與 psycopg2 實務指南

> **📌 本章定位**：Python 連接關聯式資料庫的「雙引擎」：
> - **psycopg2** 是「底層原生高吞吐馬達」，適合百萬級 ETL 批次寫入（`execute_values`）。
> - **SQLAlchemy 2.0** 是「生產級企業業務架構」，提供連線池管理、ORM 關聯導航、Unit of Work 交易邊界與防 SQL Injection。
>
> **⚠️ 痛點場景（資料庫兩大血淚事故）**：
> 1. **SQL 注入攻擊（SQL Injection）**：用 f-string 拼接 `f"SELECT * FROM users WHERE name = '{user_input}'"`，駭客輸入 `' OR '1'='1` 直接拖庫，甚至 `'; DROP TABLE orders; --` 讓整間公司倒閉。
> 2. **N+1 查詢連線池打爆**：使用 ORM 查 1,000 筆訂單，在 for 迴圈中隨手存取 `order.customer.name`，背後默默向資料庫連發 1,001 條 SQL，資料庫連線瞬間打滿，其他微服務集體逾時掛掉。
>
> **💡 學習策略**：先定位（原生驅動 vs ORM 選型）➔ 再理解（連線池、交易 Context Manager 與 N+1 根源）➔ 再操作（批次 UPSERT 與防超賣悲觀鎖）➔ 再回收（生產級防坑清單）。

---

## 目錄
1. [為什麼 Python 需要資料庫驅動與 ORM？](#1-為什麼-python-需要資料庫驅動與-orm)
2. [psycopg2 核心實務：底層驅動與高效操作](#2-psycopg2-核心實務底層驅動與高效操作)
   - [2.1 連線管理與 Context Manager 原則](#21-連線管理與-context-manager-原則)
   - [2.2 參數化查詢與 SQL Injection 防禦](#22-參數化查詢與-sql-injection-防禦)
   - [2.3 查詢結果結構化：RealDictCursor](#23-查詢結果結構化realdictcursor)
   - [2.4 高效批次寫入效能評測：execute_batch 與 execute_values](#24-高效批次寫入效能評測execute_batch-與-execute_values)
   - [2.5 連線池管理：psycopg2.pool](#25-連線池管理psycopg2pool)
3. [SQLAlchemy 2.0 現代架構：Core 與 ORM 全解析](#3-sqlalchemy-20-現代架構core-與-orm-全解析)
   - [3.1 SQLAlchemy 2.0 架構革新與 Engine 設定](#31-sqlalchemy-20-架構革新與-engine-設定)
   - [3.2 Declarative Base 與 B2B 關聯模型設計](#32-declarative-base-與-b2b-關聯模型設計)
   - [3.3 Session 生命週期管理最佳實務](#33-session-生命週期管理最佳實務)
   - [3.4 現代查詢語法：select, join 與純量提取](#34-現代查詢語法select-join-與純量提取)
   - [3.5 效能殺手：N+1 查詢問題與 joinedload / selectinload](#35-效能殺手n1-查詢問題與-joinedload--selectinload)
4. [資料庫版本控管：Alembic 實務入門](#4-資料庫版本控管alembic-實務入門)
5. [企業級防坑與避雷指南](#5-企業級防坑與避雷指南)
6. [商業情境綜合練習題（含詳解）](#6-商業情境綜合練習題含詳解)

---

## 1. 為什麼 Python 需要資料庫驅動與 ORM？

在現代軟體開發與資料工程中，Python 應用程式與關聯式資料庫之間的通訊經歷了幾個層次的演進：

```
+-------------------------------------------------------------+
|                     應用業務邏輯 (Python)                     |
+-------------------------------------------------------------+
                              |
       +----------------------+----------------------+
       | (物件導向 / 模型封裝)    | (高效能原生 SQL / ETL)
       v                                             v
+-----------------------------+              +----------------+
|     SQLAlchemy 2.0 ORM      |              |                |
| (Session / Models / Unit of |              |                |
|           Work)             |              |                |
+-----------------------------+              |  psycopg2-     |
               |                             |     binary     |
+-----------------------------+              | (原生驅動/底層  |
|     SQLAlchemy 2.0 Core     |              |   C 擴充)      |
| (Engine / Pool / SQL 表達式) |              |                |
+-----------------------------+              |                |
               |                             |                |
+--------------------------------------------+                |
|       Python DBAPI 2.0 (PEP 249 規範)       |                |
+--------------------------------------------+                |
               |                                              |
               +----------------------+-----------------------+
                                      |
                                      v
                      +-------------------------------+
                      | PostgreSQL Server (Port 5432) |
                      +-------------------------------+
```

### 業務痛點與技術選型對照
- **原生驅動（psycopg2）**：
  - **優點**：速度極快、記憶體開銷最低，直接走 PostgreSQL 原生 C 語言 libpq 協議。在百萬級資料大量寫入（ETL 批次匯入）、資料庫維護腳本中無可取代。
  - **缺點**：需手動維護 SQL 字串；拼寫錯誤只能在執行時期崩潰；資料庫欄位變更時，需手動修改多處 SQL。
- **物件關聯對映（SQLAlchemy ORM）**：
  - **優點**：將資料庫表映射為 Python 物件類別，具備型別提示、IDE 自動補齊、關係導航（例如 `order.items`）。內建 Unit of Work 機制，自動追蹤物件狀態變更並批量提交。
  - **缺點**：抽象層帶來額外運算開銷，物件生成需佔用較多記憶體；若不懂底層 SQL 生成機制，極易引發嚴重的 N+1 效能災難。
- **現代企業架構標準**：
  - **ETL / 資料分析**：使用原生 SQL 或 SQLAlchemy Core 配合批次操作，追求極致吞吐量。
  - **API 服務 / 核心業務系統**：使用 SQLAlchemy ORM，確保模型抽象、商業邏輯封裝與資料庫遷移可維護性。

---

## 2. psycopg2 核心實務：底層驅動與高效操作

### 2.1 連線管理與 Context Manager 原則

在 Python 中使用 `psycopg2` 時，最常見的初學者錯誤是：**未正確關閉連線** 或 **未明確管理交易（Transaction）**。

`psycopg2` 的 `connection` 與 `cursor` 都支援 Context Manager（`with` 陳述句），但**兩者的行為完全不同**：
- `with conn:`：管理的是**交易（Transaction）**。區塊正常結束時自動執行 `COMMIT`，發生例外時自動執行 `ROLLBACK`。但**不會關閉連線**！
- `with conn.cursor():`：管理的是**游標生命週期**。區塊結束時會自動關閉游標釋放記憶體，但**不負責 COMMIT/ROLLBACK**！

#### 正確連線與交易管理範例
```python
import psycopg2
from psycopg2 import OperationalError

DB_CONFIG = {
    "dbname": "b2b_erp",
    "user": "postgres",
    "password": "your_secure_password",
    "host": "localhost",
    "port": 5432
}

def execute_b2b_query():
    conn = None
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        # 第一層 with conn 管理 Transaction
        with conn:
            # 第二層 with conn.cursor() 管理 Cursor 生命週期
            with conn.cursor() as cur:
                cur.execute("SELECT customer_id, company_name, credit_limit FROM customers WHERE credit_limit > %s;", (1000000,))
                rows = cur.fetchall()
                for row in rows:
                    print(f"VIP 客戶: {row[1]} (信用額度: {row[2]})")
        # 走出 with conn 區塊時，若無例外會自動 COMMIT
    except OperationalError as e:
        print(f"連線或資料庫操作失敗: {e}")
    finally:
        if conn and not conn.closed:
            conn.close()
            print("資料庫連線已安全關閉。")
```

---

### 2.2 參數化查詢與 SQL Injection 防禦

**絕對原則：永遠不可使用 Python 字串格式化（f-string、`%`、`.format()`）來拼接 SQL 查詢中的使用者輸入！**

```python
# 致命錯誤示範（SQL Injection 漏洞）
user_input = "COMP_001' OR '1'='1"
unsafe_sql = f"SELECT * FROM customers WHERE customer_id = '{user_input}';"
# 結果會印出全公司所有客戶資料，資安審計直接被當！

# 正確作法：參數化查詢（Parameterized Query）
safe_sql = "SELECT customer_id, company_name, contact_email FROM customers WHERE customer_id = %s;"
# psycopg2 會將參數單獨傳遞給 PostgreSQL 伺服器進行編譯，文字內容絕對不會被解析成 SQL 語法
cur.execute(safe_sql, (user_input,))
```

> **注意語法細節**：psycopg2 的預留位置一律使用 `%s`（即使是整數、日期或浮點數也用 `%s`），且第二個參數**必須是元組（tuple）或列表（list）**。傳入單一參數時，請記得加上逗號 `(user_input,)`。

---

### 2.3 查詢結果結構化：RealDictCursor

預設的 `cursor` 返回的每筆資料為元組（Tuple），例如 `row[0]`, `row[1]`，在欄位變更或多人協作時極易讀錯。使用 `RealDictCursor` 可將查詢結果直接轉為字典物件：

```python
from psycopg2.extras import RealDictCursor

with conn.cursor(cursor_factory=RealDictCursor) as cur:
    cur.execute("""
        SELECT 
            c.company_name,
            COUNT(o.order_id) AS total_orders,
            COALESCE(SUM(o.total_amount), 0) AS lifetime_value
        FROM customers c
        LEFT JOIN orders o ON c.customer_id = o.customer_id
        GROUP BY c.customer_id, c.company_name
        ORDER BY lifetime_value DESC
        LIMIT 5;
    """)
    top_customers = cur.fetchall()
    
    for cust in top_customers:
        # 可直接透過欄位名稱存取，易讀且穩定
        print(f"企業: {cust['company_name']:20} | 訂單量: {cust['total_orders']:3} | 總貢獻額: ${cust['lifetime_value']:,.2f}")
```

---

### 2.4 高效批次寫入效能評測：execute_batch 與 execute_values

當業務端需要匯入 10,000 筆訂單明細（order_items）時，不同的寫入方式效能差異可達 **數十倍至數百倍**：

| 方法 | 運作機制 | 1 萬筆耗時估計 | 適用情境 |
| :--- | :--- | :--- | :--- |
| `for row in data: cur.execute(...)` | 發送 10,000 次網路封包與語法解析 | 30~50 秒 | 極度不推薦 |
| `cur.executemany(...)` | 內部仍單筆執行或模擬批次，效率有限 | 10~15 秒 | 小型簡單腳本 |
| `psycopg2.extras.execute_batch` | 將語句打包為多句合併發送 | 1.5~2 秒 | 中大型常規批次寫入 |
| `psycopg2.extras.execute_values` | 合併為單一語句 `INSERT INTO ... VALUES (...), (...), ...` | **0.3~0.6 秒** | **大量資料 ETL 首選** |

#### execute_values 實戰範例
```python
from psycopg2.extras import execute_values

order_items_data = [
    ("ORD_2026_001", "PROD_CHIP_X1", 50, 1200.00),
    ("ORD_2026_001", "PROD_SEN_A2", 100, 350.00),
    ("ORD_2026_002", "PROD_SRV_RACK", 2, 85000.00),
    # ... 上萬筆資料
]

sql = """
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES %s
ON CONFLICT (order_id, product_id) 
DO UPDATE SET 
    quantity = EXCLUDED.quantity,
    unit_price = EXCLUDED.unit_price;
"""

with conn:
    with conn.cursor() as cur:
        # page_size 可控制每批打包筆數，避免單次封包超過資料庫記憶體上限
        execute_values(cur, sql, order_items_data, page_size=1000)
        print(f"成功批次匯入/更新 {len(order_items_data)} 筆訂單明細。")
```

---

### 2.5 連線池管理：psycopg2.pool

在 Web 伺服器或排程程式中，頻繁建立與銷毀 TCP 連線會消耗大量伺服器 CPU 與記憶體資源。應使用「連線池（Connection Pool）」技術：

```python
from psycopg2.pool import ThreadedConnectionPool
from contextlib import contextmanager

class B2BDatabaseManager:
    def __init__(self, minconn=2, maxconn=10, **db_kwargs):
        # 建立執行緒安全的連線池
        self.pool = ThreadedConnectionPool(minconn, maxconn, **db_kwargs)

    @contextmanager
    def get_connection(self):
        """透過 Context Manager 借用並自動歸還連線"""
        conn = self.pool.getconn()
        try:
            yield conn
        finally:
            self.pool.putconn(conn)

    def close_all(self):
        self.pool.closeall()

# 使用方式
db_mgr = B2BDatabaseManager(minconn=1, maxconn=5, **DB_CONFIG)

with db_mgr.get_connection() as conn:
    with conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM orders;")
        print(f"當前總訂單數: {cur.fetchone()[0]}")

# 程式結束或容器停機時清理連線池
db_mgr.close_all()
```

---

## 3. SQLAlchemy 2.0 現代架構：Core 與 ORM 全解析

### 3.1 SQLAlchemy 2.0 架構革新與 Engine 設定

SQLAlchemy 2.0 移除了舊版 1.x 中混亂的 `session.query()` 隱式行為，全面擁抱純量提取（`session.scalars()`）與明確的 `select()` 語法，並提供完整的 Python 型別提示支援。

#### 現代 Engine 建立與連線池參數設定
```python
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# 連線字串格式：postgresql+psycopg2://使用者:密碼@主機:埠號/資料庫名稱
DATABASE_URL = "postgresql+psycopg2://postgres:your_secure_password@localhost:5432/b2b_erp"

engine = create_engine(
    DATABASE_URL,
    echo=False,             # 生產環境設為 False；開發除錯可設為 True 觀察生成的 SQL
    pool_size=5,            # 連線池常駐連線數量
    max_overflow=10,        # 流量高峰時允許額外建立的突發連線數
    pool_timeout=30,        # 借用連線超時等待秒數
    pool_recycle=1800,      # 每 30 分鐘自動重建連線，防止資料庫端將閒置連線中斷
    pool_pre_ping=True      # 每次借用前發送心跳檢測（SELECT 1），避免借到死連線
)

# 建立 Session 工廠
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)
```

---

### 3.2 Declarative Base 與 B2B 關聯模型設計

在 SQLAlchemy 2.0 中，推薦繼承 `DeclarativeBase` 並搭配 `Mapped` 與 `mapped_column` 來宣告實體模型：

```python
from datetime import datetime
from decimal import Decimal
from typing import List, Optional
from sqlalchemy import String, Numeric, Integer, ForeignKey, DateTime, Text, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship

class Base(DeclarativeBase):
    pass

class Customer(Base):
    __tablename__ = "customers"

    customer_id: Mapped[str] = mapped_column(String(20), primary_key=True)
    company_name: Mapped[str] = mapped_column(String(100), nullable=False)
    industry: Mapped[str] = mapped_column(String(50), nullable=False)
    credit_limit: Mapped[Decimal] = mapped_column(Numeric(14, 2), default=0.00)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    # 關聯：一對多（一個客戶有多筆訂單）
    orders: Mapped[List["Order"]] = relationship(back_populates="customer", cascade="all, delete-orphan")

    def __repr__(self) -> str:
        return f"<Customer(id={self.customer_id}, name='{self.company_name}')>"

class Salesperson(Base):
    __tablename__ = "salespeople"

    salesperson_id: Mapped[str] = mapped_column(String(20), primary_key=True)
    name: Mapped[str] = mapped_column(String(50), nullable=False)
    department: Mapped[str] = mapped_column(String(50), nullable=False)
    target_amount: Mapped[Decimal] = mapped_column(Numeric(14, 2), default=0.00)

    # 關聯：業務員負責的訂單
    orders: Mapped[List["Order"]] = relationship(back_populates="salesperson")

class Order(Base):
    __tablename__ = "orders"

    order_id: Mapped[str] = mapped_column(String(30), primary_key=True)
    customer_id: Mapped[str] = mapped_column(ForeignKey("customers.customer_id"), nullable=False)
    salesperson_id: Mapped[str] = mapped_column(ForeignKey("salespeople.salesperson_id"), nullable=False)
    order_date: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    status: Mapped[str] = mapped_column(String(20), default="PENDING")  # PENDING, APPROVED, SHIPPED, CANCELLED
    total_amount: Mapped[Decimal] = mapped_column(Numeric(14, 2), default=0.00)

    # 雙向關聯
    customer: Mapped["Customer"] = relationship(back_populates="orders")
    salesperson: Mapped["Salesperson"] = relationship(back_populates="orders")
    items: Mapped[List["OrderItem"]] = relationship(back_populates="order", cascade="all, delete-orphan")

class Product(Base):
    __tablename__ = "products"

    product_id: Mapped[str] = mapped_column(String(20), primary_key=True)
    product_name: Mapped[str] = mapped_column(String(100), nullable=False)
    category: Mapped[str] = mapped_column(String(50), nullable=False)
    stock_quantity: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    cost_price: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    selling_price: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)

class OrderItem(Base):
    __tablename__ = "order_items"

    item_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    order_id: Mapped[str] = mapped_column(ForeignKey("orders.order_id"), nullable=False)
    product_id: Mapped[str] = mapped_column(ForeignKey("products.product_id"), nullable=False)
    quantity: Mapped[int] = mapped_column(Integer, nullable=False)
    unit_price: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)

    order: Mapped["Order"] = relationship(back_populates="items")
    product: Mapped["Product"] = relationship()
```

---

### 3.3 Session 生命週期管理最佳實務

SQLAlchemy 的 `Session` 是操作資料庫的主要入口，實作了「工作單元（Unit of Work）」模式。維護 Session 生命週期最推薦的方式是配合 Context Manager：

```python
from contextlib import contextmanager

@contextmanager
def get_db_session():
    """提供交易安全的 Session 注入器"""
    session = SessionLocal()
    try:
        yield session
        session.commit()    # 若整個區塊無例外，自動提交交易
    except Exception as e:
        session.rollback()  # 發生任何異常，立即回滾交易
        raise e
    finally:
        session.close()     # 釋放連線回連線池
```

---

### 3.4 現代查詢語法：select, join 與純量提取

在 2.0 中，所有查詢統一採用 `select(...)` 建構 AST 語法樹，搭配 `session.scalars()` 取得 ORM 物件：

```python
from sqlalchemy import select, and_, func

def query_high_value_orders():
    with get_db_session() as session:
        # 複合條件查詢：金額大於 50 萬且狀態為 APPROVED
        stmt = (
            select(Order)
            .where(
                and_(
                    Order.total_amount >= 500000.00,
                    Order.status == "APPROVED"
                )
            )
            .order_by(Order.total_amount.desc())
            .limit(10)
        )
        orders = session.scalars(stmt).all()
        
        for ord_obj in orders:
            print(f"訂單編號: {ord_obj.order_id} | 金額: ${ord_obj.total_amount:,.2f}")

def query_salesperson_performance():
    with get_db_session() as session:
        # 聚合彙總查詢
        stmt = (
            select(
                Salesperson.name,
                func.count(Order.order_id).label("order_count"),
                func.sum(Order.total_amount).label("sales_volume")
            )
            .join(Order, Salesperson.salesperson_id == Order.salesperson_id)
            .group_by(Salesperson.salesperson_id, Salesperson.name)
            .having(func.sum(Order.total_amount) > 1000000)
        )
        results = session.execute(stmt).all()
        for row in results:
            print(f"業務: {row.name} | 單量: {row.order_count} | 業績: ${row.sales_volume:,.2f}")
```

---

### 3.5 效能殺手：N+1 查詢問題與 joinedload / selectinload

這是使用 ORM 最具毀滅性的效能陷阱。

#### 什麼是 N+1 查詢？
當你查詢 100 筆訂單，並在迴圈中逐筆存取 `order.customer.company_name` 時：
- 執行第 1 條 SQL：`SELECT * FROM orders LIMIT 100;`
- 接著 SQLAlchemy 在背後**默默發送 100 條 SQL** 去查詢每個客戶：`SELECT * FROM customers WHERE customer_id = ?;`
- 原本 1 條 JOIN 能解決的事，變成了 101 次資料庫網路來回！

```python
# 效能悲劇示範
with get_db_session() as session:
    orders = session.scalars(select(Order).limit(100)).all()
    for o in orders:
        # 每一次 .customer 都會觸發一次隱藏的 SQL 查詢！
        print(o.order_id, o.customer.company_name)
```

#### 解決方案：預先載入（Eager Loading）
SQLAlchemy 提供兩種主要的預先載入策略：
1. **`joinedload`**：使用 `LEFT OUTER JOIN` 將關聯表在單一 SQL 中一次查出。適用於**多對一（Many-to-One）**或**一對一**關聯。
2. **`selectinload`**：先查主表，再用 `WHERE id IN (...)` 發送第二條 SQL 批次取回關聯資料。適用於**一對多（One-to-Many）集合關聯**（避免 JOIN 產生過多重複主表資料膨脹）。

```python
from sqlalchemy.orm import joinedload, selectinload

def query_orders_optimized():
    with get_db_session() as session:
        stmt = (
            select(Order)
            # 對於多對一關聯 (Customer)，使用 joinedload
            .options(joinedload(Order.customer))
            # 對於一對多關聯 (OrderItems)，使用 selectinload
            .options(selectinload(Order.items).joinedload(OrderItem.product))
            .limit(100)
        )
        orders = session.scalars(stmt).unique().all()
        
        # 此處迴圈存取所有關聯資料，完全不會觸發額外 SQL！
        for o in orders:
            print(f"訂單: {o.order_id} | 客戶: {o.customer.company_name} | 明細項數: {len(o.items)}")
            for item in o.items:
                print(f"  - 品項: {item.product.product_name} x {item.quantity}")
```

---

## 4. 資料庫版本控管：Alembic 實務入門

當團隊開發時，手動在資料庫執行 `ALTER TABLE` 會導致不同成員與生產環境綱要（Schema）不一致。`Alembic` 是 SQLAlchemy 官方推薦的遷移工具。

### 標準操作工作流

```bash
# 1. 初始化 alembic 環境（會生成 alembic.ini 與 alembic/ 目錄）
alembic init migrations

# 2. 編輯 migrations/env.py，導入專案的 Base 物件
# target_metadata = Base.metadata

# 3. 根據模型變更自動偵測生成遷移腳本
alembic revision --autogenerate -m "create_customers_and_orders"

# 4. 執行遷移，套用到資料庫
alembic upgrade head

# 5. 若有問題需要回滾上一版
alembic downgrade -1
```

---

## 5. 企業級防坑與避雷指南

1. **千萬不要在迴圈中建立 `SessionLocal()`**：
   - 錯誤作法：在 `for` 迴圈內開 Session、commit、close。
   - 正確作法：單一業務請求或單次批次任務共用同一個 Session，利用快取與批次提交。
2. **避免忘記關閉游標或 Session**：
   - 永遠使用 `with` 或 `try...finally`，否則在連線池用盡後，應用程式會陷入永久阻塞（Connection pool timeout）。
3. **小心處理時區（Timezone）**：
   - 資料庫欄位使用 `TIMESTAMP WITH TIME ZONE`（TIMESTAMPTZ）。
   - Python 端使用 `datetime.now(timezone.utc)`，切忌存入無時區意識（Naive）的本地時間。
4. **小心大量資料使用 `session.scalars().all()` 導致 OOM**：
   - 若資料高達十萬筆，使用 `.all()` 會將所有資料一次性實例化為 ORM 物件擠爆記憶體。
   - 應使用分頁查詢、`yield_per(1000)` 或切換為底層的 `conn.execution_options(stream_results=True)`。

---

## 6. 商業情境綜合練習題（實戰動腦自測）

> 💡 **自我檢驗規範**：請先不要展開解答，在你的 Python 檔案中寫出骨架與語法，再點開參考擬答對照！

### 題目一：psycopg2 高效批次匯入並支援冪等性更新（Upsert）
**業務情境**：
外部 ERP 系統每小時會導出一批產品庫存最新盤點清單（CSV/列表），清單包含 `product_id`, `product_name`, `category`, `stock_quantity`, `cost_price`, `selling_price`。請撰寫一個 Python 函式 `sync_product_inventory(conn, records)`：
- 使用 `psycopg2.extras.execute_values` 批次寫入。
- 若產品已存在（`product_id` 衝突），則更新其庫存數量 `stock_quantity`、成本價與售價；若不存在則插入。
- 必須包含異常回滾機制。

<details>
<summary>🔍 點擊展開「思維引導」</summary>

- SQL 使用 `INSERT INTO ... ON CONFLICT (product_id) DO UPDATE SET ...`。
- 批次操作使用 `execute_values(cur, sql, records, page_size=...)` 比一般的 `execute_batch` 效能高出數倍。
- 交易邊界使用 `with conn:` 包覆，自動處理 commit 與 rollback。
</details>

<details>
<summary>🔑 點擊展開「題目一參考擬答」</summary>

```python
import psycopg2
from psycopg2.extras import execute_values
from typing import List, Tuple

def sync_product_inventory(conn, records: List[Tuple]):
    """
    批次同步產品庫存資料 (UPSERT 模式)
    records 格式: [(product_id, name, category, stock, cost, sell), ...]
    """
    upsert_sql = """
    INSERT INTO products (
        product_id, product_name, category, stock_quantity, cost_price, selling_price
    )
    VALUES %s
    ON CONFLICT (product_id) 
    DO UPDATE SET 
        stock_quantity = EXCLUDED.stock_quantity,
        cost_price = EXCLUDED.cost_price,
        selling_price = EXCLUDED.selling_price;
    """
    
    try:
        with conn: # 自動管理 Transaction
            with conn.cursor() as cur:
                execute_values(cur, upsert_sql, records, page_size=2000)
        print(f"成功同步 {len(records)} 項產品庫存資料。")
    except psycopg2.Error as e:
        print(f"資料庫同步失敗，交易已安全回滾: {e}")
        raise e
```
</details>

---

### 題目二：SQLAlchemy ORM 複合條件查詢與關聯載入防範 N+1
**業務情境**：
業務主管需要一份業績報告，要求撈出所有「單筆訂單總額超過 20 萬」且狀態為「APPROVED」的訂單清單。
輸出內容需列出：
1. 訂單編號、下單日期、訂單總額
2. 下單客戶的公司名稱、產業別
3. 負責該訂單的業務員姓名與部門
4. 該訂單底下的所有產品明細（品名、數量、銷售單價）
**技術要求**：必須使用 SQLAlchemy 2.0 現代語法，並完全杜絕 N+1 查詢（嚴格限制 SQL 發送次數不超過 2 次）。

<details>
<summary>🔍 點擊展開「思維引導」</summary>

- 對多對一（Many-to-One）關係（Customer, Salesperson）：使用 `joinedload` 透過 SQL JOIN 一次載入。
- 對一對多（One-to-Many）關係（Items）：使用 `selectinload` 發送一條 `IN (...)` 批次查詢載入明細，並將明細中的 Product 再次 `joinedload`。
- 查詢必須調用 `.unique()` 防止因 JOIN 產生重複的根物件。
</details>

<details>
<summary>🔑 點擊展開「題目二參考擬答」</summary>

```python
from sqlalchemy import select
from sqlalchemy.orm import joinedload, selectinload
from decimal import Decimal

def generate_vip_order_report(session):
    stmt = (
        select(Order)
        .where(
            Order.total_amount >= Decimal("200000.00"),
            Order.status == "APPROVED"
        )
        # 多對一關聯：一次性 JOIN 客戶與業務員
        .options(
            joinedload(Order.customer),
            joinedload(Order.salesperson)
        )
        # 一對多關聯：使用 selectinload 批次帶回明細，並將明細中的 Product joinedload
        .options(
            selectinload(Order.items).joinedload(OrderItem.product)
        )
        .order_by(Order.order_date.desc())
    )
    
    orders = session.scalars(stmt).unique().all()
    
    print(f"=== 高價值核准訂單報告 (共 {len(orders)} 筆) ===")
    for o in orders:
        print(f"\n【訂單】{o.order_id} | 日期: {o.order_date.strftime('%Y-%m-%d')} | 金額: ${o.total_amount:,.2f}")
        print(f"  客戶: {o.customer.company_name} ({o.customer.industry})")
        print(f"  負責業務: {o.salesperson.name} ({o.salesperson.department})")
        print("  訂購明細:")
        for item in o.items:
            subtotal = item.quantity * item.unit_price
            print(f"    * {item.product.product_name:25} x {item.quantity:3} @ ${item.unit_price:,.2f} = ${subtotal:,.2f}")
```
</details>

---

### 題目三：跨表交易一致性操作（扣減庫存並成立訂單）
**業務情境**：
當客戶下單時，系統必須依序執行以下邏輯，並確保具備 ACID 原子性：
1. 檢查客戶信用額度：客戶現有未結訂單加總 + 本次訂單金額，不得超過其 `credit_limit`。
2. 檢查各產品庫存：若任何一項產品庫存不足，整筆交易立即中止。
3. 扣減對應產品庫存數量。
4. 建立 `Order` 紀錄與對應的 `OrderItem` 明細。
5. 若過程中任一步驟出錯，資料庫必須回滾至下單前的原始狀態。

<details>
<summary>🔍 點擊展開「思維引導」</summary>

- 悲觀鎖定：在查詢產品庫存時，加上 `.with_for_update()` 鎖定該列，避免並發連線超賣。
- 信用額度檢查：計算新訂單總金額與客戶額度比對，超標則主動拋出自訂例外。
- 交易管理：函式內部不手動呼叫 `session.commit()`，交由調用方的 `with Session(engine) as session, session.begin():` 統一管理。
</details>

<details>
<summary>🔑 點擊展開「題目三參考擬答」</summary>

```python
from decimal import Decimal
from typing import List, Dict

class InsufficientStockError(Exception):
    pass

class CreditLimitExceededError(Exception):
    pass

def create_b2b_order(session, customer_id: str, salesperson_id: str, order_id: str, items_req: List[Dict]):
    """
    items_req 格式: [{"product_id": "PROD_001", "quantity": 10}, ...]
    """
    # 1. 查詢客戶並檢查信用額度
    cust = session.get(Customer, customer_id)
    if not cust:
        raise ValueError(f"找不到客戶編號: {customer_id}")
    
    # 計算訂單總額並驗證庫存
    total_order_amount = Decimal("0.00")
    order_items_to_create = []

    for item in items_req:
        pid = item["product_id"]
        qty = item["quantity"]
        
        # 加上 with_for_update 鎖定該產品行，防止併發超賣 (Pessimistic Locking)
        stmt = select(Product).where(Product.product_id == pid).with_for_update()
        product = session.scalar(stmt)
        
        if not product:
            raise ValueError(f"產品不存在: {pid}")
        if product.stock_quantity < qty:
            raise InsufficientStockError(f"產品 {product.product_name} 庫存不足！現有: {product.stock_quantity}，需求: {qty}")
        
        # 扣減庫存
        product.stock_quantity -= qty
        line_total = product.selling_price * qty
        total_order_amount += line_total
        
        order_items_to_create.append(
            OrderItem(
                product_id=pid,
                quantity=qty,
                unit_price=product.selling_price
            )
        )

    # 檢查信用限制
    if total_order_amount > cust.credit_limit:
        raise CreditLimitExceededError(
            f"訂單金額 ${total_order_amount:,.2f} 超過客戶信用額度 ${cust.credit_limit:,.2f}"
        )

    # 建立訂單主表
    new_order = Order(
        order_id=order_id,
        customer_id=customer_id,
        salesperson_id=salesperson_id,
        status="APPROVED",
        total_amount=total_order_amount,
        items=order_items_to_create
    )
    
    session.add(new_order)
    print(f"訂單 {order_id} 驗證通過，總金額: ${total_order_amount:,.2f}，準備提交交易。")
```
</details>

---

## 🎯 本章收斂總結
> **💡 核心金句**：
> 「批次匯入走原生，參數防範 SQL 坑；ORM 善用預載入，悲觀鎖定保庫存。」

