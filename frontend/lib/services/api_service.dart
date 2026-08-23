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

  /// 问卷填完后调用一次,让backend根据这个用户的profile+personalInfo(伤病/器材等)
  /// 生成一份workout plan并存下来。backend从token认用户,不需要也不接受client传profile/personalInfo。
  Future<FitnessPlan> generatePlan({String? accessToken}) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 600));
      return _mockPlan();
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/ai/generate-plan'),
      headers: {if (accessToken != null) 'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Could not generate your plan (${response.statusCode}): ${response.body}');
    }
    return FitnessPlan.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// 拿这个用户最近一次生成的plan(如果有的话)——登录/重启后用来恢复Home/Calendar/Plan
  /// 页面的内容,不用重新生成一份新的。没有生成过plan时backend返回404,这里当作null处理。
  Future<FitnessPlan?> fetchLatestPlan({String? accessToken}) async {
    if (ApiConfig.useMockData) return null;

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/ai/plan'),
      headers: {if (accessToken != null) 'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception('Could not load your plan (${response.statusCode}): ${response.body}');
    }
    return FitnessPlan.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// 计划一生成完自动分配(见profile_store.dart的autoAssignWorkoutDays)或者Plan/Calendar
  /// 页面Reschedule改了"哪天练哪个训练日"之后调用,把这份映射存到backend(挂在这个plan
  /// 底下),这样重启/重新登录也不会丢。
  Future<void> saveDayAssignments({required String planId, required Map<String, String> assignments, String? accessToken}) async {
    if (ApiConfig.useMockData) return;

    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/ai/plan/day-assignments'),
      headers: {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'planId': planId, 'assignments': assignments}),
    );
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Could not save your schedule (${response.statusCode}): ${response.body}');
    }
  }

  /// 周报/月报:数字全部是backend代码算好的,AI只负责把数字写成一段总结文字。
  Future<Report> getReport({required String periodType, String? accessToken}) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      return _mockReport(periodType);
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/ai/report'),
      headers: {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'periodType': periodType}),
    );
    if (response.statusCode != 200) {
      throw Exception('Could not load your report (${response.statusCode}): ${response.body}');
    }
    return Report.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// 记录一条体重。recordedAt只取日期部分(backend按date存)。
  Future<void> addWeightRecord({required double weightKg, DateTime? recordedAt, String? accessToken}) async {
    if (ApiConfig.useMockData) return;

    final when = recordedAt ?? DateTime.now();
    final dateOnly = '${when.year.toString().padLeft(4, '0')}-${when.month.toString().padLeft(2, '0')}-${when.day.toString().padLeft(2, '0')}';
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/weights'),
      headers: {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'weightKg': weightKg, 'recordedAt': dateOnly}),
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Could not save your weight (${response.statusCode}): ${response.body}');
    }
  }

  /// 记录一次训练结果:完成(带时长)或跳过(必须带原因——AI聊天会读这些原因来调整建议)。
  /// exerciseLog/feedback是新加的逐动作训练页数据:每个动作是否被跳过/为什么、预计vs实际
  /// 用了多久,以及(只有session看起来"异常"时才会有的)结束时反馈问卷的答案。都是可选的,
  /// 不传就是原来day级别的简单记录,后端两种都接受。
  Future<void> recordWorkout({
    required String planId,
    required String day,
    String status = 'completed',
    String? reason,
    int? durationSeconds,
    List<Map<String, dynamic>>? exerciseLog,
    Map<String, dynamic>? feedback,
    String? accessToken,
  }) async {
    if (ApiConfig.useMockData) return;

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/workouts/completions'),
      headers: {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'planId': planId,
        'day': day,
        'status': status,
        if (reason != null) 'reason': reason,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
        if (exerciseLog != null) 'exerciseLog': exerciseLog,
        if (feedback != null) 'feedback': feedback,
      }),
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Could not record the workout (${response.statusCode}): ${response.body}');
    }
  }

  /// 最近N天的训练完成/跳过记录,给Report页面的完成率图表+历史列表用。
  Future<List<WorkoutCompletion>> fetchRecentWorkouts({int days = 14, String? accessToken}) async {
    if (ApiConfig.useMockData) return [];

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/workouts/completions?days=$days'),
      headers: {if (accessToken != null) 'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw Exception('Could not load workout history (${response.statusCode}): ${response.body}');
    }
    return (jsonDecode(response.body) as List).map((e) => WorkoutCompletion.fromJson(e as Map<String, dynamic>)).toList();
  }

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

  /// 拍照/选图识别食材(冰箱/菜篮子),调用Backend的 `/ingredients/scan` 接口,跟
  /// identifyEquipment走一样的上传+auth流程。
  Future<IngredientScanResult> identifyIngredients({required File imageFile, String? accessToken}) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 800));
      return const IngredientScanResult(recognized: true, confidence: 0.85, ingredients: [
        DetectedIngredient(name: 'Egg', quantity: '6'),
        DetectedIngredient(name: 'Tomato', quantity: '3'),
      ]);
    }

    final request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/ingredients/scan'))
      ..headers.addAll({if (accessToken != null) 'Authorization': 'Bearer $accessToken'})
      ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw Exception('Ingredient scan failed (${response.statusCode}): ${response.body}');
    }
    return IngredientScanResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// 拍照/选图估算食物热量,调用Backend的 `/food/scan` 接口,用于Nutrition页面记录每日饮食。
  Future<FoodScanResult> scanFood({required File imageFile, String? accessToken}) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 800));
      return const FoodScanResult(
        recognized: true,
        confidence: 0.8,
        foodName: 'Chicken salad bowl',
        description: 'Grilled chicken breast over mixed greens with a light dressing.',
        portionEstimate: 'One medium bowl, about 350g',
        estimatedCalories: 420,
        estimatedProteinG: 35,
        estimatedCarbsG: 20,
        estimatedFatG: 18,
      );
    }

    final request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/food/scan'))
      ..headers.addAll({if (accessToken != null) 'Authorization': 'Bearer $accessToken'})
      ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw Exception('Food scan failed (${response.statusCode}): ${response.body}');
    }
    return FoodScanResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// 删除今天记录的一条食物(扫错了/重复了想撤掉)。
  Future<void> deleteFoodScan({required String scanId, String? accessToken}) async {
    if (ApiConfig.useMockData) return;

    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/food/scans/$scanId'),
      headers: {if (accessToken != null) 'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Could not delete this scan (${response.statusCode}): ${response.body}');
    }
  }

  /// 根据可用食材+忌口(可选带上最近体重进度)生成几道食谱推荐,给Nutrition页的
  /// "Get meal ideas"用。不落库——每次都是按当下食材现生成,跟plan/report不一样,
  /// 这个本来就是即用即弃的建议,不需要历史记录。
  Future<MealPlanResult> generateMealPlan({
    List<String> availableIngredients = const [],
    List<String> dietaryRestrictions = const [],
    bool includeRecentProgress = false,
    String? accessToken,
  }) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      return const MealPlanResult(
        planName: 'Balanced ideas for you',
        goal: 'lose_weight',
        dailyCalorieTarget: 1800,
        recipes: [
          Recipe(mealType: 'lunch', recipeName: 'Chicken & greens bowl', ingredientsUsed: ['chicken', 'greens'], instructions: 'Grill the chicken, toss with greens.', estimatedCalories: 420, estimatedProteinG: 35, reason: 'High protein, keeps you full.'),
        ],
      );
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/ai/generate-meal-plan'),
      headers: {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'availableIngredients': availableIngredients,
        'dietaryRestrictions': dietaryRestrictions,
        'includeRecentProgress': includeRecentProgress,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Could not generate meal ideas (${response.statusCode}): ${response.body}');
    }
    return MealPlanResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// 今日已经记录的食物列表+总热量,给Nutrition页面用。
  Future<DailyFoodLog> fetchTodayFoodLog({String? accessToken}) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 400));
      return const DailyFoodLog(date: '', totalCalories: 0, scans: []);
    }

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/food/scans/today'),
      headers: {if (accessToken != null) 'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw Exception('Could not load today\'s food log (${response.statusCode}): ${response.body}');
    }
    return DailyFoodLog.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  FitnessPlan _mockPlan() => FitnessPlan(planName: 'Your balanced starter plan', goal: 'lose_weight', weeklyFrequency: 3, exercises: const [
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
