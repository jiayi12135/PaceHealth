"""
数据模型定义。
这些字段名直接对齐团队讨论好的数据库表结构:
Profile / UserPersonalInfo (输入) -> AI Plan / SportsType (输出)
"""

from datetime import date
from typing import List, Literal, Optional
from pydantic import BaseModel, Field


# ---------- 输入:对应 Profile 表 ----------
class Profile(BaseModel):
    name: str
    age: int
    sex: str  # "male" / "female" / "other"
    heightCm: float
    startWeightKg: float  # 最一开始用户输入/设定目标时的体重,团队会议决定用这个名字替代原来含糊的currentWeightKg,这个值定了之后不会跟着日常体重打卡变动
    targetWeightKg: float
    goal: str  # 例如 "lose_weight", "gain_muscle", "improve_endurance"
    lifestyle: str  # 例如 "sedentary desk job", "active retail job"
    exerciseFrequencyPerWeek: int
    exerciseDurationMinutes: int
    exerciseHabit: List[str] = Field(default_factory=list)  # 例如 ["dancing", "swimming", "sport"]
    exerciseLocation: str  # 例如 "home", "gym", "swimming", "pilates"


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


# ---------- 聊天:对应 Chat Record 表的一条历史消息 ----------
class ChatMessage(BaseModel):
    role: str  # "user" 或 "assistant"
    message: str


# ---------- 聊天:请求体 ----------
# profile / personalInfo 设为可选,前期没传的话AI仍然可以回答通用健身知识问题,
# 只是没法给出针对这个用户的个性化建议。
class ChatRequest(BaseModel):
    userId: str
    message: str  # 用户这一次发的新消息
    history: List[ChatMessage] = Field(default_factory=list)  # 之前的聊天记录,由backend从数据库里取出来传过来
    profile: Optional[Profile] = None
    personalInfo: Optional[UserPersonalInfo] = None


# ---------- 聊天:返回体 ----------
class ChatResponse(BaseModel):
    reply: str


# ---------- 报告:对应 Weight Record 表的一条体重记录 ----------
class WeightPoint(BaseModel):
    weightKg: float
    recordedAt: date


# ---------- 报告:请求体 ----------
# weightRecords 由backend从数据库按时间范围查出来传过来(按recordedAt从早到晚排序),
# 这个AI服务不连数据库、不自己筛日期范围。
class ReportRequest(BaseModel):
    userId: str
    periodType: Literal["weekly", "monthly"]
    profile: Profile
    weightRecords: List[WeightPoint] = Field(default_factory=list)


# ---------- 报告:返回体 ----------
# initialWeightKg / endWeightKg / deltaKg / progressToGoalPercent / projectedWeeksToGoal
# 全部由Python代码算出来(见 report_calculator.py),不是AI生成的,保证数字准确。
# summary 才是AI写的那段总结文字。
# 注意: initialWeightKg 指的是"这个周期(本周/本月)开始时"的体重,跟 Profile.startWeightKg
# (最初设定目标时的体重)是两个不同的概念,不要搞混——这个字段名对齐的是 Report 表里的 initialWeightKg。
class ReportResponse(BaseModel):
    periodType: Literal["weekly", "monthly"]
    hasEnoughData: bool  # 记录数不够(少于2条)时为False,此时下面几个数字字段会是null
    initialWeightKg: Optional[float] = None
    endWeightKg: Optional[float] = None
    deltaKg: Optional[float] = None  # 负数=变轻,正数=变重
    progressToGoalPercent: Optional[float] = None  # 0-100,朝目标体重前进了百分之多少
    projectedWeeksToGoal: Optional[float] = None  # 按当前速度还需要几周达到目标,如果方向不对/没有变化则为null
    summary: str  # AI生成的总结文字
    weightRecords: List[WeightPoint] = Field(default_factory=list)  # 原样带回请求里传的体重记录,方便frontend直接画折线图,不用再单独查一次


# ---------- 器材识别:请求体 ----------
# 图片用URL传过来(backend先把用户拍的照片上传到Supabase Storage,拿到一个公开可访问
# 的URL,再把这个URL传给这个AI服务;这个AI服务会直接把URL交给Claude去读图,
# 不需要自己下载图片、不需要转base64)。
# personalInfo可选,传了的话AI会在安全提示里额外考虑用户的伤病情况。
class EquipmentIdentifyRequest(BaseModel):
    userId: str
    imageUrl: str  # 图片的公开访问URL(比如Supabase Storage生成的链接),必须是Claude能直接访问到的地址
    personalInfo: Optional[UserPersonalInfo] = None


# ---------- 器材识别:返回体 ----------
class EquipmentIdentifyResponse(BaseModel):
    recognized: bool  # False表示AI没能从照片里认出健身器材(照片不清楚/不是器材/看不出来)
    confidence: float  # 0到1之间,AI对这次识别结果的把握程度(recognized=False时通常会是较低的数字)
    equipmentName: Optional[str] = None  # 识别出的器材名称,recognized=False时为null
    description: Optional[str] = None  # 这个器材是什么、主要用来练什么
    targetMuscles: List[str] = Field(default_factory=list)  # 主要训练的肌群
    usageInstructions: Optional[str] = None  # 怎么使用这个器材(步骤说明)
    safetyNotes: Optional[str] = None  # 使用时的安全注意事项、常见错误
    personalizedWarning: Optional[str] = None  # 如果传了personalInfo,且这个器材可能不适合用户的伤病情况,这里会有提醒;没有顾虑则为null
    notRecognizedMessage: Optional[str] = None  # recognized=False时,给用户的提示(比如"照片不够清楚,请重新拍摄")
