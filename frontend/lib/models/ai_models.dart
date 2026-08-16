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
