from sqlalchemy.orm import Session
from models import Customer, Order
import schemas

def get_customer(db: Session, customer_id: int):
    return db.query(Customer).filter(Customer.customer_id == customer_id).first()

def get_customer_by_tax_id(db: Session, tax_id: str):
    return db.query(Customer).filter(Customer.tax_id == tax_id).first()

def get_customers(db: Session, skip: int = 0, limit: int = 20, city: str = None):
    query = db.query(Customer)
    if city:
        query = query.filter(Customer.city == city)
    return query.offset(skip).limit(limit).all()

def create_customer(db: Session, customer: schemas.CustomerCreate):
    db_customer = Customer(
        company_name=customer.company_name,
        tax_id=customer.tax_id,
        industry=customer.industry,
        city=customer.city,
        credit_limit=customer.credit_limit
    )
    db.add(db_customer)
    db.commit()
    db.refresh(db_customer)
    return db_customer

def update_customer(db: Session, customer_id: int, customer_update: schemas.CustomerUpdate):
    db_customer = get_customer(db, customer_id)
    if not db_customer:
        return None
    update_data = customer_update.dict(exclude_unset=True)
    for key, value in update_data.items():
        setattr(db_customer, key, value)
    db.commit()
    db.refresh(db_customer)
    return db_customer

def delete_customer(db: Session, customer_id: int):
    db_customer = get_customer(db, customer_id)
    if db_customer:
        db.delete(db_customer)
        db.commit()
        return True
    return False
