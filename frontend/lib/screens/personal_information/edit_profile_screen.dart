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

  late String selectedGoal = widget.store.profile.goal;
  late String selectedLifestyle = widget.store.profile.lifestyle;
  late final Set<String> selectedLocations = widget.store.profile.exerciseLocation.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  late final Set<String> selectedCarefulAreas = widget.store.personalInfo.injuries.map((e) => e.replaceFirst(RegExp(r' \(sensitive area\)$'), '')).toSet();
  late final Set<String> selectedPostureIssues = widget.store.personalInfo.postureIssues.toSet();
  late final Set<String> selectedSurgeries = widget.store.personalInfo.surgeryHistory.map((e) => e.replaceFirst(RegExp(r' surgery$'), '')).toSet();
  late final Set<String> selectedHabits = widget.store.profile.exerciseHabit.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  late final Set<String> selectedEquipment = widget.store.personalInfo.availableEquipment.toSet();

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
    final ageValue = int.tryParse(age.text) ?? 0;
    final heightValue = double.tryParse(height.text) ?? 0;
    final startValue = double.tryParse(startWeight.text) ?? 0;
    final targetValue = double.tryParse(targetWeight.text) ?? 0;
    if (name.text.trim().isEmpty) { _validationError('Please enter your name.'); return; }
    if (ageValue < 13 || ageValue > 120) { _validationError('Please enter an age between 13 and 120.'); return; }
    if (sex.isEmpty) { _validationError('Please select your sex.'); return; }
    if (heightValue <= 0) { _validationError('Height must be greater than 0.'); return; }
    if (startValue <= 0) { _validationError('Initial weight must be greater than 0.'); return; }
    if (targetValue <= 0) { _validationError('Target weight must be greater than 0.'); return; }
    if (selectedGoal.isEmpty) { _validationError('Please select your goal.'); return; }
    if (selectedLifestyle.isEmpty) { _validationError('Please select your lifestyle.'); return; }
    if (selectedLocations.isEmpty) { _validationError('Please select at least one exercise location.'); return; }
    setState(() => _saving = true);
    final profile = UserProfile(
      name: name.text.trim(),
      age: int.tryParse(age.text) ?? 0,
      sex: sex,
      heightCm: double.tryParse(height.text) ?? 0,
      startWeightKg: double.tryParse(startWeight.text) ?? 0,
      targetWeightKg: targetValue,
      goal: selectedGoal,
      lifestyle: selectedLifestyle,
      exerciseFrequencyPerWeek: int.tryParse(frequency.text) ?? 0,
      exerciseDurationMinutes: int.tryParse(duration.text) ?? 0,
      exerciseHabit: selectedHabits.join(', '),
      exerciseLocation: selectedLocations.join(', '),
    );
    final personalInfo = UserPersonalInfo(
      injuries: selectedCarefulAreas.where((e) => e != 'None').map((e) => '$e (sensitive area)').toList(),
      availableEquipment: selectedEquipment.toList(),
      postureIssues: selectedPostureIssues.where((e) => e != 'None').toList(),
      surgeryHistory: selectedSurgeries.where((e) => e != 'None').map((e) => '$e surgery').toList(),
      // 这个表单没有UI可以改训练星期几/末次经期,原样带回去,避免保存时被静默清空。
      exercisesToAvoid: widget.store.personalInfo.exercisesToAvoid,
      lastPeriodDate: widget.store.personalInfo.lastPeriodDate,
      workoutWeekdays: widget.store.personalInfo.workoutWeekdays,
    );

    try {
      await ApiService().saveMyProfile(profile: profile, personalInfo: personalInfo, accessToken: widget.store.accessToken);
      widget.store.save(profile: profile, personalInfo: personalInfo);
      if (mounted) {
        showAppToast(context, 'Profile updated');
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) showAppToast(context, 'Could not save profile: ${error.toString().replaceFirst('Exception: ', '')}', isError: true);
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
              _sectionTitle('Basic information', Icons.person_outline),
              _label('Name'),
              TextField(controller: name),
              _label('Sex'),
              Wrap(
                spacing: 10,
                children: {'Female': 'female', 'Male': 'male', 'Others': 'other'}.entries.map((entry) {
                  final selected = sex == entry.value;
                  return ChoiceChip(label: Text(entry.key), selected: selected, onSelected: (_) => setState(() => sex = entry.value));
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
              _sectionTitle('Goal and activity', Icons.flag_outlined),
              _label('Goal'),
              _singleChoice(['Lose weight', 'Build muscle', 'Maintain weight'], selectedGoal, (value) => setState(() { selectedGoal = value; goal.text = value; })),
              _label('Lifestyle'),
              _singleChoice(['Barely move', 'Light exercise 1-2x/week', 'Exercise 3-4x/week', 'Exercise 5+ times/week', 'Intense daily exercise'], selectedLifestyle, (value) => setState(() { selectedLifestyle = value; lifestyle.text = value; })),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Days / week'), TextField(controller: frequency, keyboardType: TextInputType.number)])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Minutes / session'), TextField(controller: duration, keyboardType: TextInputType.number)])),
              ]),
              _label('Exercise habits'),
              _multiChoice(['Jogging', 'Running', 'Swimming', 'Cycling', 'Hiking', 'Basketball', 'Badminton', 'Tennis', 'Football', 'Other'], selectedHabits, () => setState(() => habit.text = selectedHabits.join(', '))),
              _label('Exercise location'),
              _multiChoice(['Home', 'Gym', 'Outdoors'], selectedLocations, () => setState(() => location.text = selectedLocations.join(', '))),
              const SizedBox(height: 12),
              _sectionTitle('Health and equipment', Icons.health_and_safety_outlined),
              _label('Injured / sensitive areas'),
              _noneAwareChoice(['None', 'Back', 'Knee', 'Shoulder', 'Wrist', 'Ankle', 'Neck', 'Hip'], selectedCarefulAreas),
              _label('Available equipment'),
              _multiChoice(['Dumbbells', 'Yoga mat', 'Resistance band', 'Kettlebell', 'Stability ball', 'Foam roller', 'Pull-up bar', 'Other', 'Treadmill', 'Machines', 'Free weights', 'Stationary bike', 'Cable machine', 'Smith machine', 'Bench', 'Rowing machine'], selectedEquipment, () => setState(() => equipment.text = selectedEquipment.join(', '))),
              _label('Posture issues'),
              _noneAwareChoice(['None', 'Rounded shoulders', 'Hunched back', 'Pelvic tilt', 'Flat feet'], selectedPostureIssues),
              _label('Past surgeries'),
              _noneAwareChoice(['None', 'Knee', 'Shoulder', 'Spine', 'Abdominal', 'Heart'], selectedSurgeries),
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

  Widget _sectionTitle(String title, IconData icon) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Row(children: [
          Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        ]),
      );

  Widget _label(String text) => Padding(padding: const EdgeInsets.only(top: 16, bottom: 8), child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)));

  void _validationError(String message) => showAppToast(context, message, isError: true);

  Widget _singleChoice(List<String> options, String selected, ValueChanged<String> onSelected) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((option) => ChoiceChip(label: Text(option), selected: selected == option, onSelected: (_) => onSelected(option))).toList(),
      );

  Widget _multiChoice(List<String> options, Set<String> selected, VoidCallback onChanged) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((option) => FilterChip(
              label: Text(option),
              selected: selected.contains(option),
              onSelected: (value) {
                if (value) {
                  selected.add(option);
                } else {
                  selected.remove(option);
                }
                onChanged();
              },
            )).toList(),
      );

  Widget _noneAwareChoice(List<String> options, Set<String> selected) => _multiChoice(options, selected, () {
        if (selected.length > 1) selected.remove('None');
        setState(() {});
      });
}
