import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../state/profile_store.dart';

/// Plan tab: 显示backend根据这个用户的profile+personalInfo(伤病/器材等)生成的workout plan。
/// 正常流程下问卷一填完就已经自动生成好、存在store.plan里了(见questionnaire_screen.dart的
/// _finish());这个页面只是负责展示,并且在store.plan为空时(比如生成当时失败了、或者
/// 是个hydrate回来的老用户还没生成过)提供一个手动生成/重新生成的入口。
class PlanScreen extends StatefulWidget {
  final ProfileStore store;
  const PlanScreen({super.key, required this.store});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final _api = ApiService();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // 老用户(比如登录后hydrate回来的,没经过这次问卷)可能还没有plan,进这页自动补一次。
    if (widget.store.plan == null) _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plan = await _api.generatePlan(accessToken: widget.store.accessToken);
      widget.store.setPlan(plan);
    } catch (e) {
      if (mounted) setState(() => _error = "Couldn't generate your plan. Check your connection and try again.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.store.plan;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your plan'),
        actions: [
          IconButton(
            tooltip: 'Regenerate plan',
            onPressed: _loading ? null : _generate,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _generate)
              : plan == null
                  ? _EmptyState(onGenerate: _generate)
                  : _PlanView(plan: plan),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onGenerate;
  const _EmptyState({required this.onGenerate});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.fitness_center, size: 56),
              const SizedBox(height: 12),
              const Text("You don't have a plan yet.", style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Generate one based on your goal, injuries, and equipment.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              FilledButton(onPressed: onGenerate, child: const Text('Generate my plan')),
            ],
          ),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.orange),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      );
}

class _PlanView extends StatelessWidget {
  final FitnessPlan plan;
  const _PlanView({required this.plan});

  @override
  Widget build(BuildContext context) {
    final byDay = <String, List<Exercise>>{};
    for (final exercise in plan.exercises) {
      byDay.putIfAbsent(exercise.day, () => []).add(exercise);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.planName, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('${plan.goal} · ${plan.weeklyFrequency}x / week', style: TextStyle(color: Colors.grey.shade700)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        ...byDay.entries.map((entry) => _DaySection(day: entry.key, exercises: entry.value)),
      ],
    );
  }
}

class _DaySection extends StatelessWidget {
  final String day;
  final List<Exercise> exercises;
  const _DaySection({required this.day, required this.exercises});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(day, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...exercises.map((e) => _ExerciseTile(exercise: e)),
          ],
        ),
      );
}

class _ExerciseTile extends StatelessWidget {
  final Exercise exercise;
  const _ExerciseTile({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final detail = exercise.duration != null
        ? '${(exercise.duration! / 60).toStringAsFixed(0)} min · ${exercise.restSeconds}s rest'
        : '${exercise.sets} sets × ${exercise.reps ?? '-'} reps · ${exercise.restSeconds}s rest';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ExerciseThumbnail(imageUrl: exercise.imageUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exercise.exerciseName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(detail, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  if (exercise.reason.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(exercise.reason, style: const TextStyle(fontSize: 13)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 动作缩略图。imageUrl为空、加载失败、加载中都退回一个图标占位,
/// 保证demo现场就算网络抖动/Pexels搜不到图,也不会看到破图/空白。
class _ExerciseThumbnail extends StatelessWidget {
  final String? imageUrl;
  const _ExerciseThumbnail({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.fitness_center, size: 26),
    );

    if (imageUrl == null || imageUrl!.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl!,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : SizedBox(width: 56, height: 56, child: Center(child: CircularProgressIndicator(strokeWidth: 2, value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null))),
      ),
    );
  }
}
