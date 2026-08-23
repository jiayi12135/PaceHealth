import 'package:flutter/material.dart';

/// 结果对象:skipReasons/skipReasonNotes按动作名索引(跟WorkoutSessionScreen里
/// 用exerciseName对应回exercise_log保持一致);timeReason/finishedQuicklyReason是
/// 整个session级别的、只问一次。全部字段都是可选的——用户可以什么都不选直接提交,
/// 或者直接点右上角Skip整个不填。
class WorkoutFeedbackResult {
  final Map<String, String> skipReasons;
  final Map<String, String> skipReasonNotes;
  final String? timeReason;
  final String? timeReasonNote;
  final String? finishedQuicklyReason;
  const WorkoutFeedbackResult({
    this.skipReasons = const {},
    this.skipReasonNotes = const {},
    this.timeReason,
    this.timeReasonNote,
    this.finishedQuicklyReason,
  });
}

// 这几个code要跟backend app/routers/ai.py里的_SKIP_REASON_LABELS一一对应,AI教练读的
// 就是这些code(不是这里的显示文案)。
const _skipReasonOptions = [
  ('too_difficult', 'Too difficult'),
  ('pain_discomfort', 'Pain / discomfort'),
  ('equipment_unavailable', 'Equipment unavailable'),
  ('dont_know_how', "Don't know how to perform it"),
  ('not_enough_space', 'Not enough space'),
  ('other', 'Other'),
];

const _timeReasonOptions = [
  ('needed_more_rest', 'Needed more rest'),
  ('exercise_difficult', 'Exercise was difficult'),
  ('interrupted', 'Interrupted during workout'),
  ('unclear_instructions', 'Instructions were unclear'),
  ('other', 'Other'),
];

const _quickReasonOptions = [
  ('felt_easy', 'Felt too easy'),
  ('wanted_to_save_time', 'Wanted to save time'),
  ('skipped_rest', 'Skipped rest between sets'),
  ('other', 'Not sure, just felt good today'),
];

/// 只有Finish workout时判断这次session"不寻常"才会弹出这一页——按具体触发原因只显示
/// 相关的问题,不是一个大而全的通用表单。每个问题都可以直接跳过不答。
class WorkoutFeedbackScreen extends StatefulWidget {
  final List<String> skippedExerciseNames;
  final bool showTimeQuestion;
  final bool showQuickQuestion;
  const WorkoutFeedbackScreen({super.key, required this.skippedExerciseNames, required this.showTimeQuestion, required this.showQuickQuestion});

  @override
  State<WorkoutFeedbackScreen> createState() => _WorkoutFeedbackScreenState();
}

class _WorkoutFeedbackScreenState extends State<WorkoutFeedbackScreen> {
  final Map<String, String> _skipReasons = {};
  final Map<String, TextEditingController> _skipNotes = {};
  String? _timeReason;
  final _timeNoteController = TextEditingController();
  String? _quickReason;

  @override
  void dispose() {
    _timeNoteController.dispose();
    for (final c in _skipNotes.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _noteControllerFor(String exerciseName) => _skipNotes.putIfAbsent(exerciseName, () => TextEditingController());

  void _submit() {
    final result = WorkoutFeedbackResult(
      skipReasons: _skipReasons,
      skipReasonNotes: {
        for (final entry in _skipReasons.entries)
          if (entry.value == 'other' && (_skipNotes[entry.key]?.text.trim().isNotEmpty ?? false)) entry.key: _skipNotes[entry.key]!.text.trim(),
      },
      timeReason: _timeReason,
      timeReasonNote: _timeReason == 'other' && _timeNoteController.text.trim().isNotEmpty ? _timeNoteController.text.trim() : null,
      finishedQuicklyReason: _quickReason,
    );
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick feedback'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Skip'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            'A couple quick questions so we can fine-tune your plan. Totally optional.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          if (widget.skippedExerciseNames.isNotEmpty) ...[
            Text('Why did you skip these exercises?', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            for (final name in widget.skippedExerciseNames) ...[
              _SkipReasonCard(
                exerciseName: name,
                selected: _skipReasons[name],
                onSelected: (code) => setState(() => _skipReasons[name] = code),
                noteController: _noteControllerFor(name),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 12),
          ],
          if (widget.showTimeQuestion) ...[
            Text('What caused the workout to take longer than expected?', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            _ReasonChips(options: _timeReasonOptions, selected: _timeReason, onSelected: (code) => setState(() => _timeReason = code)),
            if (_timeReason == 'other') ...[
              const SizedBox(height: 8),
              TextField(controller: _timeNoteController, decoration: const InputDecoration(hintText: 'Say a bit more (optional)'), maxLines: 2),
            ],
            const SizedBox(height: 20),
          ],
          if (widget.showQuickQuestion) ...[
            Text('That was fast! Anything to note?', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            _ReasonChips(options: _quickReasonOptions, selected: _quickReason, onSelected: (code) => setState(() => _quickReason = code)),
            const SizedBox(height: 20),
          ],
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: _submit, child: const Text('Submit feedback'))),
        ],
      ),
    );
  }
}

class _SkipReasonCard extends StatelessWidget {
  final String exerciseName;
  final String? selected;
  final ValueChanged<String> onSelected;
  final TextEditingController noteController;
  const _SkipReasonCard({required this.exerciseName, required this.selected, required this.onSelected, required this.noteController});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(exerciseName, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _ReasonChips(options: _skipReasonOptions, selected: selected, onSelected: onSelected),
              if (selected == 'other') ...[
                const SizedBox(height: 8),
                TextField(controller: noteController, decoration: const InputDecoration(hintText: 'Say a bit more (optional)'), maxLines: 2),
              ],
            ],
          ),
        ),
      );
}

class _ReasonChips extends StatelessWidget {
  final List<(String, String)> options;
  final String? selected;
  final ValueChanged<String> onSelected;
  const _ReasonChips({required this.options, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (code, label) in options)
            ChoiceChip(
              label: Text(label),
              selected: selected == code,
              onSelected: (_) => onSelected(code),
            ),
        ],
      );
}
