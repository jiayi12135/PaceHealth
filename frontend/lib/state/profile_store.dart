import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../models/profile.dart';
import '../services/api_service.dart';

const kWeekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

// 登录状态本地持久化用的key——加这个是因为之前每次hot restart(Dart VM整个重启,不是
// 单纯reload)都会把ProfileStore这些纯内存字段清空,逼用户重新登录一次很烦。
// main.dart启动时会读这两个值,拿着token去验证还有效不有效(打/users/me),
// 有效才真的signIn,无效就照常回登录页,不会拿一个过期token硬当作已登录。
const _kAccessTokenKey = 'ph_access_token';
const _kEmailKey = 'ph_email';
// 问卷里选的经验等级("Beginner"/"Intermediate"/"Intense")+第一次设定目标体重的
// 日期——只在本地存,不经过backend(纯粹给Home页那个"预计几周达到目标"进度条用,
// 不是核心数据,不用跨设备同步)。经验等级本来就只被拼进lifestyle自由文本里,
// 没有结构化字段,所以单独存一份方便直接拿来算。
const _kExperienceKey = 'ph_experience';
const _kGoalStartDateKey = 'ph_goal_start_date';
// "这周已经自动生成过新一轮了"的标记,存这周周一的日期字符串——防止同一周内
// 反复触发生成(比如用户在Plan/Calendar两个页面都触发了onRecorded)。
const _kRoundGeneratedForWeekKey = 'ph_round_generated_for_week';

/// 'Mon'/'Tue'/... 映射到"这一周"(周一到周日,包含reference,默认今天)对应的具体日期。
/// Plan页面的reschedule功能靠这个判断某天是不是已经过去了。
DateTime dateForWeekdayThisWeek(String weekday, {DateTime? reference}) {
  final now = reference ?? DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: today.weekday - 1));
  final index = kWeekdays.indexOf(weekday);
  if (index == -1) return today;
  return monday.add(Duration(days: index));
}

/// 计划一生成完就自动把每个"Day 1/Day 2…"分配到具体星期几,不再单独问用户一遍——
/// 问卷里已经问过"你想哪几天练"(存在store.workoutDays),直接按顺序对上就行。
/// existing(比如重新生成前已经手动调过的分配)优先保留,plan的训练日数量超出
/// 问卷选的天数时,剩下的按kWeekdays顺序兜底填。
Map<String, String> autoAssignWorkoutDays({
  required FitnessPlan plan,
  required List<String> suggestedWeekdays,
  Map<String, String> existing = const {},
}) {
  final planDays = <String>[];
  for (final exercise in plan.exercises) {
    if (!planDays.contains(exercise.day)) planDays.add(exercise.day);
  }
  final assignments = <String, String>{};
  for (var i = 0; i < planDays.length; i++) {
    final planDay = planDays[i];
    assignments[planDay] = existing[planDay] ?? (i < suggestedWeekdays.length ? suggestedWeekdays[i] : kWeekdays[i % 7]);
  }
  return assignments;
}

/// 排定了要练的那天,过去了,却既没点完成、也没按Incomplete——就自动补一条skipped
/// 记录,落在真正错过的那个日期上(不是"现在"),原因写"没有响应"。这样Report的
/// 历史/完成率、AI的adherence note、还有maybeStartNewRound的"这周收工了没"判断,
/// 都不会因为用户单纯没理会某一天就一直看不到那天、或者卡住不往下走。
/// 只回填到昨天为止(今天还没过完不算),最多回看60天,避免plan开了很久之后
/// 突然一次性灌一堆历史记录。应该在maybeStartNewRound之前调用。
Future<void> autoMarkMissedDays(ProfileStore store) async {
  final plan = store.plan;
  if (plan == null) return;
  final planId = plan.planId;
  if (planId == null) return;
  final weekdayToPlanDay = <String, String>{
    for (final entry in store.workoutDayAssignments.entries) entry.value: entry.key,
  };
  if (weekdayToPlanDay.isEmpty) return;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final createdDate = DateTime(plan.createdAt.year, plan.createdAt.month, plan.createdAt.day);
  final earliestAllowed = today.subtract(const Duration(days: 60));
  final start = createdDate.isBefore(earliestAllowed) ? earliestAllowed : createdDate;
  final yesterday = today.subtract(const Duration(days: 1));
  if (start.isAfter(yesterday)) return; // plan今天才建的,还没有"已经过去"的排定日

  final api = ApiService();
  List<WorkoutCompletion> recent;
  try {
    recent = await api.fetchRecentWorkouts(days: (today.difference(start).inDays + 2).clamp(1, 365), accessToken: store.accessToken);
  } catch (_) {
    return;
  }
  // 不分plan/day label,只要那个日期上有任何记录就算"已经处理过了"——跟Calendar
  // 判断"这天有没有记录"用的是同一套逻辑(按日期,不是按plan轮次)。
  final recordedDates = recent.map((w) {
    final d = w.completedAt.toLocal();
    return DateTime(d.year, d.month, d.day);
  }).toSet();

  for (var date = start; !date.isAfter(yesterday); date = date.add(const Duration(days: 1))) {
    final planDay = weekdayToPlanDay[kWeekdays[date.weekday - 1]];
    if (planDay == null || recordedDates.contains(date)) continue;
    try {
      await api.recordWorkout(
        planId: planId,
        day: planDay,
        status: 'skipped',
        reason: 'No response — automatically marked incomplete',
        accessToken: store.accessToken,
        completedAt: DateTime(date.year, date.month, date.day, 12), // 用中午,避免时区换算跨到别的日期
      );
    } catch (_) {
      // 单条补记失败不影响别的日期继续补
    }
  }
}

/// 检查这一周排定的训练日是不是全都已经有记录了(完成或跳过)——如果是,而且这周
/// 还没自动生成过新一轮,就调用/ai/generate-plan生成新一轮计划(backend会自动带上
/// 上一轮的完成情况给AI参考,见后端generate-plan的adherence_note),更新store并
/// 存好day assignments。返回true代表真的生成了新一轮,调用方可以据此提示用户;
/// false代表这周还没收工/已经生成过了/没有plan可续/生成失败。
Future<bool> maybeStartNewRound(ProfileStore store) async {
  final plan = store.plan;
  if (plan == null) return false;
  // 用"排定的训练日label"(Day 1/Day 2…)判断,而不是"具体星期几当天有没有点"——
  // 现实里经常会晚一两天补做(比如周一没空,周二才补),记录的completedAt自然
  // 不会正好落在周一那天,但这仍然算是把这一周的训练日做完了,不该因此永远查不到。
  final planDays = store.workoutDayAssignments.keys.toSet();
  if (planDays.isEmpty) return false;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: today.weekday - 1));
  final sunday = monday.add(const Duration(days: 6));

  final api = ApiService();
  List<WorkoutCompletion> recent;
  try {
    recent = await api.fetchRecentWorkouts(days: 7, accessToken: store.accessToken);
  } catch (_) {
    return false; // 查不到历史就不冒险生成,下次(比如再记一条)会重新检查一遍
  }
  // 这周(周一到周日)范围内,每个排定的训练日都得至少有一条记录(完成或跳过)——
  // 不要求正好卡在分配的那个星期几当天点,这周内任何一天补录/点掉都算数。
  final doneThisWeek = recent.where((w) {
    final d = w.completedAt.toLocal();
    final dateOnly = DateTime(d.year, d.month, d.day);
    return !dateOnly.isBefore(monday) && !dateOnly.isAfter(sunday);
  }).map((w) => w.day).toSet();
  for (final day in planDays) {
    if (!doneThisWeek.contains(day)) return false; // 这周还有训练日没收尾
  }

  // 每周只自动生成一次——用这周周一的日期当key,防止在Plan/Calendar两个页面
  // 都触发onRecorded导致重复生成。
  final weekKey = '${monday.year.toString().padLeft(4, '0')}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getString(_kRoundGeneratedForWeekKey) == weekKey) return false;

  try {
    final newPlan = await api.generatePlan(accessToken: store.accessToken);
    store.setPlan(newPlan);
    // 沿用问卷里选的训练日顺序,新一轮还是排在原来那几个星期几上,只是动作内容
    // 换了一批(backend已经根据上一轮的完成情况调整过)。
    final assignments = autoAssignWorkoutDays(plan: newPlan, suggestedWeekdays: store.workoutDays);
    store.setWorkoutDayAssignments(assignments);
    final planId = newPlan.planId;
    if (planId != null) {
      try {
        await api.saveDayAssignments(planId: planId, assignments: assignments, accessToken: store.accessToken);
      } catch (_) {
        // 存后端失败不拦着——本地状态已经是对的了
      }
    }
    await prefs.setString(_kRoundGeneratedForWeekKey, weekKey);
    return true;
  } catch (_) {
    return false; // 生成失败就算了,没写weekKey进去,下次检查时会重试
  }
}

/// 根据经验等级+每周训练频率,估算一个"安全、有依据"的每周体重变化速率(kg/周)。
/// 参考公开的安全减重区间(常见建议是每周0.5-1kg左右),经验越丰富、练得越勤,
/// 给的速率越接近这个区间上限,但不会超过——不暗示不健康的快速减重。这是一次性的
/// 粗略估算,不是精确预测,纯代码计算(不是AI编的),只给用户一个大概的时间感。
double estimatedWeeklyRateKg({required String experience, required int workoutsPerWeek}) {
  const experienceBonusKg = {'Beginner': 0.0, 'Intermediate': 0.05, 'Intense': 0.1};
  final frequencyBonusKg = 0.05 * (workoutsPerWeek - 1).clamp(0, 6);
  final rate = 0.3 + frequencyBonusKg + (experienceBonusKg[experience] ?? 0.0);
  return rate.clamp(0.3, 0.8);
}

/// 估算达到目标体重大概需要多少周。没有真正要减的体重(维持/增肌/目标体重设反了)
/// 就返回null,调用方应该整个卡片都不显示,不硬凑一个没意义的数字出来。
int? estimatedWeeksToGoal({
  required double startWeightKg,
  required double targetWeightKg,
  required String experience,
  required int workoutsPerWeek,
}) {
  final toLoseKg = startWeightKg - targetWeightKg;
  if (toLoseKg <= 0 || workoutsPerWeek <= 0) return null;
  final rate = estimatedWeeklyRateKg(experience: experience, workoutsPerWeek: workoutsPerWeek);
  return (toLoseKg / rate).ceil();
}

class ProfileStore extends ChangeNotifier {
  UserProfile profile = UserProfile();
  UserPersonalInfo personalInfo = UserPersonalInfo();
  bool completed = false;
  bool signedIn = false;
  String email = '';
  String? accessToken;
  // 问卷完成后自动生成的workout plan,先只存内存里(demo阶段够用)。
  // app重启会丢失——如果以后要跨设备/重启都保留,backend需要加一个GET最新plan的接口。
  FitnessPlan? plan;
  // 用户在问卷里选的训练日(如['Mon','Wed','Fri'],已按周一到周日排序)——只作为
  // 生成完plan后"分配到具体星期几"那一步的默认建议值,不直接用来显示。
  List<String> workoutDays = [];

  // 每次plan生成完,自动把"Day 1/Day 2…"分配到具体星期几(见下面的autoAssignWorkoutDays,
  // 不再单独问用户),存在这里(planDay -> weekday)。用户可以随时在Calendar/Plan页面
  // Reschedule调整。Plan页面显示、以及Report页面对历史记录排序都用这份映射,而不是靠
  // position硬对应。同时也会存一份到backend(见ApiService.saveDayAssignments),
  // 重启/重新登录能恢复。
  Map<String, String> workoutDayAssignments = {};

  // 问卷里选的经验等级+第一次设定目标体重的日期,给Home页"预计几周达到目标"的
  // 进度条用。goalStartDate只在第一次问卷完成时写入,之后编辑资料不会重置它——
  // 这个时间起点要保持稳定,不然进度条每次都从0开始就没意义了。
  String experience = '';
  DateTime? goalStartDate;

  /// 问卷完成时调用一次。goalStartDate已经有值的话不会被覆盖(比如以后重新走一遍
  /// 问卷流程,起点还是第一次设定目标的那天)。
  Future<void> saveGoalMeta({required String experience}) async {
    this.experience = experience;
    goalStartDate ??= DateTime.now();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kExperienceKey, this.experience);
    await prefs.setString(_kGoalStartDateKey, goalStartDate!.toIso8601String());
  }

  /// app启动时读一次本地存的经验等级/目标起点日期,直接赋给store(不走notifyListeners,
  /// 调用方自己决定什么时候一起notify——跟readPersistedSession的用法一致)。
  Future<void> restoreGoalMeta() async {
    final prefs = await SharedPreferences.getInstance();
    experience = prefs.getString(_kExperienceKey) ?? '';
    final dateStr = prefs.getString(_kGoalStartDateKey);
    goalStartDate = dateStr != null ? DateTime.tryParse(dateStr) : null;
  }

  void setWorkoutDayAssignments(Map<String, String> value) {
    workoutDayAssignments = value;
    notifyListeners();
  }

  void signIn(String value, {String? accessToken}) {
    email = value.trim();
    signedIn = true;
    this.accessToken = accessToken;
    notifyListeners();
    _persistSession(); // 写磁盘是异步的,但不影响上面notify的时机,fire-and-forget就行
  }

  void signOut() {
    signedIn = false;
    completed = false;
    email = '';
    accessToken = null;
    profile = UserProfile();
    personalInfo = UserPersonalInfo();
    plan = null;
    workoutDays = [];
    workoutDayAssignments = {};
    experience = '';
    goalStartDate = null;
    notifyListeners();
    _clearPersistedSession();
  }

  Future<void> _persistSession() async {
    if (accessToken == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccessTokenKey, accessToken!);
    await prefs.setString(_kEmailKey, email);
  }

  Future<void> _clearPersistedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccessTokenKey);
    await prefs.remove(_kEmailKey);
    // 经验等级/目标起点日期是SharedPreferences里全局存的(不分账号),换账号登录前
    // 必须清掉,不然新账号会看到上一个账号残留的"预计几周达到目标"起点。
    await prefs.remove(_kExperienceKey);
    await prefs.remove(_kGoalStartDateKey);
  }

  /// app启动(冷启动或hot restart)时调用一次,看看本地有没有存过上次登录的token。
  /// 只是把值读出来,不碰notifyListeners、也不代表登录一定还有效——调用方(main.dart)
  /// 要拿着这个token先打一次/users/me验证过了,才能真的当作已登录处理。
  static Future<({String email, String accessToken})?> readPersistedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kAccessTokenKey);
    if (token == null || token.isEmpty) return null;
    return (email: prefs.getString(_kEmailKey) ?? '', accessToken: token);
  }

  void setPlan(FitnessPlan? value) {
    plan = value;
    // 如果这份plan自带day assignments(比如从backend读回来的、之前分配过的老plan),
    // 顺手把它也同步进来——不然Home的calendar/streak这些靠workoutDayAssignments
    // 算的东西会看起来"这份plan哪天都没排"。刚生成、还没分配过的plan这里是空map,
    // 不会覆盖掉已经有的本地分配。
    if (value != null && value.dayAssignments.isNotEmpty) {
      workoutDayAssignments = value.dayAssignments;
    }
    notifyListeners();
  }

  void save({required UserProfile profile, required UserPersonalInfo personalInfo}) {
    this.profile = profile;
    this.personalInfo = personalInfo;
    // personalInfo.workoutWeekdays是持久化过backend的那份真相;workoutDays只是
    // 内存里给"分配到具体星期几"这一步用的建议值副本,每次save/hydrate都从前者
    // 同步回来,这样重启后(hydrate从backend读回)workoutDays不会是空的。
    if (personalInfo.workoutWeekdays.isNotEmpty) {
      workoutDays = personalInfo.workoutWeekdays;
    }
    completed = true;
    notifyListeners();
  }

  /// 登录后如果backend已经有这个用户的资料,直接用它填充store并跳过问卷——
  /// 跟save()逻辑一样,单独起个名字只是为了在调用处更清楚这是"从backend读回来的",不是用户刚填的。
  void hydrate({required UserProfile profile, required UserPersonalInfo personalInfo}) {
    save(profile: profile, personalInfo: personalInfo);
  }
}
