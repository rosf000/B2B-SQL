# 02 Pydantic 資料驗證與 CRUD 實作

## 一、Pydantic 2.0 Schema 定義

```python
from pydantic import BaseModel, Field, EmailStr
from typing import Optional
from datetime import datetime

class CustomerBase(BaseModel):
    company_name: str = Field(..., min_length=2, max_length=120, description="企業名稱")
    tax_id: Optional[str] = Field(None, min_length=8, max_length=8, description="8碼統一編號")
    industry: str = Field(..., description="所屬產業")
    city: str = Field(..., description="所在城市")
    credit_limit: float = Field(default=100000.0, ge=0, description="信用額度需>=0")

class CustomerCreate(CustomerBase):
    pass

class CustomerResponse(CustomerBase):
    customer_id: int
    status: str
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True # 支援 SQLAlchemy ORM 轉換
```
