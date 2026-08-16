"""
体重相关的数字计算,全部用普通 Python 数学算,不经过 AI。

为什么不让AI算数字: 大语言模型对精确算术、日期计算不是100%可靠,容易算错或编数字。
把"算数字"和"写总结"这两件事分开,数字用代码保证准确,AI只负责在数字基础上
写一段人话总结,是更稳妥的做法。
"""

from typing import List, Optional

from app.models import Profile, WeightPoint


class ReportStats:
    """算出来的这些数字,传给AI写总结用,也直接作为API返回结果的一部分"""

    def __init__(
        self,
        has_enough_data: bool,
        start_weight_kg: Optional[float] = None,
        end_weight_kg: Optional[float] = None,
        delta_kg: Optional[float] = None,
        progress_to_goal_percent: Optional[float] = None,
        projected_weeks_to_goal: Optional[float] = None,
    ):
        self.has_enough_data = has_enough_data
        self.start_weight_kg = start_weight_kg
        self.end_weight_kg = end_weight_kg
        self.delta_kg = delta_kg
        self.progress_to_goal_percent = progress_to_goal_percent
        self.projected_weeks_to_goal = projected_weeks_to_goal


def calculate_report_stats(weight_records: List[WeightPoint], profile: Profile) -> ReportStats:
    # 数据不够就直接返回,不用往下算,避免用一两个点硬算出没有意义的数字
    if len(weight_records) < 2:
        return ReportStats(has_enough_data=False)

    # 假设 weight_records 已经按时间从早到晚排好序(backend负责排序好再传进来)
    first = weight_records[0]
    last = weight_records[-1]

    start_weight_kg = first.weightKg
    end_weight_kg = last.weightKg
    delta_kg = round(end_weight_kg - start_weight_kg, 2)

    # ---- 目标进度百分比 ----
    # 用 profile.startWeightKg 当作"起点"(用户最初设定目标时的体重,团队会议已经确认
    # 这个字段固定不变,不会跟着日常体重打卡更新),用最新一条体重记录当作"现在的位置",
    # 算走了目标距离的百分之多少。
    direction_kg = profile.targetWeightKg - profile.startWeightKg  # 正=要增重,负=要减重
    progress_to_goal_percent: Optional[float] = None
    if direction_kg == 0:
        progress_to_goal_percent = 100.0
    else:
        traveled_kg = end_weight_kg - profile.startWeightKg
        progress_to_goal_percent = round((traveled_kg / direction_kg) * 100, 1)

    # ---- 按当前速度预计还需要几周达到目标 ----
    days_spanned = (last.recordedAt - first.recordedAt).days
    projected_weeks_to_goal: Optional[float] = None
    if days_spanned > 0:
        weekly_rate_kg = delta_kg / (days_spanned / 7)
        remaining_kg = profile.targetWeightKg - end_weight_kg

        if remaining_kg == 0:
            projected_weeks_to_goal = 0.0
        elif weekly_rate_kg != 0 and (remaining_kg > 0) == (weekly_rate_kg > 0):
            # 剩余距离和每周变化速度方向一致,说明确实在朝目标前进,才能算出预计周数
            projected_weeks_to_goal = round(remaining_kg / weekly_rate_kg, 1)
        # 否则(速度是0,或者方向跟目标相反,比如目标要减重但体重却在增加)
        # 保持 None,代表现在这个趋势没法预测/正在偏离目标

    return ReportStats(
        has_enough_data=True,
        start_weight_kg=start_weight_kg,
        end_weight_kg=end_weight_kg,
        delta_kg=delta_kg,
        progress_to_goal_percent=progress_to_goal_percent,
        projected_weeks_to_goal=projected_weeks_to_goal,
    )
