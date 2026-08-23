import 'package:flutter/material.dart';
import '../../models/profile.dart';
import '../../services/api_service.dart';
import '../../state/profile_store.dart';
import '../../widgets/app_toast.dart';

/// 编辑资料页——问卷是多步骤的引导式流程,这里是给已经填过的人快速改几个字段用的,
/// 所以做成单页表单而不是重走一遍9步问卷。保存走的是跟问卷一样的saveMyProfile接口。
class EditProfileScreen extends StatefulWidget {
  final ProfileStore store;
  const EditProfileScreen({super.key, required this.store});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final name = TextEditingController(text: widget.store.profile.name);
  late final age = TextEditingController(text: widget.store.profile.age > 0 ? '${widget.store.profile.age}' : '');
  late final height = TextEditingController(text: widget.store.profile.heightCm > 0 ? '${widget.store.profile.heightCm}' : '');
  late final startWeight = TextEditingController(text: widget.store.profile.startWeightKg > 0 ? '${widget.store.profile.startWeightKg}' : '');
  late final targetWeight = TextEditingController(text: widget.store.profile.targetWeightKg > 0 ? '${widget.store.profile.targetWeightKg}' : '');
  late final goal = TextEditingController(text: widget.store.profile.goal);
  late final lifestyle = TextEditingController(text: widget.store.profile.lifestyle);
  late final frequency = TextEditingController(text: widget.store.profile.exerciseFrequencyPerWeek > 0 ? '${widget.store.profile.exerciseFrequencyPerWeek}' : '');
  late final duration = TextEditingController(text: widget.store.profile.exerciseDurationMinutes > 0 ? '${widget.store.profile.exerciseDurationMinutes}' : '');
  late final habit = TextEditingController(text: widget.store.profile.exerciseHabit);
  late final location = TextEditingController(text: widget.store.profile.exerciseLocation);
  late String sex = widget.store.profile.sex;

  late final injuries = TextEditingController(text: widget.store.personalInfo.injuries.join(', '));
  late final equipment = TextEditingController(text: widget.store.personalInfo.availableEquipment.join(', '));
  late final posture = TextEditingController(text: widget.store.personalInfo.postureIssues.join(', '));
  late final surgery = TextEditingController(text: widget.store.personalInfo.surgeryHistory.join(', '));

  bool _saving = false;

  @override
  void dispose() {
    for (final c in [name, age, height, startWeight, targetWeight, goal, lifestyle, frequency, duration, habit, location, injuries, equipment, posture, surgery]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _split(String text) => text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Future<void> _save() async {
    setState(() => _saving = true);
    final profile = UserProfile(
      name: name.text.trim(),
      age: int.tryParse(age.text) ?? 0,
      sex: sex,
      heightCm: double.tryParse(height.text) ?? 0,
      startWeightKg: double.tryParse(startWeight.text) ?? 0,
      targetWeightKg: double.tryParse(targetWeight.text) ?? 0,
      goal: goal.text.trim(),
      lifestyle: lifestyle.text.trim(),
      exerciseFrequencyPerWeek: int.tryParse(frequency.text) ?? 0,
      exerciseDurationMinutes: int.tryParse(duration.text) ?? 0,
      exerciseHabit: habit.text.trim(),
      exerciseLocation: location.text.trim(),
    );
    final personalInfo = UserPersonalInfo(
      injuries: _split(injuries.text),
      availableEquipment: _split(equipment.text),
      postureIssues: _split(posture.text),
      surgeryHistory: _split(surgery.text),
    );

    try {
      await ApiService().saveMyProfile(profile: profile, personalInfo: personalInfo, accessToken: widget.store.accessToken);
      widget.store.save(profile: profile, personalInfo: personalInfo);
      if (mounted) {
        showAppToast(context, 'Profile updated');
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) showAppToast(context, "Couldn't save your changes. Please try again.", isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Edit profile')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _label('Name'),
              TextField(controller: name),
              _label('Sex'),
              Wrap(
                spacing: 10,
                children: ['female', 'male', 'other'].map((option) {
                  final selected = sex == option;
                  return ChoiceChip(label: Text(option), selected: selected, onSelected: (_) => setState(() => sex = option));
                }).toList(),
              ),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Age'), TextField(controller: age, keyboardType: TextInputType.number)])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Height (cm)'), TextField(controller: height, keyboardType: TextInputType.number)])),
              ]),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Current weight (kg)'), TextField(controller: startWeight, keyboardType: TextInputType.number)])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Target weight (kg)'), TextField(controller: targetWeight, keyboardType: TextInputType.number)])),
              ]),
              _label('Goal'),
              TextField(controller: goal),
              _label('Lifestyle'),
              TextField(controller: lifestyle),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Days / week'), TextField(controller: frequency, keyboardType: TextInputType.number)])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Minutes / session'), TextField(controller: duration, keyboardType: TextInputType.number)])),
              ]),
              _label('Exercise habits'),
              TextField(controller: habit, decoration: const InputDecoration(hintText: 'e.g. dancing, swimming')),
              _label('Exercise location'),
              TextField(controller: location),
              const SizedBox(height: 12),
              Text('Health details', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              _label('Injured / sensitive areas'),
              TextField(controller: injuries, decoration: const InputDecoration(hintText: 'Comma-separated, e.g. Knee, Back')),
              _label('Available equipment'),
              TextField(controller: equipment, decoration: const InputDecoration(hintText: 'Comma-separated')),
              _label('Posture issues'),
              TextField(controller: posture, decoration: const InputDecoration(hintText: 'Comma-separated')),
              _label('Past surgeries'),
              TextField(controller: surgery, decoration: const InputDecoration(hintText: 'Comma-separated')),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save changes'),
              ),
            ],
          ),
        ),
      );

  Widget _label(String text) => Padding(padding: const EdgeInsets.only(top: 14, bottom: 6), child: Text(text, style: Theme.of(context).textTheme.titleSmall));
}
