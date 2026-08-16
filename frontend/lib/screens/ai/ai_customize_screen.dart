import 'package:flutter/material.dart';
import '../../models/ai_assistant.dart';
import '../../state/ai_assistant_store.dart';

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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.aiStore.settings.name);
    _selectedIconKey = widget.aiStore.settings.iconKey;
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved!')));
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
            child: CircleAvatar(radius: 44, backgroundColor: selected.color, child: Icon(selected.icon, size: 40, color: Colors.white)),
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
            children: kAiIconOptions.map((option) {
              final isSelected = option.key == _selectedIconKey;
              return GestureDetector(
                onTap: () => setState(() => _selectedIconKey = option.key),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: isSelected ? option.color : Colors.transparent, width: 3),
                  ),
                  child: CircleAvatar(radius: 28, backgroundColor: option.color, child: Icon(option.icon, color: Colors.white)),
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
