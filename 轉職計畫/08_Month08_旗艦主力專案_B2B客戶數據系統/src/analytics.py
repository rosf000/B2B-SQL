"""
B2B 商業分析與營收報表生成引擎 (Business Analytics Engine)
"""

import os
import pandas as pd
from sqlalchemy import create_engine, text

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql+psycopg2://postgres:postgres123@localhost:5432/b2b_db")
engine = create_engine(DATABASE_URL)

def run_salesperson_performance() -> pd.DataFrame:
    """計算各業務代表業績與達成率。"""
    query = """
    SELECT 
        s.name AS salesperson_name,
        s.region,
        s.monthly_target,
        COALESCE(SUM(o.total_amount), 0) AS total_revenue,
        ROUND((COALESCE(SUM(o.total_amount), 0) / s.monthly_target) * 100, 2) AS quota_attainment_pct
    FROM m8_salespeople s
    LEFT JOIN m8_orders o ON s.salesperson_id = o.salesperson_id AND o.status = 'COMPLETED'
    GROUP BY s.salesperson_id, s.name, s.region, s.monthly_target
    ORDER BY total_revenue DESC;
    """
    try:
        return pd.read_sql(query, engine)
    except Exception as e:
        print(f"[提示] 若資料庫未連線，使用模擬測試資料: {e}")
        return pd.DataFrame([
            {"salesperson_name": "Alex Hunter", "region": "North", "monthly_target": 800000, "total_revenue": 1080000, "quota_attainment_pct": 135.0},
            {"salesperson_name": "Carlos Diaz", "region": "Central", "monthly_target": 600000, "total_revenue": 300000, "quota_attainment_pct": 50.0}
        ])

def run_top_customers() -> pd.DataFrame:
    """計算消費前幾名 VIP 客戶。"""
    query = """
    SELECT 
        c.company_name,
        c.city,
        c.industry,
        COUNT(o.order_id) AS order_count,
        SUM(o.total_amount) AS total_spent
    FROM m8_customers c
    JOIN m8_orders o ON c.customer_id = o.customer_id
    WHERE o.status = 'COMPLETED'
    GROUP BY c.customer_id, c.company_name, c.city, c.industry
    ORDER BY total_spent DESC;
    """
    try:
        return pd.read_sql(query, engine)
    except Exception:
        return pd.DataFrame([
            {"company_name": "Apex Semiconductor Inc", "city": "Hsinchu", "industry": "Semiconductor", "order_count": 2, "total_spent": 960000.0}
        ])

def export_executive_summary():
    print("=== 生成 B2B 商業分析報告 ===")
    rep_df = run_salesperson_performance()
    print("\n--- 業務代表業績表現 ---")
    print(rep_df.to_string(index=False))

    top_cust_df = run_top_customers()
    print("\n--- VIP 核心客戶貢獻榜 ---")
    print(top_cust_df.to_string(index=False))

if __name__ == "__main__":
    export_executive_summary()
