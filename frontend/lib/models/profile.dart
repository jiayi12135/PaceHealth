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
  UserPersonalInfo({List<String>? availableEquipment, List<String>? postureIssues, List<String>? injuries, List<String>? surgeryHistory, List<String>? exercisesToAvoid})
      : availableEquipment = availableEquipment ?? [],
        postureIssues = postureIssues ?? [],
        injuries = injuries ?? [],
        surgeryHistory = surgeryHistory ?? [],
        exercisesToAvoid = exercisesToAvoid ?? [];
  Map<String, dynamic> toJson() => {'availableEquipment': availableEquipment, 'postureIssues': postureIssues, 'injuries': injuries, 'surgeryHistory': surgeryHistory, 'exercisesToAvoid': exercisesToAvoid};

  factory UserPersonalInfo.fromJson(Map<String, dynamic> json) => UserPersonalInfo(
        availableEquipment: (json['availableEquipment'] as List?)?.cast<String>(),
        postureIssues: (json['postureIssues'] as List?)?.cast<String>(),
        injuries: (json['injuries'] as List?)?.cast<String>(),
        surgeryHistory: (json['surgeryHistory'] as List?)?.cast<String>(),
        exercisesToAvoid: (json['exercisesToAvoid'] as List?)?.cast<String>(),
      );
}
