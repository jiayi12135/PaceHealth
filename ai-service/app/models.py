"""
数据模型定义。
这些字段名直接对齐团队讨论好的数据库表结构:
Profile / UserPersonalInfo (输入) -> AI Plan / SportsType (输出)
"""

from typing import List, Optional
from pydantic import BaseModel, Field


# ---------- 输入:对应 Profile 表 ----------
class Profile(BaseModel):
    name: str
    age: int
    sex: str  # "male" / "female" / "other"
    heightCm: float
    currentWeightKg: float
    targetWeightKg: float
    goal: str  # 例如 "lose_weight", "gain_muscle", "improve_endurance"
    lifestyle: str  # 例如 "sedentary desk job", "active retail job"
    exerciseFrequencyPerWeek: int
    exerciseDurationMinutes: int
    exerciseLocation: str  # 例如 "home", "gym", "outdoor"


# ---------- 输入:对应 UserPersonalInfo 表 ----------
class UserPersonalInfo(BaseModel):
    availableEquipment: List[str] = Field(default_factory=list)
    postureIssues: List[str] = Field(default_factory=list)
    injuries: List[str] = Field(default_factory=list)
    surgeryHistory: List[str] = Field(default_factory=list)
    exercisesToAvoid: List[str] = Field(default_factory=list)


# ---------- 请求体:前端/后端发给这个AI服务的完整数据 ----------
class GeneratePlanRequest(BaseModel):
    userId: str
    profile: Profile
    personalInfo: UserPersonalInfo


# ---------- 输出:对应 SportsType 表(计划里的单个动作) ----------
class Exercise(BaseModel):
    day: str  # 例如 "Monday" 或 "Day 1"
    exerciseName: str
    sets: int
    reps: Optional[int] = None       # 力量动作用
    duration: Optional[int] = None   # 有氧/拉伸类动作用,单位秒
    restSeconds: int
    reason: str  # 为什么给用户推荐这个动作(个性化理由)
    videoUrl: Optional[str] = None


# ---------- 输出:对应 AI Plan 表 ----------
class WorkoutPlan(BaseModel):
    planName: str
    goal: str
    weeklyFrequency: int
    exercises: List[Exercise]
