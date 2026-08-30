import 'package:flutter/material.dart';
import '../../state/profile_store.dart';
import '../../widgets/section_card.dart';
import 'edit_profile_screen.dart';

class PersonalInformationScreen extends StatefulWidget {
  final ProfileStore store;
  const PersonalInformationScreen({super.key, required this.store});

  @override
  State<PersonalInformationScreen> createState() => _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  Future<void> _edit() async {
    // 编辑页保存成功后pop(context, true)——用await接住它,回来后setState一下,
    // 这个页面本身是StatelessWidget风格的只读展示,不会自动感知store.profile变了。
    await Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfileScreen(store: widget.store)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.store.profile;
    final info = widget.store.personalInfo;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Information'),
        actions: [IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined), onPressed: _edit)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SectionCard(title: 'Basic Information', icon: Icons.person_outline, children: [
            InfoRow(label: 'Name', value: p.name),
            InfoRow(label: 'Age', value: '${p.age}'),
            InfoRow(label: 'Sex', value: p.sex),
          ]),
          const SizedBox(height: 12),
          SectionCard(title: 'Body Measurements', icon: Icons.monitor_weight_outlined, children: [
            InfoRow(label: 'Height', value: '${p.heightCm} cm'),
            InfoRow(label: 'Starting weight', value: '${p.startWeightKg} kg'),
            InfoRow(label: 'Target weight', value: '${p.targetWeightKg} kg'),
          ]),
          const SizedBox(height: 12),
          SectionCard(title: 'Goal', icon: Icons.flag_outlined, children: [
            InfoRow(label: 'Goal', value: p.goal),
          ]),
          const SizedBox(height: 12),
          SectionCard(title: 'Lifestyle', icon: Icons.directions_walk_outlined, children: [
            InfoRow(label: 'Lifestyle', value: p.lifestyle),
          ]),
          const SizedBox(height: 12),
          SectionCard(title: 'Exercise Routine', icon: Icons.fitness_center_outlined, children: [
            InfoRow(label: 'Frequency', value: '${p.exerciseFrequencyPerWeek} times per week'),
            InfoRow(label: 'Duration', value: '${p.exerciseDurationMinutes} min'),
            InfoRow(label: 'Exercise habit', value: p.exerciseHabit),
            InfoRow(label: 'Location', value: p.exerciseLocation),
          ]),
          const SizedBox(height: 12),
          SectionCard(title: 'Equipment', icon: Icons.sports_gymnastics_outlined, children: [
            InfoRow(label: 'Equipment', value: info.availableEquipment.isEmpty ? 'None' : info.availableEquipment.join(', ')),
          ]),
          const SizedBox(height: 12),
          SectionCard(title: 'Physical Considerations', icon: Icons.health_and_safety_outlined, children: [
            InfoRow(label: 'Injuries', value: info.injuries.isEmpty ? 'None' : info.injuries.join(', ')),
            InfoRow(label: 'Posture issues', value: info.postureIssues.isEmpty ? 'None' : info.postureIssues.join(', ')),
            InfoRow(label: 'Past surgeries', value: info.surgeryHistory.isEmpty ? 'None' : info.surgeryHistory.join(', ')),
          ]),
        ],
      ),
    );
  }
}
