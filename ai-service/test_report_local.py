"""
本地快速测试周报/月报功能,不需要起服务器,直接跑:
    python3 test_report_local.py

先测正常情况(有4条体重记录),再测数据不够的情况(只有1条记录),
确认两种情况AI都能给出合理的文字,不会编数字。
"""

from app.mock_data import MOCK_PROFILE, MOCK_WEEKLY_WEIGHT_RECORDS, MOCK_INSUFFICIENT_WEIGHT_RECORDS
from app.report_calculator import calculate_report_stats
from app.claude_client import generate_report_summary

if __name__ == "__main__":
    print("===== 情况1: 数据充足(4条体重记录) =====")
    stats = calculate_report_stats(MOCK_WEEKLY_WEIGHT_RECORDS, MOCK_PROFILE)
    print(f"开始体重: {stats.start_weight_kg} kg")
    print(f"结束体重: {stats.end_weight_kg} kg")
    print(f"变化: {stats.delta_kg} kg")
    print(f"目标进度: {stats.progress_to_goal_percent}%")
    print(f"预计还需: {stats.projected_weeks_to_goal} 周")
    summary = generate_report_summary(stats, MOCK_PROFILE, "weekly")
    print(f"AI总结: {summary}")

    print("\n===== 情况2: 数据不够(只有1条记录) =====")
    stats2 = calculate_report_stats(MOCK_INSUFFICIENT_WEIGHT_RECORDS, MOCK_PROFILE)
    print(f"数据是否充足: {stats2.has_enough_data}")
    summary2 = generate_report_summary(stats2, MOCK_PROFILE, "weekly")
    print(f"AI总结: {summary2}")
