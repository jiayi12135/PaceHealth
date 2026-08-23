import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/models.dart';
import '../../models/profile.dart';
import '../../services/api_service.dart';
import '../../state/profile_store.dart';
import '../../theme.dart';
import '../../widgets/app_toast.dart';
import 'calendar_screen.dart';

// 固定周期假设,跟backend那份(app/services/ai/prompts.py describe_cycle_context)完全对齐——
// 前端这份只是为了能在Home页立刻显示,不用等一次网络请求;真正喂给AI的那份是backend自己算的。
const _cycleLengthDays = 28;
const _periodLengthDays = 5;
// 预测的经期开始日到了之后,主动问用户"来了吗"的确认窗口——预测日当天+接下来2天,
// 一共3天,因为实际来的日子经常会比预测晚一两天,不用卡死在预测当天才问一次。
const _confirmWindowDays = 3;
const _kPeriodConfirmDismissedPrefix = 'ph_period_confirm_dismissed_';

class HomeScreen extends StatefulWidget {
  final ProfileStore store;
  final void Function(int tabIndex) onNavigateToTab;
  const HomeScreen({super.key, required this.store, required this.onNavigateToTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<WorkoutCompletion> _recent = [];
  bool _loadingStreak = true;

  @override
  void initState() {
    super.initState();
    _loadStreak();
  }

  Future<void> _loadStreak() async {
    try {
      // 拉够多天数(5周)才能算出有意义的streak,不然只拉7天的话streak最多显示到7。
      final recent = await ApiService().fetchRecentWorkouts(days: 35, accessToken: widget.store.accessToken);
      if (mounted) setState(() => _recent = recent);
    } catch (_) {
      // streak拉不到就显示0,不阻断首页其他内容
    } finally {
      if (mounted) setState(() => _loadingStreak = false);
    }
  }

  /// Streak按"排定的训练日"算,不是按自然日连续算——不然一周3-5练的计划,中间的
  /// 休息日会把streak天天打断,永远只显示1。休息日(非训练日)直接跳过、不算数也不
  /// 打断;只有"排定要练的那天却没完成"才会把streak断掉。之前的plan换过/重新生成过
  /// 也没关系,workoutDayAssignments会保留下来(见autoAssignWorkoutDays),而且
  /// _recent本来就没有按plan过滤,以前的完成记录一样算数。
  int get _streak {
    final completedDates = _recent.where((w) => w.status == 'completed').map((w) {
      final d = w.completedAt.toLocal();
      return DateTime(d.year, d.month, d.day);
    }).toSet();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scheduledWeekdays = widget.store.workoutDayAssignments.values.toSet();

    var streak = 0;
    var cursor = today;
    // 最多回看35天,跟_loadStreak拉的历史范围对齐(也避免万一没有排定训练日时死循环)。
    for (var i = 0; i < 35; i++) {
      // 没有排定过训练日(比如还没生成过plan)就退回"每天都算"的老逻辑。
      final isScheduledDay = scheduledWeekdays.isEmpty || scheduledWeekdays.contains(kWeekdays[cursor.weekday - 1]);
      if (isScheduledDay) {
        if (completedDates.contains(cursor)) {
          streak++;
        } else if (cursor != today) {
          break; // 排定的训练日、已经过去了、却没完成记录——streak在这里断掉
        }
        // cursor == today 且今天还没练:不算断,今天先跳过继续往前看昨天
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String get _greetingEmoji {
    final hour = DateTime.now().hour;
    if (hour < 12) return '☀️';
    if (hour < 18) return '🌤️';
    return '🌙';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isFemale = widget.store.profile.sex.toLowerCase() == 'female';
    return Scaffold(
      appBar: AppBar(title: const Text('PaceHealth')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Row(
            children: [
              Text(_greetingEmoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 8),
              Expanded(child: Text(_greeting, style: Theme.of(context).textTheme.headlineSmall)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Your health companion for steady progress.', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 20),
          InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => widget.onNavigateToTab(1),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [scheme.primary, scheme.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your plan is one tap away', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                        SizedBox(height: 6),
                        Text('Personalized around your goals, injuries, and equipment.', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('💪', style: TextStyle(fontSize: 40)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _WeeklyCalendarCard(
            store: widget.store,
            onDayTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CalendarScreen(store: widget.store))),
          ),
          const SizedBox(height: 14),
          _StreakCard(streak: _streak, loading: _loadingStreak),
          if (isFemale) ...[
            const SizedBox(height: 14),
            _PeriodCard(store: widget.store, onChanged: () => setState(() {})),
          ],
          const SizedBox(height: 24),
          Text('Quick access', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _QuickCard(emoji: '🍽️', label: 'Log a meal', color: paceHealthAccents[0], onTap: () => widget.onNavigateToTab(0)),
              _QuickCard(emoji: '🏋️', label: 'Today\'s plan', color: paceHealthAccents[1], onTap: () => widget.onNavigateToTab(1)),
              _QuickCard(emoji: '📊', label: 'Your report', color: paceHealthAccents[2], onTap: () => widget.onNavigateToTab(3)),
              _QuickCard(emoji: '💬', label: 'Ask your coach', color: paceHealthAccents[3], onTap: null),
            ],
          ),
        ],
      ),
    );
  }
}

/// 一周(周一到周日)视图:标出今天、哪几天排了训练、哪几天已经完成。点哪天都跳去Plan tab。
class _WeeklyCalendarCard extends StatelessWidget {
  final ProfileStore store;
  final VoidCallback onDayTap;
  const _WeeklyCalendarCard({required this.store, required this.onDayTap});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final scheduledWeekdays = store.workoutDayAssignments.values.toSet();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_month_outlined, size: 18),
                const SizedBox(width: 6),
                Text('This week', style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: kWeekdays.map((weekday) {
                final date = dateForWeekdayThisWeek(weekday);
                final isToday = date == todayOnly;
                final isScheduled = scheduledWeekdays.contains(weekday);
                return Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onDayTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          Text(weekday.substring(0, 1), style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isToday ? Theme.of(context).colorScheme.primary : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${date.day}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: isToday ? Colors.white : const Color(0xFF3A2E28),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Icon(
                            Icons.circle,
                            size: 5,
                            color: isScheduled ? Theme.of(context).colorScheme.primary : Colors.transparent,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final int streak;
  final bool loading;
  const _StreakCard({required this.streak, required this.loading});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loading ? 'Loading streak…' : (streak == 0 ? 'No streak yet' : '$streak day${streak > 1 ? 's' : ''} streak'),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    Text('Complete a workout today to keep it going', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

/// 经期记录+预测。只对sex==female显示。日期只存yyyy-MM-dd,预测用固定28天周期假设——
/// 跟backend describe_cycle_context()用的是同一套逻辑,这里只是为了不用等网络请求就能显示。
class _PeriodCard extends StatefulWidget {
  final ProfileStore store;
  final VoidCallback onChanged;
  const _PeriodCard({required this.store, required this.onChanged});

  @override
  State<_PeriodCard> createState() => _PeriodCardState();
}

class _PeriodCardState extends State<_PeriodCard> {
  bool _saving = false;
  // 每个"预测周期开始日"独立判断有没有被dismiss过——SharedPreferences里存的key
  // 是这个日期,所以"这一轮不问了"不会影响下一轮(28天后)的新预测窗口重新问一次。
  bool _dismissedThisWindow = false;
  String? _checkedDismissKey;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
      helpText: 'When did your last period start?',
    );
    if (picked == null) return;

    setState(() => _saving = true);
    final dateStr = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    final info = widget.store.personalInfo;
    final updated = UserPersonalInfo(
      availableEquipment: info.availableEquipment,
      postureIssues: info.postureIssues,
      injuries: info.injuries,
      surgeryHistory: info.surgeryHistory,
      exercisesToAvoid: info.exercisesToAvoid,
      lastPeriodDate: dateStr,
      workoutWeekdays: info.workoutWeekdays,
    );
    try {
      await ApiService().saveMyProfile(profile: widget.store.profile, personalInfo: updated, accessToken: widget.store.accessToken);
      widget.store.save(profile: widget.store.profile, personalInfo: updated);
      widget.onChanged();
      if (mounted) showAppToast(context, 'Got it — saved.');
    } catch (_) {
      if (mounted) showAppToast(context, "Couldn't save that. Please try again.", isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastPeriod = widget.store.personalInfo.lastPeriodDate;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: lastPeriod == null ? _prompt(context) : _summary(context, DateTime.parse(lastPeriod)),
      ),
    );
  }

  Widget _prompt(BuildContext context) => Row(
        children: [
          const Text('🩸', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Log your last period to see it reflected in your plan.', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          ),
          TextButton(onPressed: _saving ? null : _pickDate, child: Text(_saving ? '...' : 'Log')),
        ],
      );

  /// 把'yyyy-MM-dd'解析成不带时分秒的DateTime,跟todayOnly统一比较基准,避免时区/
  /// 时分秒偏差导致差一天。
  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _fmtDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 只在key变了的时候才去读一次SharedPreferences(避免每次build都读)。key是这一轮
  /// "预测周期开始日"的日期字符串,用户点过"Not yet"就会把这个key存成true,28天后
  /// 换了新的预测日、key也变了,会重新问一遍,不会被永久静音。
  void _loadDismissedIfNeeded(String key) {
    if (_checkedDismissKey == key) return;
    _checkedDismissKey = key;
    _dismissedThisWindow = false;
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted || _checkedDismissKey != key) return;
      final dismissed = prefs.getBool('$_kPeriodConfirmDismissedPrefix$key') ?? false;
      if (dismissed != _dismissedThisWindow) setState(() => _dismissedThisWindow = dismissed);
    });
  }

  Future<void> _dismissConfirm(String key) async {
    setState(() => _dismissedThisWindow = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_kPeriodConfirmDismissedPrefix$key', true);
  }

  Future<void> _confirmPeriodStarted() async {
    setState(() => _saving = true);
    final today = _dateOnly(DateTime.now());
    final info = widget.store.personalInfo;
    final updated = UserPersonalInfo(
      availableEquipment: info.availableEquipment,
      postureIssues: info.postureIssues,
      injuries: info.injuries,
      surgeryHistory: info.surgeryHistory,
      exercisesToAvoid: info.exercisesToAvoid,
      lastPeriodDate: _fmtDate(today),
      workoutWeekdays: info.workoutWeekdays,
    );
    try {
      await ApiService().saveMyProfile(profile: widget.store.profile, personalInfo: updated, accessToken: widget.store.accessToken);
      widget.store.save(profile: widget.store.profile, personalInfo: updated);
      widget.onChanged();
      if (mounted) showAppToast(context, 'Thanks — updated your cycle.');
    } catch (_) {
      if (mounted) showAppToast(context, "Couldn't save that. Please try again.", isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _summary(BuildContext context, DateTime lastPeriod) {
    final today = DateTime.now();
    final todayOnly = _dateOnly(today);
    final daysSince = todayOnly.difference(_dateOnly(lastPeriod)).inDays;
    final daysIntoCycle = daysSince % _cycleLengthDays;
    final daysUntilNext = _cycleLengthDays - daysIntoCycle;
    final onPeriod = daysIntoCycle < _periodLengthDays;
    // 这一轮"预测周期开始日"——只有daysSince跨过了至少一整个28天周期,才算是"预测"出来的
    // (而不是用户上次实打实记录的那天),才需要主动确认。
    final predictedCycleStart = todayOnly.subtract(Duration(days: daysIntoCycle));
    final isPredictedWindow = daysSince >= _cycleLengthDays && daysIntoCycle < _confirmWindowDays;

    if (isPredictedWindow) {
      final key = _fmtDate(predictedCycleStart);
      _loadDismissedIfNeeded(key);
      if (!_dismissedThisWindow) {
        return _confirmBanner(context, key);
      }
    }

    final label = onPeriod ? 'Day ${daysIntoCycle + 1} of your period' : 'Period expected in $daysUntilNext day${daysUntilNext > 1 ? 's' : ''}';

    return Row(
      children: [
        const Text('🩸', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Text('Estimate only, based on a 28-day cycle', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
            ],
          ),
        ),
        IconButton(onPressed: _saving ? null : _pickDate, icon: const Icon(Icons.edit_outlined, size: 18)),
      ],
    );
  }

  Widget _confirmBanner(BuildContext context, String dismissKey) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🩸', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Did your period start?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    Text('Based on your cycle, it was expected around now.', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => _dismissConfirm(dismissKey),
                  child: const Text('Not yet'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _confirmPeriodStarted,
                  child: Text(_saving ? '...' : 'Yes, today'),
                ),
              ),
            ],
          ),
        ],
      );
}

class _QuickCard extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _QuickCard({required this.emoji, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
      );
}
