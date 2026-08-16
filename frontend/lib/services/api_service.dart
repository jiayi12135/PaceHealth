import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import '../models/profile.dart';
import '../models/ai_models.dart';

class ApiConfig { static const baseUrl = String.fromEnvironment('PACEHEALTH_API_URL', defaultValue: 'http://localhost:8000'); static const useMockData = true; }

class ApiService {
  Future<FitnessPlan> generatePlan({required String userId, required Profile profile, required PersonalInfo personalInfo}) async => _mockPlan();
  Future<Report> getReport({required String periodType, required Profile profile}) async => _mockReport(periodType);
  Future<void> addWeightRecord(WeightRecord record) async {}

  /// 发一条消息给AI聊天,拿到回复文字。
  /// history 需要按时间顺序传入之前的对话(最新的消息不用带进history,单独传在message里)。
  /// useMockData=true 时不会真的连backend,直接返回一句假回复,方便没搭好backend之前先把UI做出来测试。
  Future<String> sendChatMessage({
    required String userId,
    required String message,
    required List<ChatMessageDto> history,
    UserProfile? profile,
    UserPersonalInfo? personalInfo,
  }) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      return _mockChatReply(message);
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/ai/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'message': message,
        'history': history.map((m) => m.toJson()).toList(),
        if (profile != null) 'profile': profile.toJson(),
        if (personalInfo != null) 'personalInfo': personalInfo.toJson(),
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Chat request failed (${response.statusCode}): ${response.body}');
    }
    return (jsonDecode(response.body) as Map<String, dynamic>)['reply'] as String;
  }

  /// 拍照/选图识别健身器材。
  ///
  /// 注意: 这里调用的是 Backend 的 `/equipment/scan` 接口(需要 Backend 实现,
  /// 目前还没做),不是直接调AI服务——因为图片要先上传到Supabase Storage拿到URL,
  /// 这一步需要Backend的密钥权限,Flutter端不应该直接持有存储的写入权限。
  /// Backend拿到图片后自己上传、拿URL、再转发给AI服务的 /ai/identify-equipment。
  Future<EquipmentResult> identifyEquipment({
    required String userId,
    required File imageFile,
    UserPersonalInfo? personalInfo,
  }) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 800));
      return _mockEquipmentResult();
    }

    final request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/equipment/scan'))
      ..fields['userId'] = userId
      ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw Exception('Equipment scan failed (${response.statusCode}): ${response.body}');
    }
    return EquipmentResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  FitnessPlan _mockPlan() => const FitnessPlan(planName: 'Your balanced starter plan', goal: 'lose_weight', weeklyFrequency: 3, exercises: [
    Exercise(day: 'Day 1', exerciseName: 'Bodyweight Squat', sets: 3, reps: 12, restSeconds: 60, reason: 'Build lower-body strength with a joint-friendly movement.'),
    Exercise(day: 'Day 1', exerciseName: 'Dead Bug', sets: 3, reps: 10, restSeconds: 45, reason: 'Strengthen your core and support better posture.'),
    Exercise(day: 'Day 2', exerciseName: 'Brisk Walk', sets: 1, duration: 1200, restSeconds: 0, reason: 'A sustainable cardio session matched to your current fitness level.'),
  ]);
  Report _mockReport(String period) => Report(periodType: period, summary: 'You are building a consistent routine. Keep recording your weight to make your progress trend more meaningful.', hasEnoughData: true, startWeightKg: 68, endWeightKg: 67.2, deltaKg: -.8, progressToGoalPercent: 10, projectedWeeksToGoal: 7.7, weightRecords: [WeightRecord(weightKg: 68, recordedAt: DateTime.now().subtract(const Duration(days: 7))), WeightRecord(weightKg: 67.2, recordedAt: DateTime.now())]);

  String _mockChatReply(String message) {
    if (message.contains('？') || message.contains('?')) {
      return 'Good question! Based on your goals, I would suggest starting light and focusing on form first. Want me to explain more?';
    }
    return "Got it — I've noted that. Keep up the consistency, that matters more than intensity early on.";
  }

  EquipmentResult _mockEquipmentResult() => const EquipmentResult(
        recognized: true,
        confidence: 0.9,
        equipmentName: 'Resistance Band',
        description: 'A stretchy loop band used for strength and mobility training.',
        targetMuscles: ['Glutes', 'Shoulders', 'Core'],
        usageInstructions: '1. Choose a light resistance to start.\n2. Keep tension on the band throughout the movement.\n3. Move slowly and with control.',
        safetyNotes: 'Check the band for tears before use. Do not overstretch beyond its limit.',
        personalizedWarning: null,
      );
}
