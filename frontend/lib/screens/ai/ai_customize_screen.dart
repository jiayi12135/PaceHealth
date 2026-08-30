import 'package:flutter/material.dart';
import '../../models/ai_assistant.dart';
import '../../state/ai_assistant_store.dart';
import '../../widgets/app_toast.dart';

/// 让用户给AI起名字、选一个预设头像。保存后本地记住(见 ai_assistant_store.dart)。
class AiCustomizeScreen extends StatefulWidget {
  final AiAssistantStore aiStore;
  const AiCustomizeScreen({super.key, required this.aiStore});

  @override
  State<AiCustomizeScreen> createState() => _AiCustomizeScreenState();
}

class _AiCustomizeScreenState extends State<AiCustomizeScreen> {
  late TextEditingController _nameController;
  late String _selectedIconKey;

  List<AiIconOption> get _petOptions {
    final pet = widget.aiStore.settings.iconKey.startsWith('heart') || widget.aiStore.settings.iconKey.startsWith('dog_') ? 'dog' : widget.aiStore.settings.iconKey.startsWith('bolt') || widget.aiStore.settings.iconKey.startsWith('wolf_') ? 'wolf' : 'cat';
    return List.generate(4, (index) => AiIconOption(key: '${pet}_$index', icon: Icons.circle, color: kAiIconOptions[index + 2].color));
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.aiStore.settings.name);
    _selectedIconKey = widget.aiStore.settings.iconKey.startsWith('cat_') || widget.aiStore.settings.iconKey.startsWith('dog_') || widget.aiStore.settings.iconKey.startsWith('wolf_') ? widget.aiStore.settings.iconKey : '${widget.aiStore.settings.iconKey == 'heart' ? 'dog' : widget.aiStore.settings.iconKey == 'bolt' ? 'wolf' : 'cat'}_0';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim().isEmpty ? 'Coach' : _nameController.text.trim();
    await widget.aiStore.save(name: name, iconKey: _selectedIconKey);
    if (mounted) {
      showAppToast(context, 'Saved!');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = aiIconByKey(_selectedIconKey);

    return Scaffold(
      appBar: AppBar(title: const Text('Customize your AI')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: CircleAvatar(radius: 44, backgroundColor: selected.color, child: Text(aiEmojiByKey(selected.key), style: const TextStyle(fontSize: 40))),
          ),
          const SizedBox(height: 24),
          const Text('Name', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            maxLength: 20,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'e.g. Coach, Ava, Max…'),
          ),
          const SizedBox(height: 16),
          const Text('Icon', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: _petOptions.map((option) {
              final isSelected = option.key == _selectedIconKey;
              return GestureDetector(
                onTap: () => setState(() => _selectedIconKey = option.key),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: isSelected ? option.color : Colors.transparent, width: 3),
                  ),
                  child: CircleAvatar(radius: 28, backgroundColor: option.color, child: Text(aiEmojiByKey(option.key), style: const TextStyle(fontSize: 28))),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          FilledButton(onPressed: _save, child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Save'))),
        ],
      ),
    );
  }
}
