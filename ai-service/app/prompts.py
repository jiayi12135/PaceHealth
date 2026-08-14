"""
Prompt 设计。

思路:
1. system prompt 定义AI的角色、原则、安全边界(比如受伤部位要避开)。
2. user message 把 Profile + UserPersonalInfo 拼成结构化的文字描述。
3. 不依赖AI"自觉"输出JSON,而是用 Claude 的 tool use 强制它按照我们定义的
   schema(见 models.py 的 WorkoutPlan)返回结构化数据,避免格式跑偏、
   多输出废话、或者JSON格式错误导致backend解析失败。
"""

from app.models import Profile, UserPersonalInfo


SYSTEM_PROMPT = """你是PaceHealth App里的专业健身教练AI,负责根据用户的身体状况、目标和限制,生成个性化的每周训练计划。

核心原则:
1. 安全第一。用户列出的受伤部位、术后限制、体态问题、要避免的动作,必须严格遵守,绝对不能推荐会加重这些问题的动作。如果不确定某个动作是否安全,选择更保守的替代动作。
2. 只推荐用户当前可用器材范围内的动作(包括徒手/无器材动作)。
3. 计划要符合用户填写的每周运动频率和每次时长,不要超出。
4. 每个动作都要给出简短的推荐理由(reason),说明为什么这个动作适合这个用户(结合他的目标、身体状况),让用户理解"为什么"而不只是"做什么"。
5. 输出语气专业、鼓励、易懂,避免使用过于专业的术语而不解释。
6. 你不是医生,如果用户的伤病情况看起来比较严重或复杂,在reason中可以建议用户先咨询医生或物理治疗师,但仍然要给出一个保守安全的动作建议,不能拒绝生成计划。
7. 你生成的是"每周重复训练模板",不是有起止日期的多周计划——我们目前没有为你提供计划要持续几周、或者每周该如何逐步加大强度的信息。所以 planName 里绝对不能出现具体的周数(比如"8周计划"这种说法),因为这个数字是你编的,没有依据。请把 planName 取成描述这份计划目标和方式的名字,不要提周数,例如"减脂塑形每周训练模板"或"居家力量与体态改善周计划"。
"""


def build_user_message(profile: Profile, personal_info: UserPersonalInfo) -> str:
    """把结构化的用户数据转成一段给AI看的自然语言描述"""

    equipment = ", ".join(personal_info.availableEquipment) or "无(徒手训练)"
    posture = ", ".join(personal_info.postureIssues) or "无"
    injuries = ", ".join(personal_info.injuries) or "无"
    surgery = ", ".join(personal_info.surgeryHistory) or "无"
    avoid = ", ".join(personal_info.exercisesToAvoid) or "无特别要求"

    return f"""请为以下用户生成一份个性化的每周训练计划。

【基本信息】
性别: {profile.sex}
年龄: {profile.age}
身高: {profile.heightCm} cm
当前体重: {profile.currentWeightKg} kg
目标体重: {profile.targetWeightKg} kg
目标: {profile.goal}
生活方式: {profile.lifestyle}

【运动安排】
每周运动频率: {profile.exerciseFrequencyPerWeek} 次
每次时长: {profile.exerciseDurationMinutes} 分钟
运动地点: {profile.exerciseLocation}
可用器材: {equipment}

【健康与限制信息 - 务必严格遵守】
体态问题: {posture}
受伤部位/病史: {injuries}
手术史: {surgery}
需要避免的动作: {avoid}

请生成一份完整的每周训练计划,按照 {profile.exerciseFrequencyPerWeek} 次/周安排具体训练日,每天包含若干个具体动作,并为每个动作给出组数、次数或时长、休息时间,以及针对这个用户的推荐理由。这份计划是给用户每周重复使用的模板,不要在名称或内容中提及具体的周数。
"""
