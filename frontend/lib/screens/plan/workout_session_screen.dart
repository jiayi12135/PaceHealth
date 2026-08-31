import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../state/profile_store.dart';
import 'workout_feedback_screen.dart';

/// 每个动作在这次训练session里的进度状态。Skipped是可撤销的(参考类的滑动回来能看到
/// 撤销入口),Completed目前不可撤销(需求里只明确说了Skipped要能撤销)。
enum _ExStatus { notStarted, active, completed, skipped }

class _ExerciseRuntime {
  _ExStatus status = _ExStatus.notStarted;
  // 这个动作变成"当前在做"之后,累计了多少秒——不管当时用户是不是正看着这一页
  // (计时器在后台为activeIndex那一个动作走,用户可以自由滑走看别的动作)。
  int activeSeconds = 0;
}

/// 每个动作(不管是力量还是有氧)都给一个预计耗时,用来驱动倒计时+自动前进,也用来在
/// Finish时对比"预计vs实际"。有duration字段(有氧/拉伸)直接用AI给的秒数;力量动作
/// (只有sets/reps)没有现成的时长,这里用一个粗略经验公式估算——纯前端本地计算,
/// 不是AI编的数字,只是给UI一个合理的参考,不需要精确。
int estimatedSeconds(Exercise e) {
  if (e.duration != null) return e.duration!;
  final reps = e.reps ?? 10;
  final sets = e.sets < 1 ? 1 : e.sets;
  const secondsPerRep = 3;
  final workSeconds = sets * reps * secondsPerRep;
  final restSeconds = e.restSeconds * (sets - 1 < 0 ? 0 : sets - 1);
  final total = workSeconds + restSeconds;
  return total < 30 ? 30 : total;
}

String _formatMmSs(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final m = (s ~/ 60).toString().padLeft(2, '0');
  final sec = (s % 60).toString().padLeft(2, '0');
  return '$m:$sec';
}

/// 逐动作全屏训练页:一个动作一页,可以左右滑动预览(滑动本身不算完成)。每个动作有
/// 自己的预计时长倒计时,时间到了自动跳到下一个未完成的动作(哪怕用户当时正滑着看
/// 别的动作,计时器也在后台继续走);也可以随时点Skip跳过或Mark done提前完成。
/// Finish workout时把actual跟planned对比,只有"不寻常"的情况才弹出针对性的反馈问卷。
class WorkoutSessionScreen extends StatefulWidget {
  final ProfileStore store;
  final String day; // AI计划里的day标签,如 'Day 1'
  final String displayDay; // 映射后的星期几,如 'Mon'(没有映射时同day)
  final List<Exercise> exercises;
  const WorkoutSessionScreen({super.key, required this.store, required this.day, required this.displayDay, required this.exercises});

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  late final List<_ExerciseRuntime> _runtime = List.generate(widget.exercises.length, (_) => _ExerciseRuntime());
  final _pageController = PageController();
  final _sessionStopwatch = Stopwatch();
  Timer? _ticker;
  int _currentIndex = 0;
  bool _saving = false;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _sessionStopwatch.start();
    if (_runtime.isNotEmpty) _runtime[0].status = _ExStatus.active;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // 第一个还没完成/没跳过的动作,就是"当前在做的"那一个——计时器只为它走。
  int get _activeIndex => _runtime.indexWhere((r) => r.status != _ExStatus.completed && r.status != _ExStatus.skipped);
  bool get _allDone => _activeIndex == -1;

  void _onTick() {
    if (!mounted || _finishing) return;
    final active = _activeIndex;
    if (active == -1) return;
    setState(() {
      _runtime[active].status = _ExStatus.active;
      _runtime[active].activeSeconds++;
    });
    if (_runtime[active].activeSeconds >= estimatedSeconds(widget.exercises[active])) {
      setState(() => _runtime[active].status = _ExStatus.completed);
      _followActiveExercise();
    }
  }

  void _followActiveExercise() {
    final active = _activeIndex;
    if (active == -1 || active == _currentIndex || !_pageController.hasClients) return;
    _pageController.animateToPage(active, duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
  }

  void _skip(int i) {
    if (_runtime[i].status == _ExStatus.completed || _runtime[i].status == _ExStatus.skipped) return;
    setState(() => _runtime[i].status = _ExStatus.skipped);
    _followActiveExercise();
  }

  void _restoreSkip(int i) {
    setState(() => _runtime[i].status = _ExStatus.notStarted);
  }

  void _markDone(int i) {
    if (_runtime[i].status == _ExStatus.completed || _runtime[i].status == _ExStatus.skipped) return;
    setState(() => _runtime[i].status = _ExStatus.completed);
    _followActiveExercise();
  }

  Future<void> _finish() async {
    if (_saving) return;
    _ticker?.cancel();
    _sessionStopwatch.stop();
    setState(() => _finishing = true);

    final skippedIndexes = <int>[];
    final completedIndexes = <int>[];
    for (var i = 0; i < _runtime.length; i++) {
      if (_runtime[i].status == _ExStatus.skipped) skippedIndexes.add(i);
      if (_runtime[i].status == _ExStatus.completed) completedIndexes.add(i);
    }

    final plannedTotal = widget.exercises.fold<int>(0, (sum, e) => sum + estimatedSeconds(e));
    final actualTotal = _sessionStopwatch.elapsed.inSeconds;
    final overageSeconds = actualTotal - plannedTotal;
    // 容差:只有超时既>=5分钟、又占计划时长15%以上才算"明显偏长"——正常的休息、
    // 换页看看别的动作、读instructions都不该触发问卷。
    final tookLonger = plannedTotal > 0 && overageSeconds / 60 >= 5 && overageSeconds / plannedTotal >= 0.15;
    final repeatedOverruns = List.generate(widget.exercises.length, (i) => i)
        .where((i) => _runtime[i].activeSeconds > estimatedSeconds(widget.exercises[i]) * 1.3)
        .length >= 2;
    // 只有在没有skip能解释"为什么这么快"的情况下,才把"异常快"当成一个独立信号。
    final finishedQuickly = skippedIndexes.isEmpty && plannedTotal > 0 && actualTotal < plannedTotal * 0.6;

    final looksUnusual = skippedIndexes.isNotEmpty || tookLonger || repeatedOverruns || finishedQuickly;

    WorkoutFeedbackResult? feedback;
    if (looksUnusual && mounted) {
      feedback = await Navigator.push<WorkoutFeedbackResult>(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutFeedbackScreen(
            skippedExerciseNames: skippedIndexes.map((i) => widget.exercises[i].exerciseName).toList(),
            showTimeQuestion: tookLonger || repeatedOverruns,
            showQuickQuestion: finishedQuickly,
          ),
        ),
      );
    }

    setState(() => _saving = true);
    try {
      final planId = widget.store.plan?.planId;
      if (planId != null) {
        final exerciseLog = [
          for (var i = 0; i < widget.exercises.length; i++)
            if (_runtime[i].status == _ExStatus.completed || _runtime[i].status == _ExStatus.skipped)
              {
                'exerciseName': widget.exercises[i].exerciseName,
                'status': _runtime[i].status == _ExStatus.completed ? 'completed' : 'skipped',
                'estimatedDurationSeconds': estimatedSeconds(widget.exercises[i]),
                'actualDurationSeconds': _runtime[i].activeSeconds,
                if (_runtime[i].status == _ExStatus.skipped)
                  'skipReason': feedback?.skipReasons[widget.exercises[i].exerciseName],
                if (_runtime[i].status == _ExStatus.skipped)
                  'skipReasonNote': feedback?.skipReasonNotes[widget.exercises[i].exerciseName],
              },
        ];

        final dayStatus = completedIndexes.isEmpty && skippedIndexes.isNotEmpty ? 'skipped' : 'completed';
        await ApiService().recordWorkout(
          planId: planId,
          day: widget.day,
          status: dayStatus,
          reason: dayStatus == 'skipped' ? 'All exercises in this session were skipped' : null,
          durationSeconds: actualTotal,
          exerciseLog: exerciseLog,
          feedback: feedback == null
              ? null
              : {
                  if (feedback.timeReason != null) 'timeReason': feedback.timeReason,
                  if (feedback.timeReasonNote != null) 'timeReasonNote': feedback.timeReasonNote,
                  if (feedback.finishedQuicklyReason != null) 'finishedQuicklyReason': feedback.finishedQuicklyReason,
                },
          accessToken: widget.store.accessToken,
        );
      }
    } catch (_) {
      // 记录失败不拦着用户结束训练——demo阶段静默放过
    }
    if (!mounted) return;
    setState(() => _saving = false);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 32,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_rounded,
                      size: 42, color: scheme.primary),
                ),
                const SizedBox(height: 20),
                Text(
                  'Workout complete',
                  textAlign: TextAlign.center,
                  style: Theme.of(dialogContext).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  widget.displayDay,
                  style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _CompletionMetric(
                          value: _formatMmSs(actualTotal),
                          label: 'Time',
                        ),
                      ),
                      SizedBox(
                        height: 34,
                        child: VerticalDivider(color: scheme.outlineVariant),
                      ),
                      Expanded(
                        child: _CompletionMetric(
                          value:
                              '${completedIndexes.length}/${widget.exercises.length}',
                          label: 'Completed',
                        ),
                      ),
                      SizedBox(
                        height: 34,
                        child: VerticalDivider(color: scheme.outlineVariant),
                      ),
                      Expanded(
                        child: _CompletionMetric(
                          value: '${skippedIndexes.length}',
                          label: 'Skipped',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final doneCount = _runtime.where((r) => r.status == _ExStatus.completed || r.status == _ExStatus.skipped).length;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.displayDay} workout')),
      body: Column(
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 12), child: _ProgressStrip(runtime: _runtime, currentIndex: _currentIndex)),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.exercises.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (context, i) => _ExercisePage(
                exercise: widget.exercises[i],
                index: i,
                total: widget.exercises.length,
                runtime: _runtime[i],
                isActive: i == _activeIndex,
                onSkip: () => _skip(i),
                onMarkDone: () => _markDone(i),
                onRestoreSkip: () => _restoreSkip(i),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                children: [
                  if (_allDone)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'All exercises done — tap Finish workout to wrap up.',
                        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _finish,
                      icon: _saving
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_outline),
                      label: Text('Finish workout ($doneCount/${widget.exercises.length})'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressStrip extends StatelessWidget {
  final List<_ExerciseRuntime> runtime;
  final int currentIndex;
  const _ProgressStrip({required this.runtime, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(runtime.length, (i) {
        final r = runtime[i];
        Color color;
        switch (r.status) {
          case _ExStatus.completed:
            color = const Color(0xFF3FA796);
            break;
          case _ExStatus.skipped:
            color = Colors.grey.shade400;
            break;
          case _ExStatus.active:
            color = scheme.primary;
            break;
          case _ExStatus.notStarted:
            color = Colors.grey.shade200;
            break;
        }
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            height: i == currentIndex ? 6 : 4,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          ),
        );
      }),
    );
  }
}

class _ExercisePage extends StatelessWidget {
  final Exercise exercise;
  final int index, total;
  final _ExerciseRuntime runtime;
  final bool isActive;
  final VoidCallback onSkip, onMarkDone, onRestoreSkip;
  const _ExercisePage({
    required this.exercise,
    required this.index,
    required this.total,
    required this.runtime,
    required this.isActive,
    required this.onSkip,
    required this.onMarkDone,
    required this.onRestoreSkip,
  });

  @override
  Widget build(BuildContext context) {
    if (runtime.status == _ExStatus.skipped) {
      return _SkippedPage(exercise: exercise, index: index, total: total, onRestore: onRestoreSkip);
    }

    final scheme = Theme.of(context).colorScheme;
    final estimated = estimatedSeconds(exercise);
    final remaining = (estimated - runtime.activeSeconds).clamp(0, estimated);
    final isCompleted = runtime.status == _ExStatus.completed;
    final isTimed = exercise.duration != null;
    final detailLine = isTimed ? '${(exercise.duration! / 60).toStringAsFixed(0)} min' : '${exercise.sets} sets × ${exercise.reps ?? '-'} reps';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text('Exercise ${index + 1} of $total', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 10),
          Center(
            child: isCompleted
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFF3FA796).withOpacity(0.14), borderRadius: BorderRadius.circular(20)),
                    child: Text('Completed · ${_formatMmSs(runtime.activeSeconds)}', style: const TextStyle(color: Color(0xFF3FA796), fontWeight: FontWeight.w700, fontSize: 12)),
                  )
                : isActive
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(color: scheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                        child: Text('In progress', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700, fontSize: 12)),
                      )
                    : Text('Up next', style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w600, fontSize: 12)),
          ),
          const SizedBox(height: 18),
          _ExerciseImage(exercise: exercise),
          const SizedBox(height: 18),
          Text(exercise.exerciseName, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(detailLine, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          Text(
            _formatMmSs(remaining),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 44),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: estimated == 0 ? 0 : (runtime.activeSeconds / estimated).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isCompleted ? 'Nice work!' : (isActive ? 'Auto-advances when the timer ends — tap Mark done to finish early' : 'This is an estimate; the timer runs once this becomes your current exercise'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          const SizedBox(height: 24),
          if (exercise.instructions.isNotEmpty) _InfoCard(icon: Icons.checklist_rounded, label: 'How to do it', text: exercise.instructions),
          if (exercise.instructions.isNotEmpty) const SizedBox(height: 10),
          if (exercise.reason.isNotEmpty) _InfoCard(icon: Icons.favorite_border, label: 'Why this for you', text: exercise.reason),
          const SizedBox(height: 28),
          if (!isCompleted)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(onPressed: onSkip, icon: const Icon(Icons.skip_next_rounded, size: 18), label: const Text('Skip')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(onPressed: onMarkDone, icon: const Icon(Icons.check, size: 18), label: const Text('Mark done')),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ExerciseImage extends StatelessWidget {
  final Exercise exercise;
  const _ExerciseImage({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final url = exercise.imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: url != null
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(context),
                loadingBuilder: (context, child, progress) => progress == null ? child : _fallback(context, loading: true),
              )
            : _fallback(context),
      ),
    );
  }

  Widget _fallback(BuildContext context, {bool loading = false}) => Container(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
        alignment: Alignment.center,
        child: loading
            ? const CircularProgressIndicator(strokeWidth: 2)
            : Icon(Icons.fitness_center, size: 44, color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
      );
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label, text;
  const _InfoCard({required this.icon, required this.label, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, size: 16, color: Colors.grey.shade500), const SizedBox(width: 6), Text(label, style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w700, fontSize: 12))]),
            const SizedBox(height: 6),
            Text(text, style: const TextStyle(height: 1.4)),
          ],
        ),
      );
}

class _SkippedPage extends StatelessWidget {
  final Exercise exercise;
  final int index, total;
  final VoidCallback onRestore;
  const _SkippedPage({required this.exercise, required this.index, required this.total, required this.onRestore});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Exercise ${index + 1} of $total', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
              const SizedBox(height: 28),
              Icon(Icons.skip_next_rounded, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 14),
              Text(exercise.exerciseName, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onRestore,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.undo, size: 16, color: Colors.orange.shade800),
                      const SizedBox(width: 6),
                      Text('Skipped — tap to undo', style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _CompletionMetric extends StatelessWidget {
  final String value;
  final String label;

  const _CompletionMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      );
}
