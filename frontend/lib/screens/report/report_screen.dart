import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../state/profile_store.dart';
import '../../widgets/app_toast.dart';

/// Report tab: weekly/monthly体重报告。所有数字(变化量、进度百分比、预计周数)都是
/// backend代码算好的,AI只写summary那段话——这是demo里"AI不碰真实数字"的展示点。
/// 顺便是体重记录的入口(记完自动刷新报告)。
class ReportScreen extends StatefulWidget {
  final ProfileStore store;
  const ReportScreen({super.key, required this.store});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _api = ApiService();
  String _period = 'weekly';
  bool _loading = true;
  String? _error;
  Report? _report;
  List<WorkoutCompletion> _workouts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getReport(periodType: _period, accessToken: widget.store.accessToken),
        _api.fetchRecentWorkouts(days: _period == 'weekly' ? 7 : 30, accessToken: widget.store.accessToken),
      ]);
      if (mounted) {
        setState(() {
          _report = results[0] as Report;
          _workouts = results[1] as List<WorkoutCompletion>;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't load your report. Pull down to retry.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addWeight() async {
    final controller = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log your weight'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(suffixText: 'kg', hintText: 'e.g. 62.5'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text);
              if (parsed != null && parsed > 0 && parsed < 1000) Navigator.pop(context, parsed);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value == null) return;

    try {
      await _api.addWeightRecord(weightKg: value, accessToken: widget.store.accessToken);
      await _load(); // 记完重新拉报告,数字/图表立刻反映新记录
    } catch (_) {
      if (mounted) {
        showAppToast(context, "Couldn't save your weight. Please try again.", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addWeight,
        icon: const Icon(Icons.monitor_weight_outlined),
        label: const Text('Log weight'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'weekly', label: Text('Weekly')),
                ButtonSegment(value: 'monthly', label: Text('Monthly')),
              ],
              selected: {_period},
              onSelectionChanged: (selection) {
                setState(() => _period = selection.first);
                _load();
              },
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 48), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(child: Text(_error!, style: TextStyle(color: Colors.grey.shade600))),
              )
            else if (_report != null) ...[
              if (!_report!.hasEnoughData)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(Icons.scale_outlined, size: 40),
                        const SizedBox(height: 10),
                        Text(
                          'Not enough weight records this ${_period == 'weekly' ? 'week' : 'month'} yet. Log your weight at least twice to see your trend.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Row(
                  children: [
                    Expanded(child: _StatCard(label: 'Change', value: '${_report!.deltaKg! > 0 ? '+' : ''}${_report!.deltaKg!.toStringAsFixed(1)} kg')),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        label: 'To goal',
                        value: _report!.progressToGoalPercent != null ? '${_report!.progressToGoalPercent!.toStringAsFixed(0)}%' : '—',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        label: 'Est. weeks left',
                        value: _report!.projectedWeeksToGoal != null ? _report!.projectedWeeksToGoal!.toStringAsFixed(1) : '—',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _WeightTrend(records: _report!.weightRecords),
              ],
              const SizedBox(height: 14),
              if (_report!.summary.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome, size: 18),
                            const SizedBox(width: 6),
                            Text('Coach summary', style: Theme.of(context).textTheme.titleSmall),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(_report!.summary, style: const TextStyle(height: 1.4)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              _CompletionChart(workouts: _workouts, periodLabel: _period == 'weekly' ? 'this week' : 'this month'),
              const SizedBox(height: 14),
              _WorkoutHistory(workouts: _workouts, plan: widget.store.plan),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
            ],
          ),
        ),
      );
}

/// 简易体重趋势图:不引第三方chart库,直接CustomPaint画折线,demo够用。
class _WeightTrend extends StatelessWidget {
  final List<WeightRecord> records;
  const _WeightTrend({required this.records});

  @override
  Widget build(BuildContext context) {
    if (records.length < 2) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weight trend', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              width: double.infinity,
              child: CustomPaint(painter: _TrendPainter(records: records, color: Theme.of(context).colorScheme.primary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<WeightRecord> records;
  final Color color;
  _TrendPainter({required this.records, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final sorted = [...records]..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    final weights = sorted.map((r) => r.weightKg).toList();
    final minW = weights.reduce((a, b) => a < b ? a : b);
    final maxW = weights.reduce((a, b) => a > b ? a : b);
    final span = (maxW - minW).abs() < 0.001 ? 1.0 : maxW - minW;

    final points = <Offset>[];
    for (var i = 0; i < sorted.length; i++) {
      final x = sorted.length == 1 ? size.width / 2 : size.width * i / (sorted.length - 1);
      final y = size.height - ((weights[i] - minW) / span) * (size.height - 16) - 8;
      points.add(Offset(x, y));
    }

    final line = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, line);

    final dot = Paint()..color = color;
    for (final p in points) {
      canvas.drawCircle(p, 3.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => old.records != records || old.color != color;
}

/// 训练完成率:一个甜甜圈图(完成 vs 跳过的百分比),中间显示完成率数字。
class _CompletionChart extends StatelessWidget {
  final List<WorkoutCompletion> workouts;
  final String periodLabel;
  const _CompletionChart({required this.workouts, required this.periodLabel});

  @override
  Widget build(BuildContext context) {
    final completed = workouts.where((w) => w.status == 'completed').length;
    final skipped = workouts.where((w) => w.status == 'skipped').length;
    final total = completed + skipped;
    final rate = total == 0 ? 0.0 : completed / total;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Workout completion', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text('$periodLabel · $completed done, $skipped skipped', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const SizedBox(height: 16),
            if (total == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(child: Text('No workouts logged yet', style: TextStyle(color: Colors.grey.shade500))),
              )
            else
              Row(
                children: [
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(96, 96),
                          painter: _DonutPainter(rate: rate, color: scheme.primary, trackColor: scheme.error.withOpacity(0.25)),
                        ),
                        Text('${(rate * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LegendRow(color: scheme.primary, label: 'Completed', value: completed),
                        const SizedBox(height: 6),
                        _LegendRow(color: scheme.error.withOpacity(0.6), label: 'Skipped', value: skipped),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final int value;
  const _LegendRow({required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text('$label ($value)', style: const TextStyle(fontSize: 13)),
        ],
      );
}

class _DonutPainter extends CustomPainter {
  final double rate; // 0..1
  final Color color;
  final Color trackColor;
  _DonutPainter({required this.rate, required this.color, required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final strokeWidth = 12.0;

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    if (rate > 0) {
      final arc = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -3.14159 / 2,
        2 * 3.14159 * rate,
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.rate != rate || old.color != color;
}

/// 最近训练历史列表:完成的显示时长,跳过的显示原因。每一条可以点进去看当天具体
/// 做了哪些动作(见_WorkoutDetailSheet)。
class _WorkoutHistory extends StatelessWidget {
  final List<WorkoutCompletion> workouts;
  final FitnessPlan? plan;
  const _WorkoutHistory({required this.workouts, this.plan});

  void _openDetail(BuildContext context, WorkoutCompletion w) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _WorkoutDetailSheet(workout: w, plan: plan),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (workouts.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Workout history', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            ...workouts.map((w) {
              final completed = w.status == 'completed';
              final dateLabel = '${w.completedAt.month}/${w.completedAt.day}';
              final detail = completed
                  ? (w.durationSeconds != null ? '${(w.durationSeconds! / 60).round()} min' : 'Completed')
                  : (w.reason ?? 'Skipped');
              return InkWell(
                onTap: () => _openDetail(context, w),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        completed ? Icons.check_circle : Icons.remove_circle_outline,
                        size: 18,
                        color: completed ? Theme.of(context).colorScheme.primary : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 10),
                      SizedBox(width: 40, child: Text(dateLabel, style: TextStyle(color: Colors.grey.shade600, fontSize: 12))),
                      Expanded(child: Text(w.day, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                      Text(detail, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// 点开一条训练历史后的详情弹层——按优先级展示当天具体做了什么:
/// 1) 有逐动作记录(exerciseLog)就直接显示每个动作的完成/跳过情况;
/// 2) 没有的话(老数据/非swipe流程记录的),但这条记录属于"当前这一轮"plan,
///    就退回显示这个day在plan里原本安排的动作列表(说明这不是实际完成记录,只是参考);
/// 3) 都没有就老实说没有详情——不同轮次plan会复用相同的day label("Day 1"等),
///    所以绝不能拿当前plan的动作去匹配别的轮次的历史记录。
class _WorkoutDetailSheet extends StatelessWidget {
  final WorkoutCompletion workout;
  final FitnessPlan? plan;
  const _WorkoutDetailSheet({required this.workout, this.plan});

  @override
  Widget build(BuildContext context) {
    final completed = workout.status == 'completed';
    final dateLabel = '${workout.completedAt.month}/${workout.completedAt.day}/${workout.completedAt.year}';
    final log = workout.exerciseLog;
    final samePlan = plan?.planId != null && plan!.planId == workout.planId;
    final plannedExercises = (log == null || log.isEmpty) && samePlan ? plan!.exercises.where((e) => e.day == workout.day).toList() : null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  completed ? Icons.check_circle : Icons.remove_circle_outline,
                  color: completed ? Theme.of(context).colorScheme.primary : Colors.grey.shade500,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(workout.day, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text(dateLabel, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (!completed && (workout.reason ?? '').isNotEmpty)
              Text('Skipped · ${workout.reason}', style: TextStyle(color: Colors.grey.shade700))
            else if (completed && workout.durationSeconds != null)
              Text('Total time: ${(workout.durationSeconds! / 60).round()} min', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 18),
            Text('Exercises', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            if (log != null && log.isNotEmpty)
              ...log.map((e) => _ExerciseLogRow(entry: e))
            else if (plannedExercises != null && plannedExercises.isNotEmpty) ...[
              Text(
                "No per-exercise record was saved for this session — showing what this day's plan was.",
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
              const SizedBox(height: 10),
              ...plannedExercises.map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.fitness_center, size: 15, color: Colors.grey.shade500),
                      const SizedBox(width: 8),
                      Expanded(child: Text(e.exerciseName, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                ),
              ),
            ] else
              Text('No exercise details available for this session.', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _ExerciseLogRow extends StatelessWidget {
  final ExerciseLogEntry entry;
  const _ExerciseLogRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final done = entry.status == 'completed';
    final durationSeconds = entry.actualDurationSeconds ?? entry.estimatedDurationSeconds;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done ? Icons.check_circle : Icons.remove_circle_outline,
            size: 16,
            color: done ? Theme.of(context).colorScheme.primary : Colors.grey.shade400,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(entry.exerciseName, style: const TextStyle(fontSize: 13))),
          if (done && durationSeconds != null)
            Text('${(durationSeconds / 60).toStringAsFixed(durationSeconds < 60 ? 0 : 1)} min', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))
          else if (!done)
            Text(entry.skipReason ?? 'Skipped', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }
}
