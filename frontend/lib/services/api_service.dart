import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import '../models/profile.dart';
import '../models/ai_models.dart';

class SavedProfile {
  final UserProfile profile;
  final UserPersonalInfo personalInfo;
  const SavedProfile({required this.profile, required this.personalInfo});
}

class ApiConfig { static const baseUrl = String.fromEnvironment('PACEHEALTH_API_URL', defaultValue: 'http://10.0.2.2:8000'); static const useMockData = false; }

class AuthSession {
  final String email;
  final String? accessToken;
  const AuthSession({required this.email, this.accessToken});
}

class ApiService {
  Future<AuthSession> authenticate({
    required String email,
    required String password,
    required bool register,
  }) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 450));
      return AuthSession(email: email);
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/${register ? 'register' : 'login'}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['message'] ?? 'Unable to ${register ? 'create your account' : 'sign in'}.');
    }
    final user = body['user'] as Map<String, dynamic>;
    final token = body['accessToken'] as String?;
    if (token == null) {
      // Supabase asked for email confirmation, so there's no session yet — don't
      // pretend the user is signed in with a token that doesn't exist.
      throw Exception('Please check your email to confirm your account, then sign in.');
    }
    return AuthSession(email: user['email'] as String, accessToken: token);
  }

  /// 登录后调用一次,看这个用户之前是不是已经填过问卷。已经填过返回资料,没填过(backend
  /// 返回404 PROFILE_NOT_FOUND)返回null——这种情况下应该引导用户走一遍问卷。
  Future<SavedProfile?> fetchMyProfile({String? accessToken}) async {
    if (ApiConfig.useMockData) return null;

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/users/me'),
      headers: {if (accessToken != null) 'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception('Could not load your profile (${response.statusCode}): ${response.body}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return SavedProfile(
      profile: UserProfile.fromJson(body['profile'] as Map<String, dynamic>),
      personalInfo: UserPersonalInfo.fromJson(body['personalInfo'] as Map<String, dynamic>),
    );
  }

  /// 问卷填完后调用,把资料真正存进backend(之前这一步只存在本地,没打这个接口)。
  Future<void> saveMyProfile({required UserProfile profile, required UserPersonalInfo personalInfo, String? accessToken}) async {
    if (ApiConfig.useMockData) return;

    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/users/me'),
      headers: {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'profile': profile.toJson(), 'personalInfo': personalInfo.toJson()}),
    );
    if (response.statusCode != 200) {
      throw Exception('Could not save your profile (${response.statusCode}): ${response.body}');
    }
  }

  Future<FitnessPlan> generatePlan({required String userId, required Profile profile, required PersonalInfo personalInfo}) async => _mockPlan();
  Future<Report> getReport({required String periodType, required Profile profile}) async => _mockReport(periodType);
  Future<void> addWeightRecord(WeightRecord record) async {}

  /// 发一条消息给AI聊天,拿到回复文字。
  /// history 需要按时间顺序传入之前的对话(最新的消息不用带进history,单独传在message里)。
  /// useMockData=true 时不会真的连backend,直接返回一句假回复,方便没搭好backend之前先把UI做出来测试。
  /// accessToken 是登录后拿到的bearer token,真实backend用它识别是哪个用户,不需要再传userId/profile。
  Future<String> sendChatMessage({
    required String userId,
    required String message,
    required List<ChatMessageDto> history,
    UserProfile? profile,
    UserPersonalInfo? personalInfo,
    String? accessToken,
  }) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      return _mockChatReply(message);
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/ai/chat'),
      headers: {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'message': message}),
    );
    if (response.statusCode != 200) {
      throw Exception('Chat request failed (${response.statusCode}): ${response.body}');
    }
    return (jsonDecode(response.body) as Map<String, dynamic>)['reply'] as String;
  }

  /// 拍照/选图识别健身器材,调用Backend的 `/equipment/scan` 接口——因为图片要先上传到
  /// Supabase Storage拿到URL,这一步需要Backend的密钥权限,Flutter端不应该直接持有存储的写入权限。
  /// Backend拿到图片后自己上传、拿URL、再转发给AI服务的 /ai/identify-equipment。
  /// accessToken 是登录后拿到的bearer token,真实backend用它识别是哪个用户。
  Future<EquipmentResult> identifyEquipment({
    required String userId,
    required File imageFile,
    UserPersonalInfo? personalInfo,
    String? accessToken,
  }) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 800));
      return _mockEquipmentResult();
    }

    final request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/equipment/scan'))
      ..headers.addAll({if (accessToken != null) 'Authorization': 'Bearer $accessToken'})
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
  Report _mockReport(String period) => Report(periodType: period, summary: 'You are building a consistent routine. Keep recording your weight to make your progress trend more meaningful.', hasEnoughData: true, initialWeightKg: 68, endWeightKg: 67.2, deltaKg: -.8, progressToGoalPercent: 10, projectedWeeksToGoal: 7.7, weightRecords: [WeightRecord(weightKg: 68, recordedAt: DateTime.now().subtract(const Duration(days: 7))), WeightRecord(weightKg: 67.2, recordedAt: DateTime.now())]);

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
