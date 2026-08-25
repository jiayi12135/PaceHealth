import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../state/profile_store.dart';
import '../../widgets/app_toast.dart';
import 'workout_session_screen.dart';

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
  // 最近7天的训练记录,按day分组(同一天可能重复出现,取最新一条)——用来判断这周
  // 某个训练日是不是已经做完/跳过了,做完的话Start/Incomplete按钮就不用再显示了。
  Map<String, WorkoutCompletion> _recentByDay = {};

  @override
  void initState() {
    super.initState();
    _loadRecent();
    // 老用户(比如登录后hydrate回来的,没经过这次问卷)可能还没有plan,进这页自动补一次——
    // 但先试试backend有没有存过之前生成的(GET /ai/plan),真的一份都没有才生成新的,
    // 不然每次store.plan只是"这次冷启动还没恢复"就白白再生成一份、多花AI token。
    if (widget.store.plan == null) _loadOrGenerate();
    // 这周有没有收工不一定是"刚点完最后一个才知道"——也可能是这周已经收工了,
    // 用户过一会儿/换个session才重新打开Plan页,所以打开页面时也顺手查一次,
    // 不是只在DaySection触发onRecorded时才查。
    _maybeStartNewRound();
  }

  Future<void> _loadOrGenerate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final existing = await _api.fetchLatestPlan(accessToken: widget.store.accessToken);
      if (existing != null) {
        widget.store.setPlan(existing);
        if (mounted) setState(() => _loading = false);
        return;
      }
    } catch (_) {
      // 查不到/查失败都当作"没有",往下走生成流程
    }
    await _generate();
  }

  /// DaySection做完/跳过一个训练日之后调用——除了刷新这周的记录,还要顺手检查
  /// 一下这周是不是刚好收工了(排定的训练日都有记录了),收工的话自动生成新一轮
  /// 计划(见profile_store.dart的maybeStartNewRound),并提示用户一声。
  void _handleRecorded() {
    _loadRecent();
    _maybeStartNewRound();
  }

  Future<void> _maybeStartNewRound() async {
    final started = await maybeStartNewRound(widget.store);
    if (started && mounted) {
      // 这个页面直接读widget.store.plan,不是靠AnimatedBuilder监听store变化的——
      // maybeStartNewRound内部已经调用了store.setPlan(通知了ChangeNotifier的
      // 监听者),但这个State本身没在监听,得自己触发一次setState才会真的重绘,
      // 不然明明新一轮已经生成好了、数据库里也有,画面却还停在旧的那份。
      setState(() {});
      _loadRecent(); // 新一轮的day label虽然大概率还是Day1/2/3,但保险起见刷新一下
      showAppToast(context, "You finished this week! Here's your new round, adjusted based on how it went.");
    }
  }

  Future<void> _loadRecent() async {
    try {
      final recent = await _api.fetchRecentWorkouts(days: 7, accessToken: widget.store.accessToken);
      final byDay = <String, WorkoutCompletion>{};
      // 不同轮次的plan会重复用"Day 1"/"Day 2"这种相同的day label,所以必须先按
      // 当前plan的planId过滤,不然新一轮还没做任何训练时,会把上一轮同label的
      // 完成/跳过记录错误地显示出来。
      final currentPlanId = widget.store.plan?.planId;
      final scoped = currentPlanId == null ? recent : recent.where((w) => w.planId == currentPlanId).toList();
      // 接口已经按completed_at倒序返回,先出现的就是最新的,后面同day的直接忽略。
      for (final w in scoped) {
        byDay.putIfAbsent(w.day, () => w);
      }
      if (mounted) setState(() => _recentByDay = byDay);
    } catch (_) {
      // 拉取历史失败不影响正常使用计划,顶多按钮一直显示着
    }
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plan = await _api.generatePlan(accessToken: widget.store.accessToken);
      widget.store.setPlan(plan);
      // 问卷已经问过想哪几天练了(store.workoutDays),直接按顺序自动分配到星期几,
      // 不用再单独问一遍——分配之后哪天练什么用户随时能在Calendar里调(只要那天
      // 还没到、而且只能换到同一周内的其他天)。
      final assignments = autoAssignWorkoutDays(plan: plan, suggestedWeekdays: widget.store.workoutDays, existing: widget.store.workoutDayAssignments);
      widget.store.setWorkoutDayAssignments(assignments);
      final planId = plan.planId;
      if (planId != null) {
        try {
          await _api.saveDayAssignments(planId: planId, assignments: assignments, accessToken: widget.store.accessToken);
        } catch (_) {
          // 存后端失败不拦着用户——本地状态已经是对的了
        }
      }
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
      appBar: AppBar(title: const Text('Your plan')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _loadOrGenerate)
              : plan == null
                  ? _EmptyState(onGenerate: _generate)
                  : _PlanView(plan: plan, store: widget.store, recentByDay: _recentByDay, onRecorded: _handleRecorded),
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
  final ProfileStore store;
  final Map<String, WorkoutCompletion> recentByDay;
  final VoidCallback onRecorded;
  const _PlanView({required this.plan, required this.store, required this.recentByDay, required this.onRecorded});

  @override
  Widget build(BuildContext context) {
    final byDay = <String, List<Exercise>>{};
    for (final exercise in plan.exercises) {
      byDay.putIfAbsent(exercise.day, () => []).add(exercise);
    }
    final dayKeys = byDay.keys.toList();

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
        ...dayKeys.map((day) {
          // 星期几优先用自动分配(或用户Reschedule调整过)的映射,没有的话(比如老数据)
          // 才退回问卷里选的顺序。
          final displayDay = store.workoutDayAssignments[day] ?? day;
          return DaySection(
            store: store,
            day: day,
            displayDay: displayDay,
            exercises: byDay[day]!,
            completion: recentByDay[day],
            onRecorded: onRecorded,
            showReschedule: false,
          );
        }),
      ],
    );
  }
}

/// 公开(不带下划线)是因为Home页的Calendar page(calendar_screen.dart)也要按星期几
/// 顺序复用这一整块UI(Start/Incomplete/Reschedule/完成状态全部一致),不想维护两份。
class DaySection extends StatelessWidget {
  final ProfileStore store;
  final String day;
  final String displayDay;
  final List<Exercise> exercises;
  // 这周这一天已经有的记录(完成或跳过)——不为null的话就不再显示Start/Incomplete,
  // 改显示一个"已经是历史记录了"的状态条。
  final WorkoutCompletion? completion;
  final VoidCallback onRecorded;
  // Reschedule入口只保留在Calendar页(挪动到哪一天是个"日期"概念,Calendar本来就是
  // 按真实日期排布的,改起来更直观)——Plan页传false隐藏这个按钮,避免两个入口。
  final bool showReschedule;
  const DaySection({
    required this.store,
    required this.day,
    required this.displayDay,
    required this.exercises,
    required this.completion,
    required this.onRecorded,
    this.showReschedule = true,
  });

  Future<void> _skip(BuildContext context) async {
    // 常见原因列表+Other,选完记到backend——AI聊天会读这些原因来调整建议。
    const reasons = ['Too tired', 'No time', 'Feeling pain', 'Not motivated', 'Other'];
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text("Why can't you do this workout?", style: Theme.of(sheetContext).textTheme.titleSmall),
            ),
            ...reasons.map((r) => ListTile(title: Text(r), onTap: () => Navigator.pop(sheetContext, r))),
          ],
        ),
      ),
    );
    if (chosen == null || !context.mounted) return;

    var reason = chosen;
    if (chosen == 'Other') {
      final controller = TextEditingController();
      final custom = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Tell us why'),
          content: TextField(controller: controller, autofocus: true, maxLength: 200),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Save')),
          ],
        ),
      );
      if (custom == null || custom.isEmpty || !context.mounted) return;
      reason = custom;
    }

    try {
      final planId = store.plan?.planId;
      if (planId != null) {
        await ApiService().recordWorkout(planId: planId, day: day, status: 'skipped', reason: reason, accessToken: store.accessToken);
      }
      onRecorded();
      if (context.mounted) {
        showAppToast(context, 'Got it — your coach will keep this in mind and adjust.');
      }
    } catch (_) {
      if (context.mounted) {
        showAppToast(context, "Couldn't save that. Please try again.", isError: true);
      }
    }
  }

  /// 这一天的运动量/热量小结。热量是代码按MET公式粗算的参考值(体重×MET×小时),
  /// 不是AI编的数字——跟整个app"数字由代码算"的原则一致。
  String _daySummary() {
    final minutes = store.profile.exerciseDurationMinutes > 0 ? store.profile.exerciseDurationMinutes : 45;
    final weight = store.profile.startWeightKg > 0 ? store.profile.startWeightKg : 65.0;
    const met = 5.0; // moderate-intensity exercise
    final kcal = (met * weight * (minutes / 60)).round();
    return '${exercises.length} exercises · ~$minutes min · ~$kcal kcal';
  }

  Future<void> _start(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutSessionScreen(store: store, day: day, displayDay: displayDay, exercises: exercises),
      ),
    );
    // Finish那边已经把completed记录写进backend了,回来刷新一下,按钮才会消失变成历史记录。
    onRecorded();
  }

  /// 这一天排定的日期是不是还没到——过了(或者就是今天)就不能再改了。
  bool get _canReschedule => dateForWeekdayThisWeek(displayDay).isAfter(DateTime.now());

  Future<void> _reschedule(BuildContext context) async {
    final takenDays = store.workoutDayAssignments.entries.where((e) => e.key != day).map((e) => e.value).toSet();
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Move $day to…', style: Theme.of(sheetContext).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text('Only future days this week are available.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kWeekdays.map((weekday) {
                  final isFuture = dateForWeekdayThisWeek(weekday).isAfter(DateTime.now());
                  final isTaken = takenDays.contains(weekday);
                  final enabled = isFuture && !isTaken && weekday != displayDay;
                  return ChoiceChip(
                    label: Text(weekday),
                    selected: weekday == displayDay,
                    onSelected: enabled ? (_) => Navigator.pop(sheetContext, weekday) : null,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null) return;
    final updated = {...store.workoutDayAssignments, day: chosen};
    store.setWorkoutDayAssignments(updated);
    onRecorded();
    final planId = store.plan?.planId;
    if (planId != null) {
      try {
        await ApiService().saveDayAssignments(planId: planId, assignments: updated, accessToken: store.accessToken);
      } catch (_) {
        // 本地已经改好了,存后端失败就不打扰用户——顶多下次重启这条改动没保留住。
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    displayDay == day ? day : '$displayDay · $day',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                if (completion == null && _canReschedule && showReschedule)
                  IconButton(
                    tooltip: 'Reschedule',
                    onPressed: () => _reschedule(context),
                    icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                if (completion == null) ...[
                  TextButton(
                    onPressed: () => _skip(context),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: const Text('Incomplete', style: TextStyle(fontSize: 12.5)),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: () => _start(context),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [Icon(Icons.play_arrow, size: 15), SizedBox(width: 2), Text('Start', style: TextStyle(fontSize: 12.5))],
                    ),
                  ),
                ] else
                  _CompletionBadge(completion: completion!),
              ],
            ),
            Text(_daySummary(), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const SizedBox(height: 8),
            ...exercises.map((e) => ExerciseTile(exercise: e, injuries: store.personalInfo.injuries)),
          ],
        ),
      );
}

/// 这一天已经有record了(这周完成过或跳过过),就不再显示Start/Incomplete按钮,
/// 换成这个小状态条——它已经是历史记录,不是待办了。
class _CompletionBadge extends StatelessWidget {
  final WorkoutCompletion completion;
  const _CompletionBadge({required this.completion});

  @override
  Widget build(BuildContext context) {
    final done = completion.status == 'completed';
    final label = done
        ? (completion.durationSeconds != null ? 'Done · ${(completion.durationSeconds! / 60).round()} min' : 'Done')
        : 'Skipped';
    final color = done ? Theme.of(context).colorScheme.primary : Colors.grey.shade500;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(done ? Icons.check_circle : Icons.remove_circle_outline, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

/// 公开(不带下划线)是因为Calendar page(calendar_screen.dart)看别的星期/月份的
/// 只读预览也要用到同一张卡片(不带Start/Incomplete按钮的那种场景)。
class ExerciseTile extends StatelessWidget {
  final Exercise exercise;
  final List<String> injuries;
  const ExerciseTile({required this.exercise, this.injuries = const []});

  /// 如果这个动作的推荐理由里提到了用户的受伤部位(说明AI是绕着伤病挑的动作),
  /// 返回那个部位名,用来在卡片上显示"Adapted for your knee"这种角标。
  String? get _adaptedFor {
    final reason = exercise.reason.toLowerCase();
    for (final injury in injuries) {
      // injuries存的是'Knee (sensitive area)'这种格式,取第一个词作为部位名
      final area = injury.split(' ').first.toLowerCase();
      if (area.length > 2 && reason.contains(area)) return area;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final detail = exercise.duration != null
        ? '${(exercise.duration! / 60).toStringAsFixed(0)} min · ${exercise.restSeconds}s rest'
        : '${exercise.sets} sets × ${exercise.reps ?? '-'} reps · ${exercise.restSeconds}s rest';
    final adaptedFor = _adaptedFor;
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
                  if (adaptedFor != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_outlined, size: 13, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Adapted for your $adaptedFor',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
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
