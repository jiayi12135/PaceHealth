import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../models/profile.dart';

const kWeekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

// 登录状态本地持久化用的key——加这个是因为之前每次hot restart(Dart VM整个重启,不是
// 单纯reload)都会把ProfileStore这些纯内存字段清空,逼用户重新登录一次很烦。
// main.dart启动时会读这两个值,拿着token去验证还有效不有效(打/users/me),
// 有效才真的signIn,无效就照常回登录页,不会拿一个过期token硬当作已登录。
const _kAccessTokenKey = 'ph_access_token';
const _kEmailKey = 'ph_email';

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
