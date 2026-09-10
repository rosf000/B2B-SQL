# 02. Pydantic 資料驗證與企業級 CRUD 實戰

> **模組目標**：掌握 FastAPI 最核心的資料防護門神——**Pydantic v2**。深入理解宣告式型別校驗、欄位約束、自定義驗證器（`@field_validator`）與跨欄位連動驗證（`@model_validator`）；精通 Schema 職責分離模式（Create / Update / Response），杜絕敏感欄位洩漏；熟練運用 `ConfigDict(from_attributes=True)` 與 SQLAlchemy 2.0 ORM 無縫整合；並實作包含部分欄位更新（PATCH）、防超賣並發鎖定與軟刪除的企業級 CRUD 業務架構。

---

## 目錄
1. [Pydantic v2 核心架構與型別驗證心智模型](#1-pydantic-v2-核心架構與型別驗證心智模型)
   - [1.1 資料解析（Parsing）而非僅是型別檢查](#11-資料解析parsing而非僅是型別檢查)
   - [1.2 Pydantic v1 vs v2 演進與 Rust 引擎核心革新](#12-pydantic-v1-vs-v2-演進與-rust-引擎核心革新)
2. [宣告式 Schema 設計與嚴格商業約束](#2-宣告式-schema-設計與嚴格商業約束)
   - [2.1 Field 參數深度運用：長度、範圍與正則表達式](#21-field-參數深度運用長度範圍與正則表達式)
   - [2.2 單欄位驗證：@field_validator 實戰](#22-單欄位驗證field_validator-實戰)
   - [2.3 跨欄位聯動驗證：@model_validator 實戰](#23-跨欄位聯動驗證model_validator-實戰)
3. [企業級 Schema 職責分層模式（Separation of Concerns）](#3-企業級-schema-職責分層模式separation-of-concerns)
   - [3.1 為什麼嚴禁「一個 Model 打天下」？](#31-為什麼嚴禁一個-model-打天下)
   - [3.2 Base, Create, Update, Response 階層架構](#32-base-create-update-response-階層架構)
   - [3.3 ORM 互轉關鍵：ConfigDict(from_attributes=True)](#33-orm-互轉關鍵configdictfrom_attributestrue)
4. [企業級 CRUD 實戰模式：以 B2B 訂單系統為例](#4-企業級-crud-實戰模式以-b2b-訂單系統為例)
   - [4.1 Create：原子交易與悲觀鎖防範超賣](#41-create原子交易與悲觀鎖防範超賣)
   - [4.2 Read：關聯預載與階層序列化](#42-read關聯預載與階層序列化)
   - [4.3 Update：PATCH 局部增量更新與 exclude_unset](#43-updatepatch-局部增量更新與-exclude_unset)
   - [4.4 Delete：企業軟刪除（Soft Delete）實務](#44-delete企業軟刪除soft-delete實務)
5. [常見避坑指南與資安規範](#5-常見避坑指南與資安規範)
6. [商業情境綜合練習題（含詳解）](#6-商業情境綜合練習題含詳解)

---

## 1. Pydantic v2 核心架構與型別驗證心智模型

### 1.1 資料解析（Parsing）而非僅是型別檢查

Pydantic 不是單純在型別不符時拋出錯誤，它更是一個強大的**資料解析與型別強制轉換引擎（Data Parsing & Coercion Engine）**。

```python
from pydantic import BaseModel

class ProductItem(BaseModel):
    product_id: str
    quantity: int
    unit_price: float

# 客戶端傳來的 JSON 可能所有數值都是字串格式
payload = {"product_id": "PROD_CHIP_01", "quantity": "25", "unit_price": "1250.50"}

item = ProductItem(**payload)
# Pydantic 自動安全轉換為正確的 Python 型別
print(type(item.quantity), item.quantity)     # <class 'int'> 25
print(type(item.unit_price), item.unit_price) # <class 'float'> 1250.5
```

---

### 1.2 Pydantic v1 vs v2 演進與 Rust 引擎核心革新

Pydantic v2 移除了以往 Python 慢速反射機制，核心驗證邏輯 `pydantic-core` 完全以 **Rust 撰寫**：

| 特性 | Pydantic v1 (舊版) | Pydantic v2 (現代標準) |
| :--- | :--- | :--- |
| **底層語言** | 純 Python | **Rust (pydantic-core)** |
| **ORM 模式配置** | `class Config: orm_mode = True` | `model_config = ConfigDict(from_attributes=True)` |
| **欄位校驗裝飾器**| `@validator("field")` | `@field_validator("field")` |
| **模型全體驗證器**| `@root_validator` | `@model_validator(mode="after" / "before")` |
| **字典導出** | `.dict()` | **`.model_dump()`** |
| **JSON 字串導出**| `.json()` | **`.model_dump_json()`** |

---

## 2. 宣告式 Schema 設計與嚴格商業約束

### 2.1 Field 參數深度運用：長度、範圍與正則表達式

使用 `Field()` 能在 API 層擋下 95% 以上的無效資料，避免髒資料流入資料庫：

```python
from decimal import Decimal
from typing import Optional
from pydantic import BaseModel, Field

class CustomerCreateSchema(BaseModel):
    customer_id: str = Field(
        ...,
        pattern=r"^CUST_[0-9]{3,6}$",
        description="客戶識別碼，格式必須為 CUST_ 開頭接 3-6 位數字",
        examples=["CUST_001", "CUST_9999"]
    )
    company_name: str = Field(
        ...,
        min_length=2,
        max_length=100,
        description="企業全域名稱",
        examples=["台積電商務股份有限公司"]
    )
    tax_id: str = Field(
        ...,
        pattern=r"^[0-9]{8}$",
        description="統一編號（台灣營利事業 8 位數字統編）",
        examples=["12345678"]
    )
    credit_limit: Decimal = Field(
        default=Decimal("100000.00"),
        ge=Decimal("0.00"),
        le=Decimal("50000000.00"),
        description="授信信用額度，上限 5000 萬元"
    )
```

---

### 2.2 單欄位驗證：@field_validator 實戰

針對單一欄位進行深入的商業規則檢驗（如統編邏輯檢查、聯絡信箱網域限制）：

```python
from pydantic import field_validator

class CustomerRegisterRequest(CustomerCreateSchema):
    contact_email: str = Field(..., description="主要商務聯絡信箱")

    @field_validator("contact_email")
    @classmethod
    def validate_corporate_email(cls, v: str) -> str:
        # 禁止使用免洗信箱註冊企業帳號
        blocked_domains = {"gmail.com", "yahoo.com", "hotmail.com", "163.com"}
        domain = v.split("@")[-1].lower()
        if domain in blocked_domains:
            raise ValueError(f"B2B 客戶註冊必須使用企業專屬網域信箱，禁止使用通用免費信箱: {domain}")
        return v.lower()
```

---

### 2.3 跨欄位聯動驗證：@model_validator 實戰

當驗證邏輯牽涉到多個欄位時（例如：核准日期不得早於下單日期、特殊優惠碼必須搭配最低金額）：

```python
from datetime import datetime
from pydantic import model_validator

class OrderApprovalRequest(BaseModel):
    order_date: datetime
    approval_date: datetime
    approved_by: str
    discount_rate: Decimal = Field(default=Decimal("0.00"), ge=0, le=Decimal("0.50"))

    @model_validator(mode="after")
    def check_approval_rules(self):
        # 規則 1：核准時間不可早於下單時間
        if self.approval_date < self.order_date:
            raise ValueError("核准時間 (approval_date) 不可早於訂單建立時間 (order_date)！")
            
        # 規則 2：大額折扣需要特定的經理級簽核者
        if self.discount_rate > Decimal("0.20") and not self.approved_by.startswith("MGR_"):
            raise ValueError("折扣率超過 20% 必須由部門主管 (MGR_ 開頭工號) 親自簽核！")
            
        return self
```

---

## 3. 企業級 Schema 職責分層模式（Separation of Concerns）

### 3.1 為什麼嚴禁「一個 Model 打天下」？

在真實企業場景中，同一個「客戶（Customer）」在不同情境下的資料結構是完全不同的：
- **前端建立客戶時（Create）**：沒有 `created_at`、沒有系統自動生成的 `id`。
- **前端更新客戶時（Update）**：所有欄位皆應為選填（Optional），只更新有帶的欄位。
- **API 回傳給前端時（Response）**：需要包含資料庫生成的 `id` 與時間戳，但**絕對必須隱藏成本毛利率或內部審核備註**！

---

### 3.2 Base, Create, Update, Response 階層架構

```
CustomerBase (共用公開屬性: company_name, industry)
   |
   |-- CustomerCreate (新增專用: 必填 customer_id, tax_id)
   |
   |-- CustomerUpdate (更新專用: 所有屬性轉為 Optional, 供 PATCH 使用)
   |
   \-- CustomerResponse (輸出專用: 繼承 Base + 新增 id, created_at, orders 關聯)
```

---

### 3.3 ORM 互轉關鍵：ConfigDict(from_attributes=True)

在 Pydantic v2 中，加入 `model_config = ConfigDict(from_attributes=True)` 後，Pydantic 就可以直接從 SQLAlchemy ORM 模型物件中提取屬性（`orm_obj.attribute`）進行自動序列化：

```python
from datetime import datetime
from pydantic import ConfigDict

class CustomerResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    customer_id: str
    company_name: str
    industry: str
    credit_limit: Decimal
    created_at: datetime
```

在路由中只需宣告 `response_model=CustomerResponse`，FastAPI 會在背後自動完成 ORM 物件到 JSON 的精準過濾與轉換！

---

## 4. 企業級 CRUD 實戰模式：以 B2B 訂單系統為例

### 4.1 Create：原子交易與悲觀鎖防範超賣

在 B2B 系統中，客戶下單必須依序進行庫存檢驗、扣減與訂單明細生成。使用 `with_for_update()` 防止併發超賣：

```python
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import select

router = APIRouter(prefix="/orders", tags=["訂單管理"])

@router.post("/", response_model=OrderResponse, status_code=status.HTTP_201_CREATED)
def create_order(payload: OrderCreateRequest, db: Session = Depends(get_db)):
    # 1. 檢查客戶存在性與額度
    customer = db.get(Customer, payload.customer_id)
    if not customer:
        raise HTTPException(status_code=404, detail=f"客戶代碼不存在: {payload.customer_id}")

    total_amount = Decimal("0.00")
    order_items_entities = []

    try:
        for item in payload.items:
            # 悲觀鎖定該產品行 (SELECT ... FOR UPDATE)
            stmt = select(Product).where(Product.product_id == item.product_id).with_for_update()
            product = db.scalar(stmt)
            
            if not product:
                raise HTTPException(status_code=400, detail=f"產品不存在: {item.product_id}")
            if product.stock_quantity < item.quantity:
                raise HTTPException(
                    status_code=400,
                    detail=f"產品 [{product.product_name}] 庫存不足！現有: {product.stock_quantity}，需求: {item.quantity}"
                )
                
            # 扣減庫存
            product.stock_quantity -= item.quantity
            line_total = product.selling_price * item.quantity
            total_amount += line_total
            
            order_items_entities.append(
                OrderItem(
                    product_id=item.product_id,
                    quantity=item.quantity,
                    unit_price=product.selling_price
                )
            )

        # 信用額度檢核
        if total_amount > customer.credit_limit:
            raise HTTPException(
                status_code=400,
                detail=f"訂單總額 ${total_amount:,.2f} 超出客戶信用上限 ${customer.credit_limit:,.2f}！"
            )

        # 建立主表
        new_order = Order(
            order_id=payload.order_id,
            customer_id=payload.customer_id,
            salesperson_id=payload.salesperson_id,
            total_amount=total_amount,
            status="APPROVED",
            items=order_items_entities
        )
        
        db.add(new_order)
        db.commit()      # 提交交易，自動釋放悲觀鎖
        db.refresh(new_order)
        return new_order

    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"建立訂單異常: {str(e)}")
```

---

### 4.2 Read：關聯預載與階層序列化

```python
from sqlalchemy.orm import joinedload, selectinload

@router.get("/{order_id}", response_model=OrderDetailResponse)
def get_order_detail(order_id: str, db: Session = Depends(get_db)):
    stmt = (
        select(Order)
        .where(Order.order_id == order_id)
        .options(
            joinedload(Order.customer),
            selectinload(Order.items).joinedload(OrderItem.product)
        )
    )
    order = db.scalar(stmt)
    if not order:
        raise HTTPException(status_code=404, detail="找不到該訂單")
    return order
```

---

### 4.3 Update：PATCH 局部增量更新與 exclude_unset

這是現代 API 開發最精華的技巧：
使用 `payload.model_dump(exclude_unset=True)`，**只會提取前端在 JSON 中明確傳入的欄位**，沒有傳入的欄位不會覆蓋資料庫現有值！

```python
@router.patch("/{order_id}", response_model=OrderResponse)
def patch_order(order_id: str, payload: OrderPatchRequest, db: Session = Depends(get_db)):
    order = db.get(Order, order_id)
    if not order:
        raise HTTPException(status_code=404, detail="找不到該訂單")

    # 關鍵：exclude_unset=True 僅取出實際有被給值的欄位
    update_data = payload.model_dump(exclude_unset=True)
    
    if not update_data:
        raise HTTPException(status_code=400, detail="未提供任何欲更新的有效欄位")

    for field, value in update_data.items():
        setattr(order, field, value)

    db.commit()
    db.refresh(order)
    return order
```

---

### 4.4 Delete：企業軟刪除（Soft Delete）實務

在商業資料庫中，訂單與客戶資料絕對不可物理刪除（`DELETE FROM`），否則歷年財務審計、進銷存報表將直接崩毀。

```python
@router.delete("/{order_id}", status_code=status.HTTP_204_NO_CONTENT)
def soft_delete_order(order_id: str, db: Session = Depends(get_db)):
    order = db.get(Order, order_id)
    if not order:
        raise HTTPException(status_code=404, detail="訂單不存在")

    # 軟刪除：標記狀態為 CANCELLED 或 is_deleted = True
    order.status = "CANCELLED"
    db.commit()
    return None
```

---

## 5. 常見避坑指南與資安規範

1. **永遠在端點標註 `response_model`**：
   - 避免直接 `return orm_object`，若沒設 `response_model`，ORM 物件可能將包含密碼雜湊或成本價在內的內部屬性全數吐給前端。
2. **避免在 Pydantic 預設值使用可變物件（Mutable Defaults）**：
   - 錯誤：`items: List[Item] = []`
   - 正確：`items: List[Item] = Field(default_factory=list)`
3. **Decimal 精度保留**：
   - 涉及貨幣計算與回傳時，優先使用 `Decimal` 而非 `float`，防止 `19.99` 變成 `19.989999999999998`。

---

## 6. 商業情境綜合練習題（含詳解）

### 題目一：設計具備防重複與業務邏輯的 B2B 下單 Pydantic Schema
**業務情境**：
請設計一組 Pydantic v2 Schema：
1. `OrderItemCreate`：包含 `product_id`（字串）與 `quantity`（整數，必須大於 0）。
2. `OrderCreateRequest`：包含 `order_id`、`customer_id`、`salesperson_id`、`items`（列表，至少包含 1 項商品）。
3. 商業規則校驗：在 `OrderCreateRequest` 中使用 `@model_validator(mode="after")` 檢驗：
   - 購物車內的 `product_id` 不能重複出現（若有重複品項，要求前端先合併數量）。
   - 購物車內單項商品的數量上限不得超過 1,000 件。

#### 【題目一解答程式碼】
```python
from typing import List
from pydantic import BaseModel, Field, model_validator

class OrderItemCreate(BaseModel):
    product_id: str = Field(..., min_length=3, max_length=30, examples=["PROD_CHIP_01"])
    quantity: int = Field(..., gt=0, le=1000, description="購買數量需介於 1 到 1000 之間")

class OrderCreateRequest(BaseModel):
    order_id: str = Field(..., pattern=r"^ORD_[0-9]{4}_[0-9]{3,}$")
    customer_id: str = Field(..., min_length=3)
    salesperson_id: str = Field(..., min_length=3)
    items: List[OrderItemCreate] = Field(..., min_length=1, description="至少需訂購一項產品")

    @model_validator(mode="after")
    def validate_unique_products(self):
        seen_products = set()
        for item in self.items:
            if item.product_id in seen_products:
                raise ValueError(f"下單明細中出現重複產品代號 [{item.product_id}]，請先合併數量後再送出！")
            seen_products.add(item.product_id)
        return self
```

---

### 題目二：實作客戶信用額度調整審批端點（含樂觀鎖或狀態檢查）
**業務情境**：
在 `endpoints/customers.py` 實作端點 `POST /api/v1/customers/{customer_id}/credit-limit`：
- 輸入 Schema：`CreditLimitUpdateRequest`（包含 `requested_limit: Decimal` 與 `approval_token: str`）。
- 業務規則：
  1. 客戶必須存在。
  2. 若調整後的新額度超過原有額度的 2 倍，`approval_token` 必須為 `"CFO_APPROVED_SECRET"`，否則拋出 `403 Forbidden`。
  3. 成功更新後返回 `CustomerResponse`。

#### 【題目二解答程式碼】
```python
from decimal import Decimal
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

class CreditLimitUpdateRequest(BaseModel):
    requested_limit: Decimal = Field(..., ge=0)
    approval_token: str = Field(default="")

@router.post("/customers/{customer_id}/credit-limit", response_model=CustomerResponse)
def adjust_credit_limit(
    customer_id: str,
    payload: CreditLimitUpdateRequest,
    db: Session = Depends(get_db)
):
    customer = db.get(Customer, customer_id)
    if not customer:
        raise HTTPException(status_code=404, detail="查無該客戶紀錄")

    current_limit = customer.credit_limit
    new_limit = payload.requested_limit

    # 商業防偽：超過雙倍需高階財務核准碼
    if new_limit > (current_limit * Decimal("2.0")):
        if payload.approval_token != "CFO_APPROVED_SECRET":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"信用額度由 ${current_limit:,.2f} 翻倍提升至 ${new_limit:,.2f} 屬於高風險操作，需要 CFO 審批授權碼！"
            )

    customer.credit_limit = new_limit
    db.commit()
    db.refresh(customer)
    return customer
```

---

### 題目三：整合 Pydantic 與自定義分頁回傳泛型包裝器（Generic Response Wrapper）
**業務情境**：
為了讓前端團隊在串接所有清單 API 時擁有統一的資料格式，請設計一個支援泛型（Generic）的 `PaginatedResponse[T]` Pydantic 容器模型，並實作於產品清單端點。

#### 【題目三解答程式碼】
```python
from typing import Generic, TypeVar, List
from pydantic import BaseModel
from fastapi import Query

# 定義泛型變數
T = TypeVar("T")

class PaginatedResponse(BaseModel, Generic[T]):
    success: bool = True
    total: int
    page: int
    limit: int
    items: List[T]

class ProductResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    product_id: str
    product_name: str
    category: str
    selling_price: Decimal
    stock_quantity: int

# 套用於產品分頁端點
@router.get("/products", response_model=PaginatedResponse[ProductResponse])
def list_products(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db)
):
    offset = (page - 1) * limit
    total = db.scalar(select(func.count(Product.product_id))) or 0
    products = db.scalars(select(Product).offset(offset).limit(limit)).all()

    return PaginatedResponse[ProductResponse](
        total=total,
        page=page,
        limit=limit,
        items=products
    )
```
