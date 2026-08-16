"""
本地快速测试脚本,不需要起服务器,直接跑:
    python test_local.py

用假数据(mock_data.py)调用一次 Claude API,打印出生成的训练计划,
用来验证 prompt 设计和 API 调用是否正常。
"""

import json
from app.mock_data import MOCK_PROFILE, MOCK_PERSONAL_INFO
from app.claude_client import generate_workout_plan

if __name__ == "__main__":
    plan = generate_workout_plan(MOCK_PROFILE, MOCK_PERSONAL_INFO)
    print(json.dumps(plan.model_dump(), indent=2, ensure_ascii=False))
