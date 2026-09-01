"""
Text-to-SQL 智慧 Agent 引擎
"""

import os
import re
import json
from typing import Dict, Any
from prompts import SYSTEM_PROMPT

FORBIDDEN_KEYWORDS = ["DROP", "DELETE", "UPDATE", "INSERT", "ALTER", "TRUNCATE", "GRANT", "REVOKE"]

def is_safe_sql(sql: str) -> bool:
    """檢查 SQL 是否為唯讀安全語法。"""
    cleaned = sql.strip().upper()
    if not (cleaned.startswith("SELECT") or cleaned.startswith("WITH")):
        return False
    for kw in FORBIDDEN_KEYWORDS:
        if re.search(r'\b' + kw + r'\b', cleaned):
            return False
    return True

class AISQLAgent:
    def __init__(self, api_key: str = None):
        self.api_key = api_key or os.getenv("OPENAI_API_KEY")

    def generate_sql(self, user_query: str) -> Dict[str, Any]:
        """將自然語言提問轉換為 SQL。支援 Mock 模式供無金鑰演示。"""
        # 若無 API Key，提供智慧範例匹配 (Mock Mode)
        if not self.api_key:
            return self._mock_llm_response(user_query)

        # 若有 OpenAI / Gemini API 金鑰可呼叫真實 LLM
        try:
            from openai import OpenAI
            client = OpenAI(api_key=self.api_key)
            response = client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": user_query}
                ],
                response_format={"type": "json_object"},
                temperature=0.0
            )
            result = json.loads(response.choices[0].message.content)
            if not is_safe_sql(result.get("sql", "")):
                result["is_safe"] = False
                result["error"] = "安全警報：該查詢包含非唯讀指令，已強制攔截！"
            else:
                result["is_safe"] = True
            return result
        except Exception as e:
            return {"error": f"LLM 呼叫失敗: {e}", "sql": "", "is_safe": False}

    def _mock_llm_response(self, query: str) -> Dict[str, Any]:
        """內建模擬模式：展示 Text-to-SQL 的精確轉換能力。"""
        q = query.lower()
        if "台北" in q or "taipei" in q:
            return {
                "thought": "使用者欲查詢台北地區客戶消費排名，需關聯 customers 與 orders 並過濾 city = 'Taipei' 與 status = 'COMPLETED'。",
                "sql": "SELECT c.company_name, SUM(o.total_amount) AS total_spent FROM customers c JOIN orders o ON c.customer_id = o.customer_id WHERE c.city = 'Taipei' AND o.status = 'COMPLETED' GROUP BY c.company_name ORDER BY total_spent DESC LIMIT 3;",
                "explanation": "查詢台北地區累積已完成訂單金額最高的前 3 名企業客戶。",
                "is_safe": True,
                "mode": "Mock Demo"
            }
        elif "業績" in q or "業務" in q:
            return {
                "thought": "使用者欲查詢業務員業績與達成率，需關聯 salespeople 與 orders 表。",
                "sql": "SELECT s.name, s.region, s.monthly_target, COALESCE(SUM(o.total_amount), 0) AS total_revenue, ROUND(COALESCE(SUM(o.total_amount), 0) / s.monthly_target * 100, 2) AS attainment_pct FROM salespeople s LEFT JOIN orders o ON s.salesperson_id = o.salesperson_id AND o.status = 'COMPLETED' GROUP BY s.salesperson_id, s.name, s.region, s.monthly_target ORDER BY total_revenue DESC;",
                "explanation": "計算每位業務員的累積完成業績與 Quota 達成百分比。",
                "is_safe": True,
                "mode": "Mock Demo"
            }
        else:
            return {
                "thought": "通用型自然語言查詢，統計各產業客戶分佈與平均信用額度。",
                "sql": "SELECT industry, COUNT(*) AS customer_count, ROUND(AVG(credit_limit), 2) AS avg_credit FROM customers GROUP BY industry ORDER BY customer_count DESC;",
                "explanation": "統計各產業的客戶總數與平均信用額度。",
                "is_safe": True,
                "mode": "Mock Demo"
            }
