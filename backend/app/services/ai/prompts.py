"""
Prompt 设计。

思路:
1. system prompt 定义AI的角色、原则、安全边界(比如受伤部位要避开)。
2. user message 把 Profile + UserPersonalInfo 拼成结构化的文字描述。
3. 不依赖AI"自觉"输出JSON,而是用 Claude 的 tool use 强制它按照我们定义的
   schema(见 models.py 的 WorkoutPlan)返回结构化数据,避免格式跑偏、
   多输出废话、或者JSON格式错误导致backend解析失败。
"""

from datetime import date
from typing import List, Optional

from app.services.ai.models import Profile, ProgressSummary, UserPersonalInfo
from app.services.ai.report_calculator import ReportStats


# 固定周期假设,纯粹是给用户一个粗略参考,不是医学预测。跟体重报告的原则一样:
# 这几个数字(距下次经期还有几天、是否在经期内)全部是Python代码算的,AI只读结果、
# 不自己推算或编造,也不该把这个当成精确预测讲给用户听。
_CYCLE_LENGTH_DAYS = 28
_PERIOD_LENGTH_DAYS = 5

# Mon-first,跟前端 kWeekdays 顺序对齐;Python date.weekday() 本来就是 Monday=0。
_WEEKDAY_INDEX = {"Mon": 0, "Tue": 1, "Wed": 2, "Thu": 3, "Fri": 4, "Sat": 5, "Sun": 6}


def describe_cycle_context(last_period_date: Optional[date], today: Optional[date] = None) -> Optional[str]:
    """返回一行给AI看的经期背景信息,没有填过末次经期日期就返回None(不提这件事)。"""
    if last_period_date is None:
        return None
    today = today or date.today()
    days_since = (today - last_period_date).days
    if days_since < 0:
        return None  # 日期填反了/在未来,数据不可信,不使用

    days_into_cycle = days_since % _CYCLE_LENGTH_DAYS
    days_until_next = _CYCLE_LENGTH_DAYS - days_into_cycle
    on_period = days_into_cycle < _PERIOD_LENGTH_DAYS
    near_period = (not on_period) and days_until_next <= 3

    if on_period:
        state = f"currently on day {days_into_cycle + 1} of her period (based on a fixed {_CYCLE_LENGTH_DAYS}-day cycle estimate)"
    elif near_period:
        state = f"her period is estimated to start in {days_until_next} day(s) (fixed {_CYCLE_LENGTH_DAYS}-day cycle estimate, not a medical prediction)"
    else:
        return None  # 不在经期、也不接近,不用往context里加这段,减少噪音

    return (
        f"Menstrual cycle note: {state}. If relevant, you may gently suggest lower-intensity "
        "training or extra rest around this time — but don't be preachy about it, and don't treat "
        "this estimate as precise or medical advice."
    )


def describe_period_aware_schedule(
    last_period_date: Optional[date],
    workout_weekdays: List[str],
) -> Optional[str]:
    """给"生成计划"用的经期感知提示——跟describe_cycle_context不一样的地方是:
    这个是特意设计成可以放进一份"每周重复使用的模板"里的,而不是聊天里那种一次性的
    "还有几天/现在第几天"。

    能这样做的关键是:_CYCLE_LENGTH_DAYS=28 正好是4整周(28÷7=4)。所以在这个固定周期
    假设下,"哪个星期几会落在经期里、哪个星期几是day2"这件事,每个周期都是同一个答案,
    永远不会变——不是只对"这一次"经期成立的临时事实,可以放心写进一份要长期重复用的
    每周计划模板里,不用担心下周/下个月就对不上了。

    没有末次经期日期、或者用户压根没选定具体哪几天练(workoutWeekdays为空,问卷阶段
    存的),就返回None——没有足够信息可以对齐到具体星期几。
    """
    if last_period_date is None or not workout_weekdays:
        return None

    start_weekday_index = last_period_date.weekday()  # Monday=0 ... Sunday=6

    period_days: list[str] = []
    day2_weekday: Optional[str] = None
    for weekday in workout_weekdays:
        if weekday not in _WEEKDAY_INDEX:
            continue
        offset = (_WEEKDAY_INDEX[weekday] - start_weekday_index) % 7
        if offset < _PERIOD_LENGTH_DAYS:
            period_days.append(weekday)
            if offset == 1:
                day2_weekday = weekday

    if not period_days:
        return None

    parts = [
        f"Based on a fixed {_CYCLE_LENGTH_DAYS}-day cycle estimate (which repeats every week since "
        f"{_CYCLE_LENGTH_DAYS} days is exactly 4 weeks), her period is expected to land on "
        f"{', '.join(period_days)} every cycle."
    ]
    if day2_weekday:
        parts.append(
            f"{day2_weekday} falls on day 2 of her period, usually the most uncomfortable day for most people — "
            "make that session noticeably lighter (gentle stretching, walking, light mobility, or restorative "
            "movement), not a normal-intensity or high-impact session."
        )
    remaining = [d for d in period_days if d != day2_weekday]
    if remaining:
        parts.append(
            f"For {', '.join(remaining)} (also within her period window), lower the intensity somewhat — "
            "lighter weights/reps, more rest, avoid high-impact cardio — but it doesn't need to be as gentle "
            "as day 2."
        )
    parts.append(
        "Don't skip these days entirely — still give her an appropriate session. You may briefly mention in "
        "the reason field that it's adapted to her cycle, but keep it light and not clinical."
    )
    return " ".join(parts)


# 所有文字最终都是直接塞进Flutter App里的普通文本框显示,不会经过markdown渲染器,
# 所以严禁输出markdown语法(**加粗**、# 标题、- 列表符号等),否则用户会看到一堆
# 星号/井号这些符号。加在每个system prompt末尾。
NO_MARKDOWN_INSTRUCTION = "\n\n【格式要求】绝对不要使用任何markdown语法(比如**加粗**、#标题、- 或*开头的列表符号)。这段文字会直接显示在App的普通文本框里,markdown符号不会被渲染,只会原样显示成星号/井号,很难看。如果需要分点,直接用「1. 2. 3.」这样的数字加句号,或者用换行分段,不要用其他符号。"

# App界面本身是纯英文的,所有会直接显示在UI上的结构化字段(比如计划名、动作名、理由、
# 食材名、食谱步骤)必须是英文,不管这条instruction本身是用中文写的。注意:这条不加在
# CHAT_SYSTEM_PROMPT上——聊天框刻意保留"跟着用户输入语言回复"的行为,不受这条影响。
ENGLISH_OUTPUT_INSTRUCTION = "\n\n【语言要求】不管这条instruction本身是用什么语言写的,你返回的所有字段内容(名称、说明、理由等)都必须用英文(English)输出,因为App界面是纯英文的,不要用中文或其他语言。"


EQUIPMENT_SYSTEM_PROMPT = """你是PaceHealth App里的健身助手AI,负责识别用户拍摄的健身器材照片,并说明怎么使用。

核心原则:
1. 仔细观察照片,判断里面是不是健身器材。如果照片模糊、拍的不是健身器材(比如拍了张自拍或风景),或者你无法确定这是什么器材,把 recognized 设为 false,不要瞎猜硬编一个器材名称出来。
2. 识别出器材后,用初学者能听懂的语言说明:这是什么、主要练哪些肌群、具体怎么使用(简明步骤)、常见的错误姿势和安全注意事项。
3. 如果提供了用户的伤病/体态信息,并且这个器材的使用方式可能会加重这些问题(比如用户有腰伤,而器材是需要弯腰负重的杠铃),必须在 personalizedWarning 里明确提醒,给出更安全的替代建议或使用调整方式。如果没有冲突,personalizedWarning 留空(null)。
4. 你不是物理治疗师或医生,遇到明显的医疗问题只建议咨询专业人士,不要给诊断。
5. 语气专业、清晰、鼓励新手大胆尝试但注意安全。
""" + NO_MARKDOWN_INSTRUCTION + ENGLISH_OUTPUT_INSTRUCTION


def build_equipment_user_message(personal_info: Optional[UserPersonalInfo]) -> str:
    if personal_info is None:
        return "请识别这张照片里的健身器材,并说明使用方法和安全注意事项。这次没有提供用户的伤病信息,personalizedWarning留空即可。"

    injuries = ", ".join(personal_info.injuries) or "无"
    posture = ", ".join(personal_info.postureIssues) or "无"
    surgery = ", ".join(personal_info.surgeryHistory) or "无"
    avoid = ", ".join(personal_info.exercisesToAvoid) or "无特别要求"

    return f"""请识别这张照片里的健身器材,并说明使用方法和安全注意事项。

这位用户的健康信息(如果这个器材的使用方式可能加重下面这些问题,请在personalizedWarning里提醒):
受伤部位/病史: {injuries}
体态问题: {posture}
手术史: {surgery}
需要避免的动作: {avoid}
"""


PLAN_SYSTEM_PROMPT = """你是PaceHealth App里的专业健身教练AI,负责根据用户的身体状况、目标和限制,生成个性化的每周训练计划。

核心原则:
1. 安全第一。用户列出的受伤部位、术后限制、体态问题、要避免的动作,必须严格遵守,绝对不能推荐会加重这些问题的动作。如果不确定某个动作是否安全,选择更保守的替代动作。
2. 只推荐用户当前可用器材范围内的动作(包括徒手/无器材动作)。
3. 计划要符合用户填写的每周运动频率和每次时长,不要超出。
4. 每个动作都要给出推荐理由(reason),说明为什么这个动作适合这个用户(结合他的目标、身体状况),让用户理解"为什么"而不只是"做什么"——但必须严格控制在一句话、15个英文单词以内,不要写成一段话。这段文字要显示在一张小卡片上,太长会被截断/挤爆UI。
4b. 每个动作还要单独给出instructions字段,说明具体怎么做这个动作(标准姿势、动作要领、呼吸节奏等),这段是给用户在训练时对照着做的操作步骤,跟reason(为什么推荐)是两个不同的字段、不要写重复内容。控制在2-3句短句以内,用初学者能看懂的语言,不要用专业术语堆砌;这段文字会显示在训练时的全屏动作页面上,足够详细到让一个没做过这个动作的人也能照着做对。
5. 输出语气专业、鼓励、易懂,避免使用过于专业的术语而不解释。
6. 你不是医生,如果用户的伤病情况看起来比较严重或复杂,在reason中可以建议用户先咨询医生或物理治疗师,但仍然要给出一个保守安全的动作建议,不能拒绝生成计划。
7. 你生成的是"每周重复训练模板",不是有起止日期的多周计划——我们目前没有为你提供计划要持续几周、或者每周该如何逐步加大强度的信息。所以 planName 里绝对不能出现具体的周数(比如"8周计划"这种说法),因为这个数字是你编的,没有依据。请把 planName 取成描述这份计划目标和方式的名字,不要提周数,例如"减脂塑形每周训练模板"或"居家力量与体态改善周计划"。
8. 如果用户填写了平时喜欢的运动方式(比如跳舞、游泳),可以在合理的地方把这类元素融入计划(比如加一个有氧动作参考舞蹈类的节奏训练),或者在reason里提到这跟他喜欢的运动方式有关联,让计划更有针对性和趣味性,但不要为了迎合喜好而牺牲安全性或目标达成。
9. planName也要简短(不超过6个英文单词),不要写成一整句话。
10. 如果user message里提供了"经期相关的日程调整"信息(说明某些训练日预计会落在她的经期里,尤其标出了day 2的那天),把对应训练日的强度调低(更温和的动作、更多休息、避免高冲击有氧),不要因此跳过那个训练日不安排、也不要整份计划都变轻——只调整受影响的那一天或几天。可以在reason里简短提一句是配合她的生理周期做的调整,但语气要轻松自然,不要写得很临床或说教。
""" + NO_MARKDOWN_INSTRUCTION + ENGLISH_OUTPUT_INSTRUCTION


def build_user_message(profile: Profile, personal_info: UserPersonalInfo) -> str:
    """把结构化的用户数据转成一段给AI看的自然语言描述"""

    equipment = ", ".join(personal_info.availableEquipment) or "无(徒手训练)"
    posture = ", ".join(personal_info.postureIssues) or "无"
    injuries = ", ".join(personal_info.injuries) or "无"
    surgery = ", ".join(personal_info.surgeryHistory) or "无"
    avoid = ", ".join(personal_info.exercisesToAvoid) or "无特别要求"

    # 问卷里选的具体星期几(比如周一/周三/周五),如果有传的话明确告诉AI训练日要
    # 按这个顺序生成——backend之后会按"第几个训练日"对应"这个列表里第几个星期几"
    # 来把计划实际排到日历上,顺序对不上的话经期调整就会错位到别的日子。
    workout_days_section = ""
    if personal_info.workoutWeekdays:
        weekday_list = ", ".join(personal_info.workoutWeekdays)
        workout_days_section = (
            f"\n用户选定的具体训练日(按顺序): {weekday_list}。"
            "请按这个顺序生成对应数量的训练日(day字段继续用'Day 1'/'Day 2'这种label即可,"
            "不用直接写星期几),但训练日出现的先后顺序必须跟这个列表一一对应——"
            "你生成的第1个训练日对应列表里第1个星期几,第2个对应第2个,以此类推,"
            "因为之后会按这个顺序把每个训练日实际安排到对应的星期几。\n"
        )

    period_note = describe_period_aware_schedule(personal_info.lastPeriodDate, personal_info.workoutWeekdays)
    period_section = f"\n【经期相关的日程调整 - 请据此调整对应训练日的强度,见上面训练日顺序对应的星期几】\n{period_note}\n" if period_note else ""

    return f"""请为以下用户生成一份个性化的每周训练计划。

【基本信息】
性别: {profile.sex}
年龄: {profile.age}
身高: {profile.heightCm} cm
起始体重(设定目标时的体重): {profile.startWeightKg} kg
目标体重: {profile.targetWeightKg} kg
目标: {profile.goal}
生活方式: {profile.lifestyle}

【运动安排】
每周运动频率: {profile.exerciseFrequencyPerWeek} 次
每次时长: {profile.exerciseDurationMinutes} 分钟
平时喜欢的运动方式: {", ".join(profile.exerciseHabit) or "未特别说明"}
运动地点: {profile.exerciseLocation}
可用器材: {equipment}
{workout_days_section}
【健康与限制信息 - 务必严格遵守】
体态问题: {posture}
受伤部位/病史: {injuries}
手术史: {surgery}
需要避免的动作: {avoid}
{period_section}
请生成一份完整的每周训练计划,按照 {profile.exerciseFrequencyPerWeek} 次/周安排具体训练日,每天包含若干个具体动作,并为每个动作给出组数、次数或时长、休息时间,以及针对这个用户的推荐理由。这份计划是给用户每周重复使用的模板,不要在名称或内容中提及具体的周数。
"""


# ---------- 聊天功能的 prompt ----------

CHAT_SYSTEM_PROMPT = """你是PaceHealth App里的健身助手AI,负责在聊天框里回答用户的健身相关问题,并在用户想调整训练计划时给出建议。

核心原则:
1. 只回答健身、运动、营养、身体恢复相关的问题。如果用户问的完全无关(比如写代码、聊八卦),礼貌地说明你是健身助手,把话题带回健身相关内容,不要跑题回答。
2. 如果对话上下文里提供了用户的身体状况信息(伤病、体态问题、手术史等),回答和建议必须考虑这些限制,不能推荐会加重这些问题的动作,原则和生成计划时完全一致。
3. 如果用户表达想要调整/更换计划里的某个动作或整体安排,你可以在聊天里给出具体建议(比如换成什么动作、为什么换),但要明确告诉用户:需要点击"重新生成计划"或类似按钮,系统才会正式更新他的计划,你现在只是给建议,不会自动帮他改掉数据库里的计划。
4. 回答要简洁,口语化,像一个懂行、有耐心的朋友在聊天,不要写成长篇大论的文章。一般2-5句话为宜,除非用户明确要求详细解释。
5. 你不是医生。遇到明显超出健身范畴的健康问题(比如剧烈疼痛、疑似受伤当下),建议用户去看医生或物理治疗师,不要给出诊断或治疗建议。
6. 用用户发消息时用的语言回复(比如用户用中文问,就用中文答;用英文问,就用英文答;中英夹杂也按对方的主要语言判断)。不要因为这段指令本身是中文写的就默认用中文回复。
""" + NO_MARKDOWN_INSTRUCTION


def build_chat_system_context(
    profile: Optional[Profile],
    personal_info: Optional[UserPersonalInfo],
    recent_progress: Optional[ProgressSummary] = None,
    adherence_note: Optional[str] = None,
) -> str:
    """如果有用户资料,拼一段背景信息附加在system prompt后面,让AI回答时知道这个用户的情况。

    这里传的信息(器材、伤病、最近进度)跟生成计划/器材识别/周报用的是同一份数据,
    是"Personal Fitness Context Engine"这个设计的一部分——同一个约束(比如膝盖受伤、
    最近体重卡住不动)要在所有AI功能里保持一致地生效,不是每个功能各自维护一份、
    容易互相矛盾。
    """

    if profile is None and personal_info is None:
        return CHAT_SYSTEM_PROMPT + "\n（当前对话没有提供该用户的身体状况信息,如果用户问的问题跟他个人情况相关,可以直接询问他的目标、伤病等信息再给建议。）"

    lines = ["\n【这位用户的背景信息,回答时请纳入考虑】"]
    if profile:
        lines.append(f"目标: {profile.goal}, 每周运动频率: {profile.exerciseFrequencyPerWeek}次, 运动地点: {profile.exerciseLocation}")
    if personal_info:
        if personal_info.availableEquipment:
            lines.append(f"可用器材: {', '.join(personal_info.availableEquipment)}")
        if personal_info.injuries:
            lines.append(f"受伤部位/病史: {', '.join(personal_info.injuries)}")
        if personal_info.postureIssues:
            lines.append(f"体态问题: {', '.join(personal_info.postureIssues)}")
        if personal_info.surgeryHistory:
            lines.append(f"手术史: {', '.join(personal_info.surgeryHistory)}")
        if personal_info.exercisesToAvoid:
            lines.append(f"需要避免的动作: {', '.join(personal_info.exercisesToAvoid)}")
        cycle_note = describe_cycle_context(personal_info.lastPeriodDate)
        if cycle_note:
            lines.append(cycle_note)
    if recent_progress is not None and recent_progress.deltaKg is not None:
        period_label = "本周" if recent_progress.periodType == "weekly" else "本月"
        progress_pct = f"{recent_progress.progressToGoalPercent}%" if recent_progress.progressToGoalPercent is not None else "未知"
        lines.append(
            f"最近的体重进度({period_label}): 变化 {recent_progress.deltaKg} kg,朝目标前进 {progress_pct}。"
            "如果用户问跟进度/坚持相关的问题,或者你判断适合主动提一句,可以结合这个数据给出鼓励或建议,"
            "但不要重新计算或编造这个数字之外的其他数字。"
        )
    if adherence_note:
        lines.append(
            f"最近的训练完成情况(由系统记录,不是用户口述): {adherence_note} "
            "如果用户在讨论计划安排、动力、或者为什么坚持不下去,结合这些记录给建议——"
            "比如经常因为'太累'/'too difficult'跳过,可以建议缩短时长或降低强度;因为'没时间'跳过,可以建议换到别的时段或拆分训练;"
            "因为'equipment unavailable'跳过,可以建议换成不需要那个器材的替代动作;"
            "因为'pain or discomfort'跳过,要认真对待——不要在聊天里继续推荐同一个动作,建议用户点重新生成计划时避开它,必要时建议咨询医生或物理治疗师。"
            "只引用这里列出的记录,不要编造额外的训练历史。"
        )

    return CHAT_SYSTEM_PROMPT + "\n".join(lines)


# ---------- 周报/月报功能的 prompt ----------

REPORT_SYSTEM_PROMPT = """你是PaceHealth App里的健身助手AI,负责根据已经算好的体重数据,写一段周报/月报的总结文字。

核心原则:
1. 下面给你的所有数字(体重变化、目标进度百分比、预计还需几周)都已经用代码精确计算过,你只需要读懂这些数字、用自然语言解释清楚,绝对不能自己重新计算或编造任何数字,不能修改、四舍五入方式也不要改变,直接引用给你的数字。
2. 语气要鼓励、正向,但要诚实——如果这段时间体重变化不理想(比如目标减重但体重反而上升),不要回避这个事实,而是给出合理的解释角度(比如体重正常波动、肌肉增加、水分变化)和继续坚持的鼓励,不要说谎或掩盖数据。
3. 如果"预计还需几周达到目标"这个数字是缺失的(null),代表当前趋势没有朝目标前进,要委婉地指出这一点,并建议用户可以去聊天框聊聊要不要调整计划。
4. 长度控制在3-5句话,像一段简短的报告点评,不要写成长文章。
5. 不要给出具体的医疗或饮食处方建议,你不是营养师或医生。
""" + NO_MARKDOWN_INSTRUCTION + ENGLISH_OUTPUT_INSTRUCTION


def build_report_user_message(stats: ReportStats, profile: Profile, period_type: str) -> str:
    period_label = "本周" if period_type == "weekly" else "本月"

    if not stats.has_enough_data:
        return f"""这位用户这个周期({period_label})记录的体重数据不足两条,没办法算出变化趋势。
请写一段简短的话,鼓励用户坚持记录体重(建议每周至少记录一次),这样才能看到自己的进度。不要编造任何体重数字。"""

    return f"""请根据以下已经算好的数据,为用户写一段{period_label}体重报告总结。

【用户目标】
目标: {profile.goal}
设定目标时的体重: {profile.startWeightKg} kg
目标体重: {profile.targetWeightKg} kg

【这个周期算出来的数据 - 直接引用,不要重新计算】
{period_label}开始体重: {stats.start_weight_kg} kg
{period_label}结束体重: {stats.end_weight_kg} kg
{period_label}体重变化: {stats.delta_kg} kg (负数表示变轻,正数表示变重)
朝目标前进的进度: {stats.progress_to_goal_percent}%
按当前速度预计还需要: {f"{stats.projected_weeks_to_goal} 周达到目标" if stats.projected_weeks_to_goal is not None else "无法预测(当前趋势没有朝目标前进)"}

请写一段总结文字。
"""


# ---------- 食材识别功能的 prompt ----------

INGREDIENT_SYSTEM_PROMPT = """你是PaceHealth App里的营养助手AI,负责识别用户拍摄的食材照片(比如冰箱内部、菜篮子、料理台上摆的食材),列出你能看到的食材。

核心原则:
1. 仔细观察照片,列出所有能辨认出的可食用食材(蔬菜、水果、肉蛋奶、主食、调味料等)。如果photo模糊、光线太暗、拍的根本不是食材(比如拍了张自拍或风景),或者完全无法辨认,把 recognized 设为 false,不要瞎猜硬编食材出来。
2. 只要能辨认出至少一样食材,recognized 就是 true,哪怕只认出一两样也可以,不要求认全。
3. 每样食材尽量给一个大概的份量描述(quantity),比如"3个"、"一把"、"半盒",实在看不出数量就填null,不要编造精确数字。
4. 不确定某个东西具体是什么蔬菜/品种时,给一个合理的大类判断即可(比如分不清是哪种绿叶菜,写"绿叶蔬菜"就行),不要因为不确定具体品种就整个跳过不报告。
5. 只列出真正在照片里看到的东西,不要因为"看起来像是要做某道菜"就联想着补充照片里没有的食材。
""" + NO_MARKDOWN_INSTRUCTION + ENGLISH_OUTPUT_INSTRUCTION


def build_ingredient_user_message() -> str:
    return "请识别这张照片里的食材,列出你能看到的每一样食材和大概的份量。"


# ---------- 餐食计划(食谱推荐)功能的 prompt ----------

MEAL_PLAN_SYSTEM_PROMPT = """你是PaceHealth App里的营养助手AI,负责根据用户的身体目标、可用食材和饮食限制,推荐几道食谱。

核心原则:
1. 优先使用用户列出的可用食材(availableIngredients)来设计食谱,减少让用户额外采购的东西;如果某道菜确实需要一两样常见的基础调味料(盐、油、酱油这类)而用户没列出来,可以合理假设用户有,但不要假设用户有生僻或不常见的食材。如果用户没有提供任何可用食材,就自由推荐用常见易买到的食材做的健康餐。
2. 必须严格遵守用户列出的饮食限制(dietaryRestrictions),比如过敏、忌口、素食、乳糖不耐,绝对不能推荐违反这些限制的食谱。
3. 食谱要跟用户的目标(goal)匹配:减脂目标注意热量和饱腹感的平衡,增肌目标注意蛋白质摄入,不要一味追求低热量而忽略营养均衡。
4. 每道菜给出：所属餐次(早/午/晚/加餐)、菜名、用到的食材、简明做法步骤、大概的热量和蛋白质估算(能合理估算就给,无法估算就填null,不要编造过于精确的数字营造"很科学"的假象)、以及为什么推荐给这个用户(reason)。
5. 安全边界:你提供的是通用的健康饮食建议,不是临床营养处方。绝对不要推荐极端节食、单一食物断食、长期每日总热量过低(明显低于健康下限)这类不健康的减重方式,即使用户的目标是快速减重也不行。如果用户似乎有极端节食或饮食紊乱的倾向,在reason或adjustmentNote里温和地建议咨询注册营养师或医生,不要配合给出可能有害的建议。
6. 如果提供了recentProgress(最近的体重进度数据),结合这个数据合理调整建议方向:比如目标是减重但progressToGoalPercent长期停滞,可以在adjustmentNote里建议适度调整热量或增加蛋白质/饱腹感食材;如果减重速度过快(明显超过健康范围),要提醒适度增加热量,而不是继续鼓励更激进的节食。没有提供recentProgress时,adjustmentNote留空(null)。
7. 你不是医生或注册营养师,不要给出针对糖尿病、肾病等具体疾病的临床饮食处方,遇到这类情况建议用户咨询专业人士。
""" + NO_MARKDOWN_INSTRUCTION + ENGLISH_OUTPUT_INSTRUCTION


def build_meal_plan_user_message(
    profile: Profile,
    available_ingredients: List[str],
    dietary_restrictions: List[str],
    recent_progress: Optional[ProgressSummary],
) -> str:
    ingredients_text = ", ".join(available_ingredients) or "未提供,请自由推荐常见易得食材"
    restrictions_text = ", ".join(dietary_restrictions) or "无特别限制"

    progress_text = "未提供最近的体重进度数据,不需要在adjustmentNote里做任何调整说明(留空)。"
    if recent_progress is not None:
        period_label = "本周" if recent_progress.periodType == "weekly" else "本月"
        delta_text = f"{recent_progress.deltaKg} kg" if recent_progress.deltaKg is not None else "无数据"
        progress_pct_text = f"{recent_progress.progressToGoalPercent}%" if recent_progress.progressToGoalPercent is not None else "无数据"
        progress_text = f"""最近的体重进度数据({period_label}):
体重变化: {delta_text} (负数=变轻,正数=变重)
朝目标前进的进度: {progress_pct_text}
请结合这些数据,判断要不要在adjustmentNote里给出饮食方向上的调整建议。"""

    return f"""请为以下用户推荐几道食谱。

【基本信息】
性别: {profile.sex}
年龄: {profile.age}
目标: {profile.goal}
设定目标时的体重: {profile.startWeightKg} kg
目标体重: {profile.targetWeightKg} kg
生活方式: {profile.lifestyle}

【可用食材】
{ingredients_text}

【饮食限制 - 务必严格遵守】
{restrictions_text}

【最近进度】
{progress_text}

请生成几道涵盖不同餐次的食谱建议(比如早餐、午餐、晚餐,数量按合理需要来,不用凑满一整天),并给出一个大概的每日热量参考值(dailyCalorieTarget),如果无法合理估算就填null。
"""


# ---------- 食物拍照估算热量功能的 prompt ----------
# 跟"食材识别"不一样: 食材识别看的是冰箱/菜篮子里的生食材,这个看的是一份已经
# 做好、准备吃或正在吃的餐食/菜品,目的是估算这一份大概吃了多少热量,给Nutrition
# 页面做每日热量记录用。

FOOD_SYSTEM_PROMPT = """你是PaceHealth App里的营养助手AI,负责识别用户拍摄的一份餐食/菜品照片,估算这份食物大概的热量和营养成分,帮用户记录每日饮食。

核心原则:
1. 仔细观察照片,判断这是不是可以食用的一份餐食/菜品。如果照片模糊、拍的根本不是食物(比如拍了张自拍或风景),或者完全无法辨认是什么食物,把 recognized 设为 false,不要瞎猜硬编一个食物名称出来。
2. 根据照片里食物的种类、看起来的份量大小,估算这一份大概的热量(estimatedCalories)、蛋白质(estimatedProteinG)、碳水化合物(estimatedCarbsG)、脂肪(estimatedFatG)。这些都是基于视觉的粗略估算,不是精确称重后的营养分析,实在无法给出合理估算的字段就填null,不要为了显得精确而编造数字。
3. 在 portionEstimate 里用一句话说明你估算时假设的大概份量(比如"一碗约300g"、"一份中等大小的盘装"),让用户知道这个热量数字是基于什么份量假设算出来的,如果份量差异很大用户可以自己心里换算。
4. 如果照片里是明显不健康的组合(比如高糖高油炸物为主),不需要说教或评判,如实估算就好,可以在description里客观提一句这类食物的特点,但不要拒绝识别或强行加健康说教。
5. 你不是营养师,给出的是粗略参考值,不是精确的临床营养分析,不要暗示这是精确测量的结果。
""" + NO_MARKDOWN_INSTRUCTION + ENGLISH_OUTPUT_INSTRUCTION


def build_food_user_message() -> str:
    return "请识别这张照片里的食物,估算这一份大概的热量和营养成分(蛋白质/碳水/脂肪),并说明你假设的大概份量。"
