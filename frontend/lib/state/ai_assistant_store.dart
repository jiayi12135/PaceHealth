import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_assistant.dart';

const _kNameKey = 'ai_assistant_name';
const _kIconKey = 'ai_assistant_icon';

/// 管理"AI名字+头像"这个设置,存在手机本地(shared_preferences),
/// 不需要backend、不需要登录状态,换手机/卸载重装会丢失,demo阶段够用。
class AiAssistantStore extends ChangeNotifier {
  AiAssistantSettings settings = const AiAssistantSettings();

  /// app启动时调用一次,把上次保存的设置读出来
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kNameKey);
    final iconKey = prefs.getString(_kIconKey);
    if (name != null || iconKey != null) {
      settings = AiAssistantSettings(
        name: name ?? settings.name,
        iconKey: iconKey ?? settings.iconKey,
      );
      notifyListeners();
    }
  }

  Future<void> save({required String name, required String iconKey}) async {
    settings = AiAssistantSettings(name: name, iconKey: iconKey);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNameKey, name);
    await prefs.setString(_kIconKey, iconKey);
  }
}
