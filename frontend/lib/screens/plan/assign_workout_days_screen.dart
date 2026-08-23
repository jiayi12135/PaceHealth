import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../state/profile_store.dart';

/// 计划一生成完就问用户:每个"Day 1/Day 2…"具体想放在星期几。
/// 默认建议用问卷里选过的训练日(按顺序对上),用户可以在这里改。
class AssignWorkoutDaysScreen extends StatefulWidget {
  final ProfileStore store;
  final FitnessPlan plan;
  // 分配存进store之后要做什么——onboarding流程里是接着进AppShell,
  // 从Plan页面重新生成进来的话是pop回去就行。
  final VoidCallback onDone;
  const AssignWorkoutDaysScreen({super.key, required this.store, required this.plan, required this.onDone});

  @override
  State<AssignWorkoutDaysScreen> createState() => _AssignWorkoutDaysScreenState();
}

class _AssignWorkoutDaysScreenState extends State<AssignWorkoutDaysScreen> {
  late final List<String> _planDays = _uniqueOrderedDays();
  late final Map<String, String> _selected = _defaults();

  List<String> _uniqueOrderedDays() {
    final seen = <String>[];
    for (final exercise in widget.plan.exercises) {
      if (!seen.contains(exercise.day)) seen.add(exercise.day);
    }
    return seen;
  }

  Map<String, String> _defaults() {
    final map = <String, String>{};
    final existing = widget.store.workoutDayAssignments;
    final suggested = widget.store.workoutDays;
    for (var i = 0; i < _planDays.length; i++) {
      final planDay = _planDays[i];
      map[planDay] = existing[planDay] ?? (i < suggested.length ? suggested[i] : kWeekdays[i % 7]);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('When do you want to train?'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pick a day for each part of your plan.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: _planDays.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, i) {
                    final planDay = _planDays[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(planDay, style: const TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: kWeekdays.map((weekday) {
                                final selected = _selected[planDay] == weekday;
                                // 同一个星期几在别的Day里已经被选了的话就不让重复选,
                                // 避免两个训练日撞在同一天。
                                final takenElsewhere = _selected.entries.any((e) => e.key != planDay && e.value == weekday);
                                return ChoiceChip(
                                  label: Text(weekday),
                                  selected: selected,
                                  onSelected: takenElsewhere ? null : (_) => setState(() => _selected[planDay] = weekday),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  widget.store.setWorkoutDayAssignments(_selected);
                  widget.onDone();
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
