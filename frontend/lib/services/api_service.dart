import '../models/models.dart';

class ApiConfig { static const baseUrl = String.fromEnvironment('PACEHEALTH_API_URL', defaultValue: 'http://localhost:8000'); static const useMockData = true; }

class ApiService {
  Future<FitnessPlan> generatePlan({required String userId, required Profile profile, required PersonalInfo personalInfo}) async => _mockPlan();
  Future<Report> getReport({required String periodType, required Profile profile}) async => _mockReport(periodType);
  Future<void> addWeightRecord(WeightRecord record) async {}

  FitnessPlan _mockPlan() => const FitnessPlan(planName: 'Your balanced starter plan', goal: 'lose_weight', weeklyFrequency: 3, exercises: [
    Exercise(day: 'Day 1', exerciseName: 'Bodyweight Squat', sets: 3, reps: 12, restSeconds: 60, reason: 'Build lower-body strength with a joint-friendly movement.'),
    Exercise(day: 'Day 1', exerciseName: 'Dead Bug', sets: 3, reps: 10, restSeconds: 45, reason: 'Strengthen your core and support better posture.'),
    Exercise(day: 'Day 2', exerciseName: 'Brisk Walk', sets: 1, duration: 1200, restSeconds: 0, reason: 'A sustainable cardio session matched to your current fitness level.'),
  ]);
  Report _mockReport(String period) => Report(periodType: period, summary: 'You are building a consistent routine. Keep recording your weight to make your progress trend more meaningful.', hasEnoughData: true, startWeightKg: 68, endWeightKg: 67.2, deltaKg: -.8, progressToGoalPercent: 10, projectedWeeksToGoal: 7.7, weightRecords: [WeightRecord(weightKg: 68, recordedAt: DateTime.now().subtract(const Duration(days: 7))), WeightRecord(weightKg: 67.2, recordedAt: DateTime.now())]);
}
