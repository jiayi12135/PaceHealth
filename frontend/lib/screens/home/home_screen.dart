import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../models/profile.dart';
import '../../services/api_service.dart';
import '../../state/profile_store.dart';
import '../../theme.dart';
import '../../widgets/app_toast.dart';

// 固定周期假设,跟backend那份(app/services/ai/prompts.py describe_cycle_context)完全对齐——
// 前端这份只是为了能在Home页立刻显示,不用等一次网络请求;真正喂给AI的那份是backend自己算的。
const _cycleLengthDays = 28;
const _periodLengthDays = 5;

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

  int get _streak {
    final completedDates = _recent.where((w) => w.status == 'completed').map((w) {
      final d = w.completedAt.toLocal();
      return DateTime(d.year, d.month, d.day);
    }).toSet();

    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    // 今天还没打卡的话不算断掉,从昨天开始数;今天已经打卡了就从今天开始数。
    if (!completedDates.contains(cursor)) cursor = cursor.subtract(const Duration(days: 1));

    var streak = 0;
    while (completedDates.contains(cursor)) {
      streak++;
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
          _WeeklyCalendarCard(store: widget.store, onDayTap: () => widget.onNavigateToTab(1)),
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

  Widget _summary(BuildContext context, DateTime lastPeriod) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final daysSince = todayOnly.difference(lastPeriod).inDays;
    final daysIntoCycle = daysSince % _cycleLengthDays;
    final daysUntilNext = _cycleLengthDays - daysIntoCycle;
    final onPeriod = daysIntoCycle < _periodLengthDays;

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
