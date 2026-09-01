from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime

class CustomerBase(BaseModel):
    company_name: str = Field(..., min_length=2, max_length=120)
    tax_id: Optional[str] = Field(None, min_length=8, max_length=8)
    industry: str
    city: str
    credit_limit: float = 100000.0

class CustomerCreate(CustomerBase):
    pass

class CustomerUpdate(BaseModel):
    company_name: Optional[str] = None
    industry: Optional[str] = None
    city: Optional[str] = None
    credit_limit: Optional[float] = None
    status: Optional[str] = None

class CustomerResponse(CustomerBase):
    customer_id: int
    status: str
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True

class OrderBase(BaseModel):
    order_number: str
    customer_id: int
    status: str = "PENDING"
    total_amount: float = 0.0

class OrderCreate(OrderBase):
    pass

class OrderResponse(OrderBase):
    order_id: int
    order_date: Optional[datetime] = None

    class Config:
        from_attributes = True
