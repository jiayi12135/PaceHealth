class Profile {
  final String name, sex, goal, lifestyle, exerciseLocation;
  final int age, exerciseFrequencyPerWeek, exerciseDurationMinutes;
  final double heightCm, startWeightKg, targetWeightKg;
  final List<String> exerciseHabit;
  const Profile({required this.name, required this.age, required this.sex, required this.heightCm, required this.startWeightKg, required this.targetWeightKg, required this.goal, required this.lifestyle, required this.exerciseFrequencyPerWeek, required this.exerciseDurationMinutes, this.exerciseHabit = const [], required this.exerciseLocation});
  Map<String, dynamic> toJson() => {'name': name, 'age': age, 'sex': sex, 'heightCm': heightCm, 'startWeightKg': startWeightKg, 'targetWeightKg': targetWeightKg, 'goal': goal, 'lifestyle': lifestyle, 'exerciseFrequencyPerWeek': exerciseFrequencyPerWeek, 'exerciseDurationMinutes': exerciseDurationMinutes, 'exerciseHabit': exerciseHabit, 'exerciseLocation': exerciseLocation};
}

class PersonalInfo {
  final List<String> availableEquipment, postureIssues, injuries, surgeryHistory, exercisesToAvoid;
  const PersonalInfo({this.availableEquipment = const [], this.postureIssues = const [], this.injuries = const [], this.surgeryHistory = const [], this.exercisesToAvoid = const []});
  Map<String, dynamic> toJson() => {'availableEquipment': availableEquipment, 'postureIssues': postureIssues, 'injuries': injuries, 'surgeryHistory': surgeryHistory, 'exercisesToAvoid': exercisesToAvoid};
}

class Exercise {
  final String day, exerciseName, reason;
  final int sets, restSeconds;
  final int? reps, duration;
  final String? videoUrl;
  // 从Pexels按动作名搜到的缩略图,可能是null(没配key/没搜到/请求失败都会是null)——
  // UI这边要有图标兜底,不能假设这个字段一定有值。
  final String? imageUrl;
  // 具体怎么做这个动作(跟reason"为什么推荐"是两个不同字段),Workout Session逐动作页用。
  final String instructions;
  const Exercise({required this.day, required this.exerciseName, required this.sets, this.reps, this.duration, required this.restSeconds, required this.reason, this.videoUrl, this.imageUrl, this.instructions = ''});
  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(day: j['day'], exerciseName: j['exerciseName'], sets: j['sets'], reps: j['reps'], duration: j['duration'], restSeconds: j['restSeconds'], reason: j['reason'] ?? '', videoUrl: j['videoUrl'], imageUrl: j['imageUrl'], instructions: j['instructions'] ?? '');
}

class FitnessPlan {
  final String? planId;
  final String planName, goal;
  final int weeklyFrequency;
  final List<Exercise> exercises;
  // planDay("Day 1") -> weekday("Mon"),从backend存的ai_plans.day_assignments读回来的——
  // 重启/重新登录后能恢复"哪天排了哪个训练日",不用重新自动分配一遍。
  // 刚生成、还没分配过的plan这里是空map。
  final Map<String, String> dayAssignments;
  // 这份plan是什么时候生成的——Calendar用它判断"这个日期是不是在有这份计划之前",
  // 避免把用户开号之前(比如周四才填问卷)那几天错误地标成missed。没有的话(理论上
  // 不该发生,backend现在一定会给)兜底成现在,行为等同于"从今天才开始有计划"。
  final DateTime createdAt;
  FitnessPlan({this.planId, required this.planName, required this.goal, required this.weeklyFrequency, required this.exercises, this.dayAssignments = const {}, DateTime? createdAt}) : createdAt = createdAt ?? DateTime.now();
  factory FitnessPlan.fromJson(Map<String, dynamic> j) => FitnessPlan(
        planId: j['planId'] as String?,
        planName: j['planName'],
        goal: j['goal'],
        weeklyFrequency: j['weeklyFrequency'],
        exercises: (j['exercises'] as List).map((e) => Exercise.fromJson(e)).toList(),
        dayAssignments: (j['dayAssignments'] as Map?)?.cast<String, String>() ?? const {},
        createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt'] as String) : null,
      );
}

class WorkoutCompletion {
  final String day, status;
  final String? reason;
  final int? durationSeconds;
  final DateTime completedAt;
  const WorkoutCompletion({required this.day, required this.status, this.reason, this.durationSeconds, required this.completedAt});
  factory WorkoutCompletion.fromJson(Map<String, dynamic> j) => WorkoutCompletion(
        day: j['day'] as String,
        status: j['status'] as String,
        reason: j['reason'] as String?,
        durationSeconds: (j['durationSeconds'] as num?)?.toInt(),
        completedAt: DateTime.parse(j['completedAt'] as String),
      );
}

class WeightRecord {
  final double weightKg;
  final DateTime recordedAt;
  const WeightRecord({required this.weightKg, required this.recordedAt});
  factory WeightRecord.fromJson(Map<String, dynamic> j) => WeightRecord(
        weightKg: (j['weightKg'] as num).toDouble(),
        recordedAt: DateTime.parse(j['recordedAt'] as String),
      );
}
// Note: `initialWeightKg` is the weight at the *start of this reporting period*
// (this week/month), not the same thing as Profile.startWeightKg (the weight when
// the goal was first set). Don't rename this back to startWeightKg — that name
// collides with the unrelated Profile field and caused confusion before.
class Report {
  final String periodType, summary;
  final bool hasEnoughData;
  final double? initialWeightKg, endWeightKg, deltaKg, progressToGoalPercent, projectedWeeksToGoal;
  final List<WeightRecord> weightRecords;
  const Report({required this.periodType, required this.summary, required this.hasEnoughData, this.initialWeightKg, this.endWeightKg, this.deltaKg, this.progressToGoalPercent, this.projectedWeeksToGoal, this.weightRecords = const []});
  factory Report.fromJson(Map<String, dynamic> j) => Report(
        periodType: j['periodType'] as String,
        summary: j['summary'] as String? ?? '',
        hasEnoughData: j['hasEnoughData'] as bool? ?? false,
        initialWeightKg: (j['initialWeightKg'] as num?)?.toDouble(),
        endWeightKg: (j['endWeightKg'] as num?)?.toDouble(),
        deltaKg: (j['deltaKg'] as num?)?.toDouble(),
        progressToGoalPercent: (j['progressToGoalPercent'] as num?)?.toDouble(),
        projectedWeeksToGoal: (j['projectedWeeksToGoal'] as num?)?.toDouble(),
        weightRecords: ((j['weightRecords'] as List?) ?? const []).map((e) => WeightRecord.fromJson(e as Map<String, dynamic>)).toList(),
      );
}
