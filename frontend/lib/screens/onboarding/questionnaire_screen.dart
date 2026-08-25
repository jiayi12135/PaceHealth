import 'package:flutter/material.dart';
import '../../models/profile.dart';
import '../../services/api_service.dart';
import '../../state/ai_assistant_store.dart';
import '../../state/profile_store.dart';
import '../../theme.dart';
import '../plan/plan_generating_screen.dart';
import '../../widgets/app_toast.dart';

/// AI伙伴的选项(按草图:猫/狗/狼,各有名字和性格,说话语气会跟着性格走)。
/// 动物形象暂时用emoji代替,之后可以换成插画图片。
class _Companion {
  final String key, emoji, name, personality, iconKey;
  const _Companion({required this.key, required this.emoji, required this.name, required this.personality, required this.iconKey});
}

const _companions = [
  _Companion(key: 'cat', emoji: '🐱', name: 'Mimi', personality: 'Playful & cheeky', iconKey: 'paw'),
  _Companion(key: 'dog', emoji: '🐶', name: 'Buddy', personality: 'Loyal & encouraging', iconKey: 'heart'),
  _Companion(key: 'wolf', emoji: '🐺', name: 'Luna', personality: 'Fierce & focused', iconKey: 'bolt'),
];

class QuestionnaireScreen extends StatefulWidget {
  final ProfileStore store;
  const QuestionnaireScreen({super.key, required this.store});
  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireState();
}

class _QuestionnaireState extends State<QuestionnaireScreen> {
  static const _totalSteps = 9;
  int step = 0;
  bool _saving = false;

  // Step 0: companion
  _Companion? companion;

  // Step 1: basics
  final name = TextEditingController();
  final age = TextEditingController();
  final height = TextEditingController();
  final start = TextEditingController();
  String sex = '';

  // Step 2: goal
  String goal = '';
  double targetWeight = 60;
  final Set<String> muscleFocus = {};

  // Step 3 & 4: experience + activity
  String experience = '';
  String activity = '';

  // Step 5: location & equipment
  final Set<String> locations = {};
  final Set<String> homeEquipment = {};
  final Set<String> gymEquipment = {};
  final Set<String> outdoorActivities = {};
  String eatingLocation = '';

  // Step 6: careful areas + posture + surgery
  final Set<String> carefulAreas = {};
  final Set<String> postureIssues = {};
  final Set<String> surgeryHistory = {};

  // Step 7: schedule — 用户直接选星期几,每周次数由选中的天数推出来
  final Set<String> workoutDays = {};
  final minutes = TextEditingController(text: '45');
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void dispose() {
    name.dispose();
    age.dispose();
    height.dispose();
    start.dispose();
    minutes.dispose();
    super.dispose();
  }

  /// 每一步吉祥物说的话。三个伙伴性格不同,从选完伙伴那一步(step 1)开始,
  /// 每一步问同一件事,但语气都按各自性格走到底,而不是只在个别步骤有差异。
  static const Map<String, List<String>> _companionLines = {
    // 🐱 Mimi — playful & cheeky: 用"~"、emoji、口语化拼写
    'cat': [
      'Let me know more abt u… 💕',
      "Ooh, what's the goal? Let's make it fun! 🐾",
      'Mew~ how much have you trained before?',
      'How much do you move around, hm? Curious cat here 👀',
      "Where do we get to play — home, gym, outside? And what toys (equipment) do you have? 🧶",
      "Any spots I should be gentle with? Tell me so I don't pounce too hard 🐾",
      "How many days can you play with me each week? Don't be shy~",
      'All done~ let me double check! 🐾',
    ],
    // 🐶 Buddy — loyal & encouraging: 温暖、鼓励、感叹号
    'dog': [
      "Tell me about yourself — I'm listening! 🐶",
      "What's your goal? I'll cheer you on every step of the way!",
      "How much have you trained before? No wrong answers — I'm proud of you either way!",
      'How active are you day to day? Every bit counts!',
      "Where do you like to move, and what gear do you have? Let's work with what you've got!",
      'Anything I should watch out for? Your safety comes first with me.',
      "How many days a week can we train together? I'll be here rain or shine!",
      "Great job getting this far! Let's double-check everything together.",
    ],
    // 🐺 Luna — fierce & focused: 简短、命令式、目标导向
    'wolf': [
      "Tell me who I'm training.",
      "What's the mission? We'll build the plan around it.",
      'State your experience level. I need the truth, not modesty.',
      'How active are you? Give it to me straight.',
      "Where do you train, and what gear's available? I plan around what you've got.",
      'Any weak points I need to protect? Speak now.',
      'How many days can you commit? Discipline starts here.',
      'Final check before we begin. Review it.',
    ],
  };

  String get _bubbleText {
    if (step == 0 || companion == null) {
      return "Hi! I'll be your health buddy. Pick me — or one of my friends!";
    }
    final lines = _companionLines[companion!.key]!;
    return lines[(step - 1).clamp(0, lines.length - 1)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: step == 0 ? null : AppBar(leading: BackButton(onPressed: () => setState(() => step--)), title: const Text('')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (step > 0) _MascotBubble(emoji: companion?.emoji ?? '🐾', text: _bubbleText),
              const SizedBox(height: 12),
              Expanded(child: SingleChildScrollView(child: _content())),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(value: (step + 1) / _totalSteps, minHeight: 8, backgroundColor: Colors.grey.shade200),
                      ),
                    ),
                  ),
                  FloatingActionButton.small(
                    heroTag: 'questionnaire_next',
                    onPressed: _saving ? null : _next,
                    child: _saving
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(step == _totalSteps - 1 ? Icons.check : Icons.arrow_forward),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content() {
    switch (step) {
      case 0:
        return _companionStep();
      case 1:
        return _basicsStep();
      case 2:
        return _goalStep();
      case 3:
        return _choiceCards('experience', ['Beginner', 'Intermediate', 'Intense'], experience, (v) => experience = v, descriptions: const {
          'Beginner': 'New to exercise, or coming back after a long break',
          'Intermediate': 'I exercise on and off and know the basics',
          'Intense': 'Training is already part of my routine',
        });
      case 4:
        return _choiceCards('activity', ['Barely move', 'Light exercise 1-2x/week', 'Exercise 3-4x/week', 'Exercise 5+ times/week', 'Intense daily exercise'], activity, (v) => activity = v);
      case 5:
        return _locationStep();
      case 6:
        return _carefulStep();
      case 7:
        return _scheduleStep();
      default:
        return _review();
    }
  }

  // ---------- Step 0: companion ----------
  Widget _companionStep() => Column(
        children: [
          const SizedBox(height: 8),
          _MascotBubble(emoji: companion?.emoji ?? '👋', text: _bubbleText),
          const SizedBox(height: 12),
          // 大只的吉祥物形象(带一个简单的弹跳动画,后续可换成真正的动画插画)
          TweenAnimationBuilder<double>(
            key: ValueKey(companion?.key ?? 'none'),
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
            child: Text(companion?.emoji ?? '🐾', style: const TextStyle(fontSize: 110)),
          ),
          const SizedBox(height: 16),
          ..._companions.map((c) {
            final selected = companion?.key == c.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SelectableCard(
                selected: selected,
                onTap: () => setState(() => companion = c),
                child: Row(
                  children: [
                    Text(c.emoji, style: const TextStyle(fontSize: 34)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          Text(c.personality, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        ],
                      ),
                    ),
                    if (selected) Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                  ],
                ),
              ),
            );
          }),
        ],
      );

  // ---------- Step 1: basics ----------
  Widget _basicsStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Name'),
          TextField(controller: name, decoration: const InputDecoration(hintText: 'What should I call you?')),
          _fieldLabel('Gender'),
          Wrap(
            spacing: 10,
            children: ['Female', 'Male', 'Other'].map((option) {
              final selected = sex == option;
              return ChoiceChip(
                label: Text(
                  option,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? Theme.of(context).colorScheme.primary : const Color(0xFF3A2E28),
                  ),
                ),
                selected: selected,
                onSelected: (_) => setState(() => sex = option),
                backgroundColor: Colors.white,
                selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.16),
                side: BorderSide(color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              );
            }).toList(),
          ),
          _fieldLabel('Age'),
          TextField(controller: age, keyboardType: TextInputType.number),
          _fieldLabel('Height (cm)'),
          TextField(controller: height, keyboardType: TextInputType.number),
          _fieldLabel('Weight (kg)'),
          TextField(controller: start, keyboardType: TextInputType.number),
        ],
      );

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );

  // ---------- Step 2: goal ----------
  Widget _goalStep() {
    final startW = double.tryParse(start.text) ?? 60;
    // 减重目标的目标体重不能超过前面填写的当前体重(至少要比现在轻1kg才算"减重")。
    // 如果体重还没填/填得不合理(<=31),先不设上限,等填了再收紧。
    final maxLoseTarget = startW > 31 ? startW - 1 : 300.0;
    return Column(
      children: [
        _SelectableCard(
          selected: goal == 'Lose weight',
          onTap: () => setState(() {
            goal = 'Lose weight';
            if (targetWeight > maxLoseTarget) targetWeight = (startW > 31 ? startW - 5 : maxLoseTarget).clamp(30, maxLoseTarget);
          }),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Lose Weight', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text('Slim down at a steady, healthy pace', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              if (goal == 'Lose weight') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(child: Text('Target weight (kg)', style: TextStyle(fontWeight: FontWeight.w600))),
                    IconButton(onPressed: () => setState(() => targetWeight = (targetWeight - 1).clamp(30, maxLoseTarget)), icon: const Icon(Icons.remove_circle_outline)),
                    Text(targetWeight.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                    IconButton(onPressed: () => setState(() => targetWeight = (targetWeight + 1).clamp(30, maxLoseTarget)), icon: const Icon(Icons.add_circle_outline)),
                  ],
                ),
                if (startW > 31)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Must be less than your current weight (${startW.toStringAsFixed(0)} kg)', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SelectableCard(
          selected: goal == 'Build muscle',
          onTap: () => setState(() => goal = 'Build muscle'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Build Muscle', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text('Get stronger and more toned', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              if (goal == 'Build muscle') ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['Arm', 'Leg', 'Butt', 'Chest', 'Back', 'Core'].map((area) {
                    final selected = muscleFocus.contains(area);
                    return FilterChip(
                      label: Text(area),
                      selected: selected,
                      onSelected: (on) => setState(() => on ? muscleFocus.add(area) : muscleFocus.remove(area)),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SelectableCard(
          selected: goal == 'Maintain weight',
          onTap: () => setState(() => goal = 'Maintain weight'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Maintain Weight', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text('Stay healthy and keep my current shape', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- Steps 3/4: single-choice card lists ----------
  Widget _choiceCards(String _, List<String> options, String current, ValueChanged<String> set, {Map<String, String>? descriptions}) => Column(
        children: options.map((option) {
          final selected = current == option;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SelectableCard(
              selected: selected,
              onTap: () => setState(() => set(option)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(option, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        if (descriptions?[option] != null) Text(descriptions![option]!, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                  ),
                  Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade400),
                ],
              ),
            ),
          );
        }).toList(),
      );

  // ---------- Step 5: location & equipment ----------
  Widget _locationStep() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: paceHealthAccents[1].withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              const Text('💡', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(child: Text("Don't know what an equipment is? You can take/upload a photo later and I'll identify it for you.", style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700))),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _locationSection('🏠', 'Home', 'Home', ['Dumbbells', 'Yoga mat', 'Resistance band', 'Kettlebell', 'None'], homeEquipment),
        const SizedBox(height: 12),
        _locationSection('🏋️', 'Gym', 'Gym', ['Treadmill', 'Machines', 'Free weights', 'Stationary bike'], gymEquipment),
        const SizedBox(height: 12),
        _locationSection('🌳', 'Outdoor', 'Outdoors', ['Jogging', 'Swimming', 'Cycling', 'Hiking'], outdoorActivities),
        _fieldLabel('Where do you usually eat?'),
        Wrap(
          spacing: 10,
          children: ['Home', 'Outside', 'Both'].map((option) {
            final selected = eatingLocation == option;
            return ChoiceChip(
              label: Text(option),
              selected: selected,
              onSelected: (_) => setState(() => eatingLocation = option),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _locationSection(String emoji, String label, String value, List<String> chips, Set<String> selectedChips) {
    final selected = locations.contains(value);
    return _SelectableCard(
      selected: selected,
      onTap: () => setState(() => selected ? locations.remove(value) : locations.add(value)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              Icon(selected ? Icons.check_circle : Icons.circle_outlined, color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade400),
            ],
          ),
          if (selected) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips.map((chip) {
                final chipSelected = selectedChips.contains(chip);
                return FilterChip(
                  label: Text(chip),
                  selected: chipSelected,
                  onSelected: (on) => setState(() => on ? selectedChips.add(chip) : selectedChips.remove(chip)),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ---------- Step 6: careful areas + posture + surgery ----------
  Widget _carefulStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Injured / sensitive areas'),
          _noneAwareChips(const ['None', 'Back', 'Knee', 'Shoulder', 'Wrist', 'Ankle', 'Neck', 'Hip'], carefulAreas),
          _fieldLabel('Posture issues'),
          _noneAwareChips(const ['None', 'Rounded shoulders', 'Hunched back', 'Pelvic tilt', 'Flat feet'], postureIssues),
          _fieldLabel('Past surgeries'),
          _noneAwareChips(const ['None', 'Knee', 'Shoulder', 'Spine', 'Abdominal', 'Heart'], surgeryHistory),
        ],
      );

  /// 一组带"None"选项的多选chips:选None清空其他,选任何其他项就取消None的视觉状态。
  Widget _noneAwareChips(List<String> options, Set<String> selectedSet) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: options.map((option) {
          final selected = option == 'None' ? selectedSet.isEmpty : selectedSet.contains(option);
          return FilterChip(
            label: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: Text(option)),
            selected: selected,
            onSelected: (_) => setState(() {
              if (option == 'None') {
                selectedSet.clear();
              } else {
                selected ? selectedSet.remove(option) : selectedSet.add(option);
              }
            }),
          );
        }).toList(),
      );

  // ---------- Step 7: schedule ----------
  Widget _scheduleStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Which days do you want to work out?'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _weekdays.map((day) {
              final selected = workoutDays.contains(day);
              return FilterChip(
                label: Text(day),
                selected: selected,
                onSelected: (on) => setState(() => on ? workoutDays.add(day) : workoutDays.remove(day)),
              );
            }).toList(),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              workoutDays.isEmpty ? 'Pick at least one day' : '${workoutDays.length} day${workoutDays.length > 1 ? 's' : ''} per week',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ),
          _fieldLabel('Minutes per session'),
          TextField(controller: minutes, keyboardType: TextInputType.number),
        ],
      );

  // ---------- Step 8: review ----------
  Widget _review() {
    final rows = <MapEntry<String, String>>[
      MapEntry('Companion', companion == null ? '-' : '${companion!.emoji} ${companion!.name}'),
      MapEntry('Name', name.text.trim()),
      MapEntry('Basics', '${age.text} yrs · $sex · ${height.text} cm · ${start.text} kg'),
      MapEntry('Goal', goal == 'Lose weight' ? 'Lose weight → ${targetWeight.toStringAsFixed(0)} kg' : (goal == 'Build muscle' && muscleFocus.isNotEmpty ? 'Build muscle (${muscleFocus.join(', ')})' : goal)),
      MapEntry('Experience', experience),
      MapEntry('Activity', activity),
      MapEntry('Location', locations.join(', ')),
      if (homeEquipment.isNotEmpty || gymEquipment.isNotEmpty) MapEntry('Equipment', {...homeEquipment, ...gymEquipment}.where((e) => e != 'None').join(', ')),
      if (outdoorActivities.isNotEmpty) MapEntry('Outdoor', outdoorActivities.join(', ')),
      MapEntry('Careful with', carefulAreas.isEmpty ? 'None' : carefulAreas.join(', ')),
      if (postureIssues.isNotEmpty) MapEntry('Posture', postureIssues.join(', ')),
      if (surgeryHistory.isNotEmpty) MapEntry('Surgeries', surgeryHistory.join(', ')),
      if (eatingLocation.isNotEmpty) MapEntry('Eats at', eatingLocation),
      MapEntry('Schedule', '${workoutDays.join(', ')} · ${minutes.text} min'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: rows
              .map((row) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 110, child: Text(row.key, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
                        Expanded(child: Text(row.value.isEmpty ? 'Not provided' : row.value, style: const TextStyle(fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  // ---------- navigation & submit ----------
  Future<void> _next() async {
    switch (step) {
      case 0:
        if (companion == null) return _error('Pick a companion to continue!');
      case 1:
        final ageValue = int.tryParse(age.text) ?? 0;
        final heightValue = double.tryParse(height.text) ?? 0;
        final startValue = double.tryParse(start.text) ?? 0;
        if (name.text.trim().isEmpty || sex.isEmpty || ageValue <= 0 || heightValue <= 0 || startValue <= 0) {
          return _error('Please complete all the fields.');
        }
      case 2:
        if (goal.isEmpty) return _error('Please choose a goal.');
      case 3:
        if (experience.isEmpty) return _error('Please choose your experience level.');
      case 4:
        if (activity.isEmpty) return _error('Please choose your activity level.');
      case 5:
        if (locations.isEmpty) return _error('Please pick at least one location.');
      case 7:
        if (workoutDays.isEmpty) return _error('Please pick at least one workout day.');
        if ((int.tryParse(minutes.text) ?? 0) <= 0) return _error('Please enter minutes per session.');
    }

    if (step == _totalSteps - 1) {
      await _finish();
    } else {
      setState(() => step++);
    }
  }

  Future<void> _finish() async {
    final startValue = double.tryParse(start.text) ?? 0;
    final goalText = goal == 'Build muscle' && muscleFocus.isNotEmpty ? 'Build muscle (focus: ${muscleFocus.join(', ')})' : goal;

    final profile = UserProfile(
      name: name.text.trim(),
      age: int.tryParse(age.text) ?? 0,
      sex: sex.toLowerCase(),
      heightCm: double.tryParse(height.text) ?? 0,
      startWeightKg: startValue,
      // 减重目标用用户选的目标体重;增肌/维持没让用户填目标体重,就用当前体重占位
      targetWeightKg: goal == 'Lose weight' ? targetWeight : startValue,
      goal: goalText,
      lifestyle: '$experience level · $activity${eatingLocation.isEmpty ? '' : ' · usually eats: $eatingLocation'}',
      exerciseFrequencyPerWeek: workoutDays.length,
      exerciseDurationMinutes: int.tryParse(minutes.text) ?? 0,
      exerciseHabit: outdoorActivities.join(', '),
      exerciseLocation: locations.join(', '),
    );
    // 问卷选的星期几,按kWeekdays的固定顺序排好(不是用户点选的顺序)——之后生成计划、
    // 排到日历、以及经期感知逻辑都依赖这个顺序跟Day 1/2/3一一对应。
    final orderedWorkoutWeekdays = _weekdays.where(workoutDays.contains).toList();
    final info = UserPersonalInfo(
      availableEquipment: {...homeEquipment, ...gymEquipment}.where((e) => e != 'None').toList(),
      injuries: carefulAreas.map((a) => '$a (sensitive area)').toList(),
      postureIssues: postureIssues.toList(),
      surgeryHistory: surgeryHistory.map((s) => '$s surgery').toList(),
      workoutWeekdays: orderedWorkoutWeekdays,
    );

    setState(() => _saving = true);
    try {
      await ApiService().saveMyProfile(profile: profile, personalInfo: info, accessToken: widget.store.accessToken);
      // 把选择的伙伴存成AI助手的名字/头像(本地),chat页面会用它
      if (companion != null) {
        await AiAssistantStore().save(name: companion!.name, iconKey: companion!.iconKey);
      }
      widget.store.workoutDays = orderedWorkoutWeekdays;
      widget.store.save(profile: profile, personalInfo: info);
      // 记一下经验等级+现在这个时间点(给Home页"预计几周达到目标"的进度条用)——
      // 只在第一次问卷完成时设起点,不是核心数据所以不经过backend。
      await widget.store.saveGoalMeta(experience: experience);
      // 问卷填完先过渡到一个loading页,在那边生成plan(带着刚存的profile——伤病/
      // 器材都在里面),生成完直接停在Plan tab,而不是回Home再让用户自己点进去。
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PlanGeneratingScreen(store: widget.store)));
    } catch (e) {
      if (mounted) _error('Could not save your profile. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _error(String message) => showAppToast(context, message, isError: true);
}

/// 吉祥物头像+对话气泡(按草图:左边小头像,右边一个圆角气泡)
class _MascotBubble extends StatelessWidget {
  final String emoji;
  final String text;
  const _MascotBubble({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(text, style: const TextStyle(fontSize: 14.5, height: 1.3)),
            ),
          ),
        ],
      );
}

/// 可选中的大卡片,选中时高亮边框(问卷里所有卡片选项共用)
class _SelectableCard extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  const _SelectableCard({required this.selected, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? primary.withOpacity(0.07) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? primary : Colors.grey.shade200, width: selected ? 1.8 : 1),
        ),
        child: child,
      ),
    );
  }
}
