"""测试用的假数据,不消耗真实用户信息"""

from datetime import date, timedelta

from app.models import ChatMessage, Profile, UserPersonalInfo, WeightPoint

MOCK_PROFILE = Profile(
    name="Test User",
    age=28,
    sex="female",
    heightCm=165,
    startWeightKg=68,
    targetWeightKg=60,
    goal="lose_weight",
    lifestyle="sedentary desk job, sits 8+ hours a day",
    exerciseFrequencyPerWeek=3,
    exerciseDurationMinutes=45,
    exerciseHabit=["dancing", "swimming"],
    exerciseLocation="home",
)

MOCK_PERSONAL_INFO = UserPersonalInfo(
    availableEquipment=["dumbbells", "yoga mat", "resistance bands"],
    postureIssues=["forward head posture", "rounded shoulders"],
    injuries=["mild lower back pain"],
    surgeryHistory=[],
    exercisesToAvoid=["heavy deadlifts", "high-impact jumping"],
)

# 模拟一段之前已经聊过的记录,测试AI能不能接上上下文
MOCK_CHAT_HISTORY = [
    ChatMessage(role="user", message="我今天练完深蹲之后膝盖有点酸,正常吗?"),
    ChatMessage(role="assistant", message="轻微酸胀通常是正常的肌肉反应,但如果是关节里面的疼痛就要注意。建议你练习前多做几分钟热身,深蹲时膝盖不要超过脚尖。如果酸痛持续超过两三天或者出现刺痛,建议先暂停这个动作。"),
]

MOCK_CHAT_MESSAGE = "我想把深蹲换成别的动作,有什么推荐吗?"

# 模拟一周的体重记录,体重从68kg慢慢降到67.2kg(健康的减重速度),用来测周报
_today = date.today()
MOCK_WEEKLY_WEIGHT_RECORDS = [
    WeightPoint(weightKg=68.0, recordedAt=_today - timedelta(days=6)),
    WeightPoint(weightKg=67.8, recordedAt=_today - timedelta(days=4)),
    WeightPoint(weightKg=67.5, recordedAt=_today - timedelta(days=2)),
    WeightPoint(weightKg=67.2, recordedAt=_today),
]

# 模拟数据不够的情况(只记录了一次),用来测边界情况
MOCK_INSUFFICIENT_WEIGHT_RECORDS = [
    WeightPoint(weightKg=68.0, recordedAt=_today),
]
