"""测试用的假数据,不消耗真实用户信息"""

from app.models import Profile, UserPersonalInfo

MOCK_PROFILE = Profile(
    name="Test User",
    age=28,
    sex="female",
    heightCm=165,
    currentWeightKg=68,
    targetWeightKg=60,
    goal="lose_weight",
    lifestyle="sedentary desk job, sits 8+ hours a day",
    exerciseFrequencyPerWeek=3,
    exerciseDurationMinutes=45,
    exerciseLocation="home",
)

MOCK_PERSONAL_INFO = UserPersonalInfo(
    availableEquipment=["dumbbells", "yoga mat", "resistance bands"],
    postureIssues=["forward head posture", "rounded shoulders"],
    injuries=["mild lower back pain"],
    surgeryHistory=[],
    exercisesToAvoid=["heavy deadlifts", "high-impact jumping"],
)
