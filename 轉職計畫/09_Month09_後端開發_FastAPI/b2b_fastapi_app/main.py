"""
FastAPI 主應用程式入口
提供 B2B 客戶與訂單的 RESTful CRUD API 與 Swagger 互動式文檔
"""

from fastapi import FastAPI, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import List, Optional
import models
import schemas
import crud
from database import engine, get_db

# 自動建立資料表結構
models.Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="B2B Customer & Order Management API",
    description="企業級 B2B 客戶與業務訂單管理 RESTful API 服務",
    version="1.0.0"
)

@app.get("/", tags=["Health"])
def root():
    return {
        "service": "B2B Backend API",
        "status": "online",
        "docs_url": "/docs"
    }

# ----------------- Customers Endpoints -----------------

@app.post("/api/v1/customers", response_model=schemas.CustomerResponse, status_code=status.HTTP_201_CREATED, tags=["Customers"])
def create_new_customer(customer: schemas.CustomerCreate, db: Session = Depends(get_db)):
    if customer.tax_id:
        existing = crud.get_customer_by_tax_id(db, customer.tax_id)
        if existing:
            raise HTTPException(status_code=400, detail=f"統編 {customer.tax_id} 已被建檔註冊！")
    return crud.create_customer(db=db, customer=customer)

@app.get("/api/v1/customers", response_model=List[schemas.CustomerResponse], tags=["Customers"])
def read_customers(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    city: Optional[str] = None,
    db: Session = Depends(get_db)
):
    return crud.get_customers(db, skip=skip, limit=limit, city=city)

@app.get("/api/v1/customers/{customer_id}", response_model=schemas.CustomerResponse, tags=["Customers"])
def read_customer_by_id(customer_id: int, db: Session = Depends(get_db)):
    db_customer = crud.get_customer(db, customer_id=customer_id)
    if not db_customer:
        raise HTTPException(status_code=404, detail="找不到該客戶 ID")
    return db_customer

@app.put("/api/v1/customers/{customer_id}", response_model=schemas.CustomerResponse, tags=["Customers"])
def update_customer_info(customer_id: int, customer_in: schemas.CustomerUpdate, db: Session = Depends(get_db)):
    updated = crud.update_customer(db, customer_id=customer_id, customer_update=customer_in)
    if not updated:
        raise HTTPException(status_code=404, detail="找不到該客戶 ID")
    return updated

@app.delete("/api/v1/customers/{customer_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["Customers"])
def remove_customer(customer_id: int, db: Session = Depends(get_db)):
    success = crud.delete_customer(db, customer_id=customer_id)
    if not success:
        raise HTTPException(status_code=404, detail="找不到該客戶 ID")
    return None

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
