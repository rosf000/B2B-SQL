"""
互動式 AI 商業數據助理 CLI 展示程式
"""

import sys
from sql_agent import AISQLAgent, is_safe_sql

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


def main():
    agent = AISQLAgent()
    print("=" * 60)
    print("🤖 歡迎使用 AI Business Data Assistant (自然語言數據助理)")
    print("支援直接用口語提問，例如：")
    print("  1. 『幫我查台北買最多的前 3 名客戶』")
    print("  2. 『每位業務員的業績達成率如何？』")
    print("  3. 『統計各產業的客戶總數』")
    print("輸入 'exit' 或 'quit' 退出程式。")
    print("=" * 60)

    demo_queries = [
        "幫我查台北買最多的前 3 名客戶",
        "每位業務員的業績達成率如何？",
        "統計各產業的客戶總數"
    ]

    for i, q in enumerate(demo_queries, 1):
        print(f"\n[示範提問 {i}] 👤 使用者問：『{q}』")
        res = agent.generate_sql(q)
        print(f"🧠 [AI 思考邏輯] {res.get('thought')}")
        print(f"⚡ [生成 SQL 語法]\n   {res.get('sql')}")
        print(f"📊 [商業說明] {res.get('explanation')}")
        print(f"🛡️ [安全校驗] {'✅ 通過 (純唯讀查詢)' if res.get('is_safe') else '❌ 攔截'}")
        print("-" * 50)

if __name__ == "__main__":
    main()
