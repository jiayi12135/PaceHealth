class Profile {
  final String name, sex, goal, lifestyle, exerciseLocation;
  final int age, exerciseFrequencyPerWeek, exerciseDurationMinutes;
  final double heightCm, currentWeightKg, targetWeightKg;
  const Profile({required this.name, required this.age, required this.sex, required this.heightCm, required this.currentWeightKg, required this.targetWeightKg, required this.goal, required this.lifestyle, required this.exerciseFrequencyPerWeek, required this.exerciseDurationMinutes, required this.exerciseLocation});
  Map<String, dynamic> toJson() => {'name': name, 'age': age, 'sex': sex, 'heightCm': heightCm, 'currentWeightKg': currentWeightKg, 'targetWeightKg': targetWeightKg, 'goal': goal, 'lifestyle': lifestyle, 'exerciseFrequencyPerWeek': exerciseFrequencyPerWeek, 'exerciseDurationMinutes': exerciseDurationMinutes, 'exerciseLocation': exerciseLocation};
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
  const Exercise({required this.day, required this.exerciseName, required this.sets, this.reps, this.duration, required this.restSeconds, required this.reason, this.videoUrl});
  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(day: j['day'], exerciseName: j['exerciseName'], sets: j['sets'], reps: j['reps'], duration: j['duration'], restSeconds: j['restSeconds'], reason: j['reason'] ?? '', videoUrl: j['videoUrl']);
}

class FitnessPlan {
  final String planName, goal;
  final int weeklyFrequency;
  final List<Exercise> exercises;
  const FitnessPlan({required this.planName, required this.goal, required this.weeklyFrequency, required this.exercises});
  factory FitnessPlan.fromJson(Map<String, dynamic> j) => FitnessPlan(planName: j['planName'], goal: j['goal'], weeklyFrequency: j['weeklyFrequency'], exercises: (j['exercises'] as List).map((e) => Exercise.fromJson(e)).toList());
}

class WeightRecord { final double weightKg; final DateTime recordedAt; const WeightRecord({required this.weightKg, required this.recordedAt}); }
class Report { final String periodType, summary; final bool hasEnoughData; final double? startWeightKg, endWeightKg, deltaKg, progressToGoalPercent, projectedWeeksToGoal; final List<WeightRecord> weightRecords; const Report({required this.periodType, required this.summary, required this.hasEnoughData, this.startWeightKg, this.endWeightKg, this.deltaKg, this.progressToGoalPercent, this.projectedWeeksToGoal, this.weightRecords = const []}); }
