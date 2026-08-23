import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../models/profile.dart';

const kWeekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

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

  // 每次plan生成完,用户在AssignWorkoutDaysScreen里把"Day 1/Day 2…"具体分配到哪个
  // 星期几,存在这里(planDay -> weekday)。Plan页面显示、以及Report页面对历史记录
  // 排序都用这份映射,而不是靠position硬对应。仅本地。
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
  }

  void setPlan(FitnessPlan? value) {
    plan = value;
    notifyListeners();
  }

  void save({required UserProfile profile, required UserPersonalInfo personalInfo}) {
    this.profile = profile;
    this.personalInfo = personalInfo;
    completed = true;
    notifyListeners();
  }

  /// 登录后如果backend已经有这个用户的资料,直接用它填充store并跳过问卷——
  /// 跟save()逻辑一样,单独起个名字只是为了在调用处更清楚这是"从backend读回来的",不是用户刚填的。
  void hydrate({required UserProfile profile, required UserPersonalInfo personalInfo}) {
    save(profile: profile, personalInfo: personalInfo);
  }
}
