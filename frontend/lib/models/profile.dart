class UserProfile {
  String name, sex, goal, lifestyle, exerciseHabit, exerciseLocation;
  int age, exerciseFrequencyPerWeek, exerciseDurationMinutes;
  double heightCm, startWeightKg, targetWeightKg;
  UserProfile({this.name = '', this.age = 0, this.sex = '', this.heightCm = 0, this.startWeightKg = 0, this.targetWeightKg = 0, this.goal = '', this.lifestyle = '', this.exerciseFrequencyPerWeek = 0, this.exerciseDurationMinutes = 0, this.exerciseHabit = '', this.exerciseLocation = ''});

  /// Backend的 `exerciseHabit` 是字符串数组(见 docs/API_CONTRACT.md),但这里的问卷UI目前
  /// 只做单选,所以存成单个String。发请求时包成数组,收到数组时用逗号拼回字符串——
  /// 这是个已知的简化,以后要支持多选的话得把这个字段也改成List<String>。
  Map<String, dynamic> toJson() => {'name': name, 'age': age, 'sex': sex, 'heightCm': heightCm, 'startWeightKg': startWeightKg, 'targetWeightKg': targetWeightKg, 'goal': goal, 'lifestyle': lifestyle, 'exerciseFrequencyPerWeek': exerciseFrequencyPerWeek, 'exerciseDurationMinutes': exerciseDurationMinutes, 'exerciseHabit': exerciseHabit.isEmpty ? <String>[] : exerciseHabit.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(), 'exerciseLocation': exerciseLocation};

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'] as String? ?? '',
        age: (json['age'] as num?)?.toInt() ?? 0,
        sex: json['sex'] as String? ?? '',
        heightCm: (json['heightCm'] as num?)?.toDouble() ?? 0,
        startWeightKg: (json['startWeightKg'] as num?)?.toDouble() ?? 0,
        targetWeightKg: (json['targetWeightKg'] as num?)?.toDouble() ?? 0,
        goal: json['goal'] as String? ?? '',
        lifestyle: json['lifestyle'] as String? ?? '',
        exerciseFrequencyPerWeek: (json['exerciseFrequencyPerWeek'] as num?)?.toInt() ?? 0,
        exerciseDurationMinutes: (json['exerciseDurationMinutes'] as num?)?.toInt() ?? 0,
        exerciseHabit: ((json['exerciseHabit'] as List?)?.cast<String>() ?? const []).join(', '),
        exerciseLocation: json['exerciseLocation'] as String? ?? '',
      );
}
class UserPersonalInfo {
  List<String> availableEquipment, postureIssues, injuries, surgeryHistory, exercisesToAvoid;
  // 只有女性用户在Home页填过才会有值,格式'yyyy-MM-dd'。用来在Home算"离下次经期还有几天"
  // (纯前端算,固定28天假设,跟backend算法一致),也会存到backend给AI聊天context用。
  String? lastPeriodDate;
  // 问卷里选的具体星期几(比如['Mon','Wed','Fri']),按顺序对应生成计划里的Day 1/2/3。
  // 存这里是为了在hot restart/重新hydrate时不丢失,并且传给backend用来做经期感知的
  // plan生成(见ProfileStore.workoutDays的同步逻辑)。
  List<String> workoutWeekdays;
  UserPersonalInfo({
    List<String>? availableEquipment,
    List<String>? postureIssues,
    List<String>? injuries,
    List<String>? surgeryHistory,
    List<String>? exercisesToAvoid,
    this.lastPeriodDate,
    List<String>? workoutWeekdays,
  })  : availableEquipment = availableEquipment ?? [],
        postureIssues = postureIssues ?? [],
        injuries = injuries ?? [],
        surgeryHistory = surgeryHistory ?? [],
        exercisesToAvoid = exercisesToAvoid ?? [],
        workoutWeekdays = workoutWeekdays ?? [];
  Map<String, dynamic> toJson() => {
        'availableEquipment': availableEquipment,
        'postureIssues': postureIssues,
        'injuries': injuries,
        'surgeryHistory': surgeryHistory,
        'exercisesToAvoid': exercisesToAvoid,
        if (lastPeriodDate != null) 'lastPeriodDate': lastPeriodDate,
        'workoutWeekdays': workoutWeekdays,
      };

  factory UserPersonalInfo.fromJson(Map<String, dynamic> json) => UserPersonalInfo(
        availableEquipment: (json['availableEquipment'] as List?)?.cast<String>(),
        postureIssues: (json['postureIssues'] as List?)?.cast<String>(),
        injuries: (json['injuries'] as List?)?.cast<String>(),
        surgeryHistory: (json['surgeryHistory'] as List?)?.cast<String>(),
        exercisesToAvoid: (json['exercisesToAvoid'] as List?)?.cast<String>(),
        lastPeriodDate: json['lastPeriodDate'] as String?,
        workoutWeekdays: (json['workoutWeekdays'] as List?)?.cast<String>(),
      );
}
