from sqlalchemy import Column, Integer, String, Numeric, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from datetime import datetime
from database import Base

class Customer(Base):
    __tablename__ = "api_customers"

    customer_id = Column(Integer, primary_key=True, index=True)
    company_name = Column(String(120), nullable=False)
    tax_id = Column(String(20), unique=True, index=True, nullable=True)
    industry = Column(String(50), nullable=False)
    city = Column(String(30), nullable=False)
    credit_limit = Column(Numeric(12, 2), default=100000.00)
    status = Column(String(20), default="ACTIVE")
    created_at = Column(DateTime, default=datetime.utcnow)

    orders = relationship("Order", back_populates="customer")

class Order(Base):
    __tablename__ = "api_orders"

    order_id = Column(Integer, primary_key=True, index=True)
    order_number = Column(String(40), unique=True, index=True, nullable=False)
    customer_id = Column(Integer, ForeignKey("api_customers.customer_id"), nullable=False)
    order_date = Column(DateTime, default=datetime.utcnow)
    status = Column(String(20), default="PENDING")
    total_amount = Column(Numeric(12, 2), default=0.00)

    customer = relationship("Customer", back_populates="orders")
