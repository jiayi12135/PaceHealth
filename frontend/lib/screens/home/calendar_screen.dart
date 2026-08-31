import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../state/profile_store.dart';
import '../../widgets/app_toast.dart';
import '../plan/plan_screen.dart' show DaySection, ExerciseTile;

/// 日期格子上的小标记:none=没排训练(休息日),pending=排了还没到/还没做,
/// completed=做完了(streak标记🔥),skipped=跳过了,missed=已经过去但没有记录。
enum _DayMarker { none, pending, completed, skipped, missed }

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// 这周一的日期(星期一到星期天算一周),用来判断某个日期是不是"这周"——
/// 只有这周的日期才允许用DaySection的Start/Incomplete/Reschedule(那几个按钮的
/// 可用逻辑都是按"这周"算的),别的星期/月份只做只读预览。
DateTime _mondayOf(DateTime date) => date.subtract(Duration(days: date.weekday - 1));

/// Home页"This week"卡片点进来的日历页——真正的日历长相:月份标题+上下月翻页、
/// 星期几表头、一整个月的日期网格。哪天有排训练还没做是个圆点,做完的是🔥,
/// 跳过是灰点,过去了没记录是浅灰点。点哪天就在下面展开显示那天的训练内容
/// (plan是按星期几重复的周模板,所以任何日期都能对应到某个星期几该练什么);
/// 只有这周的日期能直接Start/Incomplete/Reschedule,别的星期显示只读预览。
class CalendarScreen extends StatefulWidget {
  final ProfileStore store;
  const CalendarScreen({super.key, required this.store});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _selectedDate = _dateOnly(DateTime.now());
  Map<DateTime, WorkoutCompletion> _completionsByDate = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecent();
    // 这周有没有收工不一定是"刚点完最后一个才知道"——也可能是这周已经收工了,
    // 用户过一会儿/换个session才重新打开Calendar页,所以打开页面时也顺手查一次。
    _maybeStartNewRound();
  }

  /// DaySection做完/跳过一个训练日之后调用——除了刷新记录,还要顺手检查一下这周
  /// 是不是刚好收工了,收工的话自动生成新一轮计划(见profile_store.dart的
  /// maybeStartNewRound),并提示用户一声。
  void _handleRecorded() {
    _loadRecent();
    _maybeStartNewRound();
  }

  Future<void> _maybeStartNewRound() async {
    // 先把排定了但既没完成也没按Incomplete的过去日期自动补记成skipped,这样日历上
    // 那几天会直接显示成灰点(跟按了Incomplete一样),不用等用户回头手动点。
    await autoMarkMissedDays(widget.store);
    _loadRecent();
    final started = await maybeStartNewRound(widget.store);
    if (started && mounted) {
      // 这个页面直接读widget.store.plan/workoutDayAssignments,不是靠AnimatedBuilder
      // 监听store变化的——maybeStartNewRound内部已经调用了store.setPlan,但这个State
      // 本身没在监听,得自己触发一次setState才会真的重绘。
      setState(() {});
      _loadRecent();
      showAppToast(context, "You finished this week! Here's your new round, adjusted based on how it went.");
    }
  }

  /// 拉够多天数(60天,大概两个月)才能让翻月份看到的历史记录基本对得上,
  /// 按"确切日期"分组而不是按day label——不然跨周的同一个星期几(比如上周一和
  /// 这周一)会互相覆盖,日历上显示的完成状态就全乱了。
  Future<void> _loadRecent() async {
    try {
      final recent = await ApiService().fetchRecentWorkouts(days: 60, accessToken: widget.store.accessToken);
      final byDate = <DateTime, WorkoutCompletion>{};
      for (final w in recent) {
        byDate.putIfAbsent(_dateOnly(w.completedAt.toLocal()), () => w);
      }
      if (mounted) setState(() => _completionsByDate = byDate);
    } catch (_) {
      // 拉不到历史不影响日历本身照常显示计划
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeMonth(int delta) {
    setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta, 1));
  }

  void _goToToday() {
    final today = _dateOnly(DateTime.now());
    setState(() {
      _visibleMonth = DateTime(today.year, today.month, 1);
      _selectedDate = today;
    });
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.store.plan;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [TextButton(onPressed: _goToToday, child: const Text('Today'))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : plan == null
              ? _EmptyState(onBack: () => Navigator.pop(context))
              : _CalendarBody(
                  store: widget.store,
                  plan: plan,
                  completionsByDate: _completionsByDate,
                  visibleMonth: _visibleMonth,
                  selectedDate: _selectedDate,
                  onChangeMonth: _changeMonth,
                  onSelectDate: (d) => setState(() => _selectedDate = d),
                  onRecorded: _handleRecorded,
                ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onBack;
  const _EmptyState({required this.onBack});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_month_outlined, size: 48),
              const SizedBox(height: 12),
              const Text("You don't have a plan yet.", style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Generate one from the Plan tab to see it here.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onBack, child: const Text('Back to Home')),
            ],
          ),
        ),
      );
}

class _CalendarBody extends StatelessWidget {
  final ProfileStore store;
  final FitnessPlan plan;
  final Map<DateTime, WorkoutCompletion> completionsByDate;
  final DateTime visibleMonth;
  final DateTime selectedDate;
  final ValueChanged<int> onChangeMonth;
  final ValueChanged<DateTime> onSelectDate;
  final VoidCallback onRecorded;
  const _CalendarBody({
    required this.store,
    required this.plan,
    required this.completionsByDate,
    required this.visibleMonth,
    required this.selectedDate,
    required this.onChangeMonth,
    required this.onSelectDate,
    required this.onRecorded,
  });

  @override
  Widget build(BuildContext context) {
    final byPlanDay = <String, List<Exercise>>{};
    for (final exercise in plan.exercises) {
      byPlanDay.putIfAbsent(exercise.day, () => []).add(exercise);
    }
    // workoutDayAssignments存的是 planDay -> weekday;这份分配是"周模板"级别的,
    // 不分哪一周,所以能直接套用到日历上任何一个月份的任何一天。
    final weekdayToPlanDay = <String, String>{
      for (final entry in store.workoutDayAssignments.entries) entry.value: entry.key,
    };
    final today = _dateOnly(DateTime.now());
    final thisMonday = _mondayOf(today);
    final thisSunday = thisMonday.add(const Duration(days: 6));

    // plan生成之前的日期(比如周四才填的问卷,但选了周一/周二练)不该算"missed"——
    // 那几天账号/计划根本还不存在,用户压根没机会做,不能倒扣。
    final planCreatedDate = _dateOnly(plan.createdAt);

    // 一个日期只要有实际完成/跳过记录,就该一直显示出来——哪怕后来这个训练日被
    // Reschedule挪到了别的星期几,历史记录也不能跟着"消失"。所以先查有没有completion,
    // 有的话直接用它;只有从来没做过、才退回看"这个星期几现在有没有排"来判断
    // pending/missed/none(这几种状态本来就只对"还没发生的事"有意义)。
    _DayMarker markerFor(DateTime date) {
      final completion = completionsByDate[date];
      if (completion != null) {
        return completion.status == 'completed' ? _DayMarker.completed : _DayMarker.skipped;
      }
      final weekday = kWeekdays[date.weekday - 1];
      final planDay = weekdayToPlanDay[weekday];
      if (planDay == null) return _DayMarker.none;
      if (date.isBefore(planCreatedDate)) return _DayMarker.none;
      return date.isBefore(today) ? _DayMarker.missed : _DayMarker.pending;
    }

    final selectedWeekday = kWeekdays[selectedDate.weekday - 1];
    final selectedCompletion = completionsByDate[selectedDate];
    // 同样的道理:有完成记录的话,用记录里实际做的是哪个训练日(completion.day)来找
    // 对应的动作列表,而不是用"这个星期几现在分配的是哪个训练日"——不然改过schedule
    // 之后,回头看之前做完的那天会变成显示"Rest day",记录就没了。
    final selectedPlanDay = selectedCompletion?.day ?? weekdayToPlanDay[selectedWeekday];
    final selectedExercises = selectedPlanDay != null ? byPlanDay[selectedPlanDay] : null;
    final selectedIsCurrentWeek = !selectedDate.isBefore(thisMonday) && !selectedDate.isAfter(thisSunday);

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
        _MonthGrid(
          visibleMonth: visibleMonth,
          selectedDate: selectedDate,
          today: today,
          markerFor: markerFor,
          onChangeMonth: onChangeMonth,
          onSelectDate: onSelectDate,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Text(_formatFullDate(selectedDate), style: Theme.of(context).textTheme.titleSmall),
            if (selectedDate == today) ...[
              const SizedBox(width: 8),
              _Pill(label: 'Today', color: Theme.of(context).colorScheme.primary),
            ] else if (!selectedIsCurrentWeek) ...[
              const SizedBox(width: 8),
              _Pill(label: 'Repeats weekly', color: Colors.grey.shade500),
            ],
          ],
        ),
        const SizedBox(height: 10),
        if (selectedPlanDay == null || selectedExercises == null)
          const _RestDayCard()
        else if (selectedIsCurrentWeek)
          DaySection(
            store: store,
            day: selectedPlanDay,
            displayDay: selectedWeekday,
            exercises: selectedExercises,
            completion: selectedCompletion,
            onRecorded: onRecorded,
          )
        else
          _ReadOnlyDayPreview(exercises: selectedExercises, completion: selectedCompletion, injuries: store.personalInfo.injuries),
      ],
    );
  }

  String _formatFullDate(DateTime date) {
    const weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return '${weekdayNames[date.weekday - 1]}, ${_monthNames[date.month - 1]} ${date.day}';
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime visibleMonth;
  final DateTime selectedDate;
  final DateTime today;
  final _DayMarker Function(DateTime) markerFor;
  final ValueChanged<int> onChangeMonth;
  final ValueChanged<DateTime> onSelectDate;
  const _MonthGrid({
    required this.visibleMonth,
    required this.selectedDate,
    required this.today,
    required this.markerFor,
    required this.onChangeMonth,
    required this.onSelectDate,
  });

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final daysInMonth = DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday - 1; // Mon=1 -> 0 blanks ... Sun=7 -> 6 blanks
    final totalCells = leadingBlanks + daysInMonth;
    final trailingBlanks = (7 - totalCells % 7) % 7;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(onPressed: () => onChangeMonth(-1), icon: const Icon(Icons.chevron_left)),
                Expanded(
                  child: Text(
                    '${_monthNames[visibleMonth.month - 1]} ${visibleMonth.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                IconButton(onPressed: () => onChangeMonth(1), icon: const Icon(Icons.chevron_right)),
              ],
            ),
            Row(
              children: kWeekdays
                  .map((w) => Expanded(
                        child: Center(
                          child: Text(w.substring(0, 1), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 0.95,
              children: [
                for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
                for (var day = 1; day <= daysInMonth; day++)
                  _DateCell(
                    date: DateTime(visibleMonth.year, visibleMonth.month, day),
                    isToday: DateTime(visibleMonth.year, visibleMonth.month, day) == today,
                    isSelected: DateTime(visibleMonth.year, visibleMonth.month, day) == selectedDate,
                    marker: markerFor(DateTime(visibleMonth.year, visibleMonth.month, day)),
                    onTap: () => onSelectDate(DateTime(visibleMonth.year, visibleMonth.month, day)),
                  ),
                for (var i = 0; i < trailingBlanks; i++) const SizedBox.shrink(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateCell extends StatelessWidget {
  final DateTime date;
  final bool isToday, isSelected;
  final _DayMarker marker;
  final VoidCallback onTap;
  const _DateCell({required this.date, required this.isToday, required this.isSelected, required this.marker, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? scheme.primary : Colors.transparent,
              shape: BoxShape.circle,
              border: (!isSelected && isToday) ? Border.all(color: scheme.primary, width: 1.4) : null,
            ),
            child: Text(
              '${date.day}',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: isSelected ? Colors.white : const Color(0xFF3A2E28)),
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(height: 10, child: Center(child: _MarkerIcon(marker: marker))),
        ],
      ),
    );
  }
}

class _MarkerIcon extends StatelessWidget {
  final _DayMarker marker;
  const _MarkerIcon({required this.marker});

  @override
  Widget build(BuildContext context) {
    switch (marker) {
      case _DayMarker.completed:
        return const Text('🔥', style: TextStyle(fontSize: 10));
      case _DayMarker.skipped:
        return Container(width: 5, height: 5, decoration: BoxDecoration(color: Colors.grey.shade400, shape: BoxShape.circle));
      case _DayMarker.pending:
        return Container(width: 5, height: 5, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle));
      case _DayMarker.missed:
        return Container(width: 5, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, shape: BoxShape.circle));
      case _DayMarker.none:
        return const SizedBox.shrink();
    }
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );
}

/// 不是这周的日子:只读预览这个星期几该练什么(周计划是重复的模板),不给
/// Start/Incomplete/Reschedule——那几个按钮的可用性判断都是按"这周"算的,套到
/// 别的星期上没有意义。如果那天有实际的完成记录(历史上真的做过/跳过了),
/// 顶部会显示一个小状态条。
class _ReadOnlyDayPreview extends StatelessWidget {
  final List<Exercise> exercises;
  final WorkoutCompletion? completion;
  final List<String> injuries;
  const _ReadOnlyDayPreview({required this.exercises, required this.completion, required this.injuries});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (completion != null) ...[
          _Pill(
            label: completion!.status == 'completed'
                ? (completion!.durationSeconds != null ? 'Done · ${(completion!.durationSeconds! / 60).round()} min' : 'Done')
                : 'Skipped',
            color: completion!.status == 'completed' ? Theme.of(context).colorScheme.primary : Colors.grey.shade500,
          ),
          const SizedBox(height: 10),
        ],
        ...exercises.map((e) => ExerciseTile(exercise: e, injuries: injuries)),
      ],
    );
  }
}

class _RestDayCard extends StatelessWidget {
  const _RestDayCard();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(Icons.self_improvement, size: 18, color: Colors.grey.shade400),
            const SizedBox(width: 10),
            Text('Rest day', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
