/// 聊天记录里的一条消息,跟backend /ai/chat 的 history 格式对应
class ChatMessageDto {
  final String role; // "user" 或 "assistant"
  final String message;
  const ChatMessageDto({required this.role, required this.message});
  Map<String, dynamic> toJson() => {'role': role, 'message': message};
}

/// 器材识别结果,对应backend /ai/identify-equipment 的返回格式
class EquipmentResult {
  final bool recognized;
  final double confidence;
  final String? equipmentName;
  final String? description;
  final List<String> targetMuscles;
  final String? usageInstructions;
  final String? safetyNotes;
  final String? personalizedWarning;
  final String? notRecognizedMessage;

  const EquipmentResult({
    required this.recognized,
    required this.confidence,
    this.equipmentName,
    this.description,
    this.targetMuscles = const [],
    this.usageInstructions,
    this.safetyNotes,
    this.personalizedWarning,
    this.notRecognizedMessage,
  });

  factory EquipmentResult.fromJson(Map<String, dynamic> j) => EquipmentResult(
        recognized: j['recognized'] ?? false,
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
        equipmentName: j['equipmentName'],
        description: j['description'],
        targetMuscles: (j['targetMuscles'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        usageInstructions: j['usageInstructions'],
        safetyNotes: j['safetyNotes'],
        personalizedWarning: j['personalizedWarning'],
        notRecognizedMessage: j['notRecognizedMessage'],
      );
}

/// 识别出的单个食材,对应backend /ingredients/scan 返回的 ingredients 数组里的一项
class DetectedIngredient {
  final String name;
  final String? quantity;
  const DetectedIngredient({required this.name, this.quantity});
  factory DetectedIngredient.fromJson(Map<String, dynamic> j) => DetectedIngredient(name: j['name'] ?? '', quantity: j['quantity']);
}

/// 食材识别结果,对应backend /ingredients/scan 的返回格式
class IngredientScanResult {
  final bool recognized;
  final double confidence;
  final List<DetectedIngredient> ingredients;
  final String? notRecognizedMessage;

  const IngredientScanResult({required this.recognized, required this.confidence, this.ingredients = const [], this.notRecognizedMessage});

  factory IngredientScanResult.fromJson(Map<String, dynamic> j) => IngredientScanResult(
        recognized: j['recognized'] ?? false,
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
        ingredients: (j['ingredients'] as List?)?.map((e) => DetectedIngredient.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
        notRecognizedMessage: j['notRecognizedMessage'],
      );
}

/// 食物拍照估算热量结果,对应backend /food/scan 的返回格式
class FoodScanResult {
  final String? scanId;
  final bool recognized;
  final double confidence;
  final String? foodName;
  final String? description;
  final String? portionEstimate;
  final int? estimatedCalories;
  final double? estimatedProteinG;
  final double? estimatedCarbsG;
  final double? estimatedFatG;
  final String? notRecognizedMessage;
  final String? scannedAt;

  const FoodScanResult({
    this.scanId,
    required this.recognized,
    required this.confidence,
    this.foodName,
    this.description,
    this.portionEstimate,
    this.estimatedCalories,
    this.estimatedProteinG,
    this.estimatedCarbsG,
    this.estimatedFatG,
    this.notRecognizedMessage,
    this.scannedAt,
  });

  factory FoodScanResult.fromJson(Map<String, dynamic> j) => FoodScanResult(
        scanId: j['scanId'],
        recognized: j['recognized'] ?? false,
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
        foodName: j['foodName'],
        description: j['description'],
        portionEstimate: j['portionEstimate'],
        estimatedCalories: (j['estimatedCalories'] as num?)?.toInt(),
        estimatedProteinG: (j['estimatedProteinG'] as num?)?.toDouble(),
        estimatedCarbsG: (j['estimatedCarbsG'] as num?)?.toDouble(),
        estimatedFatG: (j['estimatedFatG'] as num?)?.toDouble(),
        notRecognizedMessage: j['notRecognizedMessage'],
        scannedAt: j['scannedAt'],
      );
}

/// 一道推荐食谱,对应backend MealPlanResponse.recipes里的一项
class Recipe {
  final String mealType; // 'breakfast' / 'lunch' / 'dinner' / 'snack'
  final String recipeName;
  final List<String> ingredientsUsed;
  final String instructions;
  final int? estimatedCalories;
  final double? estimatedProteinG;
  final String reason;

  const Recipe({
    required this.mealType,
    required this.recipeName,
    this.ingredientsUsed = const [],
    required this.instructions,
    this.estimatedCalories,
    this.estimatedProteinG,
    required this.reason,
  });

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
        mealType: j['mealType'] ?? '',
        recipeName: j['recipeName'] ?? '',
        ingredientsUsed: (j['ingredientsUsed'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        instructions: j['instructions'] ?? '',
        estimatedCalories: (j['estimatedCalories'] as num?)?.toInt(),
        estimatedProteinG: (j['estimatedProteinG'] as num?)?.toDouble(),
        reason: j['reason'] ?? '',
      );
}

/// AI生成的食谱推荐结果,对应backend POST /ai/generate-meal-plan 的返回格式
class MealPlanResult {
  final String planName;
  final String goal;
  final int? dailyCalorieTarget;
  final List<Recipe> recipes;
  final String? adjustmentNote;

  const MealPlanResult({
    required this.planName,
    required this.goal,
    this.dailyCalorieTarget,
    this.recipes = const [],
    this.adjustmentNote,
  });

  factory MealPlanResult.fromJson(Map<String, dynamic> j) => MealPlanResult(
        planName: j['planName'] ?? '',
        goal: j['goal'] ?? '',
        dailyCalorieTarget: (j['dailyCalorieTarget'] as num?)?.toInt(),
        recipes: (j['recipes'] as List?)?.map((e) => Recipe.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
        adjustmentNote: j['adjustmentNote'],
      );
}

/// 今日食物日志,对应backend GET /food/scans/today 的返回格式
class DailyFoodLog {
  final String date;
  final int totalCalories;
  final List<FoodScanResult> scans;
  const DailyFoodLog({required this.date, required this.totalCalories, this.scans = const []});
  factory DailyFoodLog.fromJson(Map<String, dynamic> j) => DailyFoodLog(
        date: j['date'] ?? '',
        totalCalories: (j['totalCalories'] as num?)?.toInt() ?? 0,
        scans: (j['scans'] as List?)?.map((e) => FoodScanResult.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      );
}
