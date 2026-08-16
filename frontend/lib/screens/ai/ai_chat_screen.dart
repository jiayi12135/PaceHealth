import 'package:flutter/material.dart';
import '../../models/ai_assistant.dart';
import '../../models/ai_models.dart';
import '../../services/api_service.dart';
import '../../state/ai_assistant_store.dart';
import '../../state/profile_store.dart';

/// AI聊天页面。用户点悬浮气泡后打开这个页面。
class AiChatScreen extends StatefulWidget {
  final AiAssistantStore aiStore;
  final ProfileStore profileStore;
  const AiChatScreen({super.key, required this.aiStore, required this.profileStore});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _api = ApiService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessageDto> _messages = [];
  bool _sending = false;

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(ChatMessageDto(role: 'user', message: text));
      _sending = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final reply = await _api.sendChatMessage(
        userId: 'demo-user', // TODO: 换成真实登录用户的ID(等auth接好之后)
        message: text,
        history: _messages.sublist(0, _messages.length - 1), // 不包含刚发的这条,那条是通过message参数单独传的
        profile: widget.profileStore.profile,
        personalInfo: widget.profileStore.personalInfo,
      );
      setState(() => _messages.add(ChatMessageDto(role: 'assistant', message: reply)));
    } catch (e) {
      setState(() => _messages.add(ChatMessageDto(role: 'assistant', message: "Sorry, I couldn't reply just now. Please try again.")));
    } finally {
      setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.aiStore.settings;
    final iconOption = aiIconByKey(settings.iconKey);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(backgroundColor: iconOption.color, radius: 16, child: Icon(iconOption.icon, size: 18, color: Colors.white)),
            const SizedBox(width: 10),
            Text(settings.name),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _EmptyState(name: settings.name)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) => _ChatBubble(message: _messages[i], iconOption: iconOption),
                  ),
          ),
          if (_sending) const Padding(padding: EdgeInsets.only(bottom: 4), child: Text('Typing…', style: TextStyle(color: Colors.grey))),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(hintText: 'Ask about fitness or your plan…', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))), contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(onPressed: _sending ? null : _send, icon: const Icon(Icons.send)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String name;
  const _EmptyState({required this.name});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Say hi to $name! Ask a fitness question, or tell me if you want to adjust your plan.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
        ),
      );
}

class _ChatBubble extends StatelessWidget {
  final ChatMessageDto message;
  final AiIconOption iconOption;
  const _ChatBubble({required this.message, required this.iconOption});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final bubbleColor = isUser ? Theme.of(context).colorScheme.primary : Colors.grey.shade200;
    final textColor = isUser ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(backgroundColor: iconOption.color, radius: 14, child: Icon(iconOption.icon, size: 16, color: Colors.white)),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: bubbleColor, borderRadius: BorderRadius.circular(16)),
              child: Text(message.message, style: TextStyle(color: textColor)),
            ),
          ),
        ],
      ),
    );
  }
}
