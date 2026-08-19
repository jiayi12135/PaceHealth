"""
本地快速测试食谱推荐功能,不需要起服务器,直接跑:
    python3 test_meal_plan_local.py

用假数据(mock_data.py)调用两次 Claude API:
1. 不带最近进度数据 —— 正常按目标+可用食材生成食谱,adjustmentNote应该是null
2. 带"进度停滞"的假数据 —— 验证AI会不会在adjustmentNote里给出合理的调整建议

用来验证 prompt 设计和 API 调用是否正常。
"""

import json

from app.mock_data import (
    MOCK_AVAILABLE_INGREDIENTS,
    MOCK_DIETARY_RESTRICTIONS,
    MOCK_PROFILE,
    MOCK_STALLED_PROGRESS,
)
from app.claude_client import generate_meal_plan

if __name__ == "__main__":
    print("=== 场景1: 没有最近进度数据 ===")
    plan = generate_meal_plan(
        profile=MOCK_PROFILE,
        available_ingredients=MOCK_AVAILABLE_INGREDIENTS,
        dietary_restrictions=MOCK_DIETARY_RESTRICTIONS,
        recent_progress=None,
    )
    print(json.dumps(plan.model_dump(), indent=2, ensure_ascii=False))

    print("\n=== 场景2: 减重目标但进度停滞,看AI会不会给出adjustmentNote ===")
    plan_with_progress = generate_meal_plan(
        profile=MOCK_PROFILE,
        available_ingredients=MOCK_AVAILABLE_INGREDIENTS,
        dietary_restrictions=MOCK_DIETARY_RESTRICTIONS,
        recent_progress=MOCK_STALLED_PROGRESS,
    )
    print(json.dumps(plan_with_progress.model_dump(), indent=2, ensure_ascii=False))
