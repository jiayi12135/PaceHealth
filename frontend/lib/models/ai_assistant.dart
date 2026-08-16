import 'package:flutter/material.dart';

/// 一个预设图标选项(用户从这几个里选一个当AI的头像,不用处理图片上传)
class AiIconOption {
  final String key;
  final IconData icon;
  final Color color;
  const AiIconOption({required this.key, required this.icon, required this.color});
}

/// 所有可选的预设AI头像,想加新的直接往这个列表里加一项就行
const List<AiIconOption> kAiIconOptions = [
  AiIconOption(key: 'robot', icon: Icons.smart_toy, color: Color(0xff287d68)),
  AiIconOption(key: 'spark', icon: Icons.auto_awesome, color: Color(0xfff5a623)),
  AiIconOption(key: 'heart', icon: Icons.favorite, color: Color(0xffe0575b)),
  AiIconOption(key: 'bolt', icon: Icons.bolt, color: Color(0xff4a90d9)),
  AiIconOption(key: 'star', icon: Icons.star, color: Color(0xff9b59b6)),
  AiIconOption(key: 'paw', icon: Icons.pets, color: Color(0xffe67e22)),
];

AiIconOption aiIconByKey(String key) => kAiIconOptions.firstWhere((o) => o.key == key, orElse: () => kAiIconOptions.first);

/// 用户自定义的AI设置(名字 + 头像),本地存储,不经过backend
class AiAssistantSettings {
  final String name;
  final String iconKey;
  const AiAssistantSettings({this.name = 'Coach', this.iconKey = 'robot'});

  AiAssistantSettings copyWith({String? name, String? iconKey}) =>
      AiAssistantSettings(name: name ?? this.name, iconKey: iconKey ?? this.iconKey);
}
