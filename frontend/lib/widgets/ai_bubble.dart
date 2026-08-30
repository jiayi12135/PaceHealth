import 'package:flutter/material.dart';
import '../models/ai_assistant.dart';
import '../screens/ai/ai_chat_screen.dart';
import '../screens/ai/ai_customize_screen.dart';
import '../state/ai_assistant_store.dart';
import '../state/profile_store.dart';

/// 仿Messenger的悬浮聊天气泡: 可以拖动到屏幕任意位置,点一下打开AI聊天页。
/// 要用这个widget,把它和页面内容一起放进一个Stack里(见 app_shell.dart)。
class AiBubble extends StatefulWidget {
  final AiAssistantStore aiStore;
  final ProfileStore profileStore;
  const AiBubble({super.key, required this.aiStore, required this.profileStore});

  @override
  State<AiBubble> createState() => _AiBubbleState();
}

class _AiBubbleState extends State<AiBubble> {
  static const double _bubbleSize = 60;
  Offset? _offset; // null直到第一次build拿到屏幕尺寸,算出右下角默认位置;之后用户可以拖到别处

  void _openChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AiChatScreen(aiStore: widget.aiStore, profileStore: widget.profileStore)),
    );
  }

  void _openCustomize(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AiCustomizeScreen(aiStore: widget.aiStore)));
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.aiStore.settings;
    final iconOption = aiIconByKey(settings.iconKey);
    final screenSize = MediaQuery.of(context).size;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    // 默认停在右下角(导航栏上方留够空间),之后用户拖过的位置才会覆盖这个默认值。
    _offset ??= Offset(screenSize.width - _bubbleSize - 16, screenSize.height - _bubbleSize - safeBottom - 96);
    final offset = _offset!;

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            final next = offset + details.delta;
            // 别让气泡拖出屏幕外(clamp在double上返回的是num,这里用toDouble()转回来)
            _offset = Offset(
              next.dx.clamp(0.0, screenSize.width - _bubbleSize).toDouble(),
              next.dy.clamp(0.0, screenSize.height - _bubbleSize).toDouble(),
            );
          });
        },
        onTap: () => _openChat(context),
        onLongPress: () => _openCustomize(context),
        child: Material(
          elevation: 6,
          shape: const CircleBorder(),
          color: iconOption.color,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(aiEmojiByKey(settings.iconKey), style: const TextStyle(fontSize: 27)),
          ),
        ),
      ),
    );
  }
}
