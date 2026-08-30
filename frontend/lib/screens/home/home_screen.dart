import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/models.dart';
import '../../models/profile.dart';
import '../../services/api_service.dart';
import '../../state/profile_store.dart';
import '../../theme.dart';
import '../../widgets/app_toast.dart';
import 'calendar_screen.dart';
import '../notifications/notifications_screen.dart';

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
  bool _hasUnreadNotifications = true;
  double? _latestWeight;

  @override
  void initState() {
    super.initState();
    _loadRecent();
    _loadLatestWeight();
  }

  Future<void> _loadLatestWeight() async {
    try {
      final report = await ApiService().getReport(periodType: 'weekly', accessToken: widget.store.accessToken);
      if (mounted && report.weightRecords.isNotEmpty) setState(() => _latestWeight = report.weightRecords.last.weightKg);
    } catch (_) {}
  }

  Future<void> _updateWeight() async {
    final controller = TextEditingController(text: _latestWeight?.toStringAsFixed(1));
    final value = await showDialog<double>(context: context, builder: (context) => AlertDialog(
      title: const Text('Update current weight'),
      content: TextField(controller: controller, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(suffixText: 'kg')),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () { final v = double.tryParse(controller.text); if (v != null && v > 0 && v < 1000) Navigator.pop(context, v); }, child: const Text('Save'))],
    ));
    controller.dispose();
    if (value == null) return;
    try {
      await ApiService().addWeightRecord(weightKg: value, accessToken: widget.store.accessToken);
      if (mounted) setState(() => _latestWeight = value);
      if (mounted) showAppToast(context, 'Weight updated');
    } catch (_) { if (mounted) showAppToast(context, "Couldn't save your weight.", isError: true); }
  }

  Future<void> _loadRecent() async {
    try {
      // 给_GoalProgressCard的"完成了几次训练"用——目标进度条要看的是从goalStartDate
      // 到现在一共完成了几次,不是只看最近几周,所以这里拉大一点(接近一年)。
      final recent = await ApiService().fetchRecentWorkouts(days: 365, accessToken: widget.store.accessToken);
      if (mounted) setState(() => _recent = recent);
    } catch (_) {
      // 拉不到不阻断首页其他内容,目标进度条会按0次处理
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening';
    final name = widget.store.profile.name.trim();
    return name.isEmpty ? timeGreeting : '$timeGreeting, $name';
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
      appBar: AppBar(
        title: const Text('PaceHealth'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              setState(() => _hasUnreadNotifications = false);
              Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen(store: widget.store)));
            },
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_outlined),
                if (_hasUnreadNotifications)
                  Positioned(right: -1, top: -2, child: Container(width: 9, height: 9, decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)))),
              ],
            ),
          ),
        ],
      ),
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
          const SizedBox(height: 10),
          _CurrentWeightCard(weight: _latestWeight, onUpdate: _updateWeight),
          const SizedBox(height: 10),
          if (false) InkWell(
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
          const SizedBox(height: 10),
          _GoalProgressCard(store: widget.store, recent: _recent),
          _WeeklyCalendarCard(
            store: widget.store,
            onDayTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CalendarScreen(store: widget.store))),
          ),
          if (isFemale) ...[
            const SizedBox(height: 14),
            _PeriodCard(store: widget.store, onChanged: () => setState(() {})),
          ],
          if (false) ...[
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
        ],
      ),
    );
  }
}

class _CurrentWeightCard extends StatelessWidget {
  final double? weight;
  final VoidCallback onUpdate;
  const _CurrentWeightCard({required this.weight, required this.onUpdate});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.primary.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: scheme.primary.withOpacity(0.16), shape: BoxShape.circle),
              child: Icon(Icons.monitor_weight_outlined, color: scheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current weight', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(weight == null ? 'No weight recorded yet' : '${weight!.toStringAsFixed(1)} kg', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: scheme.primary)),
                ],
              ),
            ),
            FilledButton.tonal(onPressed: onUpdate, child: Text(weight == null ? 'Add' : 'Update')),
          ],
        ),
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

/// "预计几周达到目标体重"的进度条卡片——只在真的有体重要减(startWeightKg >
/// targetWeightKg,减重目标才会这样)才显示,增肌/维持目标没有真正的体重终点,
/// 这张卡片直接不出现,不硬凑一个没意义的数字。速率是纯代码算的(见profile_store.dart
/// 的estimatedWeeklyRateKg/estimatedWeeksToGoal),不是AI编的,也不是医学承诺。
/// 进度条本身跟着"实际完成了几次训练"走,不是单纯按日历时间推进——不然躺着不练,
/// 进度条也会自己往前挪,起不到激励作用;做完一次训练它才应该往前挪一点。
class _GoalProgressCard extends StatelessWidget {
  final ProfileStore store;
  final List<WorkoutCompletion> recent;
  const _GoalProgressCard({required this.store, required this.recent});

  @override
  Widget build(BuildContext context) {
    final profile = store.profile;
    final workoutsPerWeek = store.workoutDays.isNotEmpty ? store.workoutDays.length : profile.exerciseFrequencyPerWeek;
    final weeks = estimatedWeeksToGoal(
      startWeightKg: profile.startWeightKg,
      targetWeightKg: profile.targetWeightKg,
      experience: store.experience,
      workoutsPerWeek: workoutsPerWeek,
    );
    if (weeks == null || workoutsPerWeek <= 0) return const SizedBox.shrink();

    final startDate = store.goalStartDate ?? DateTime.now();
    final startDateOnly = DateTime(startDate.year, startDate.month, startDate.day);
    // 从设定目标那天开始,算实际完成(不算skip)了几次训练——这才是"做了多少"的
    // 真实信号,不是单纯日期过去了多久。
    final completedCount = recent.where((w) {
      if (w.status != 'completed') return false;
      final d = w.completedAt.toLocal();
      return !DateTime(d.year, d.month, d.day).isBefore(startDateOnly);
    }).length;
    final totalEstimatedWorkouts = weeks * workoutsPerWeek;
    final progress = (completedCount / totalEstimatedWorkouts).clamp(0.0, 1.0);
    final toLoseKg = profile.startWeightKg - profile.targetWeightKg;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🎯', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('About $weeks week${weeks == 1 ? '' : 's'} to your goal', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        Text(
                          '$completedCount of ~$totalEstimatedWorkouts workouts done · losing ${toLoseKg.toStringAsFixed(1)} kg',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: SizedBox(
                  width: 180,
                  height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(child: CircularProgressIndicator(value: progress, strokeWidth: 18, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary))),
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('${(progress * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 30)),
                        Text('complete', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Estimate only, based on your experience level and workout frequency — moves as you complete workouts, not a guarantee.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 10.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
          FilledButton.tonal(onPressed: _saving ? null : _pickDate, child: Text(_saving ? '...' : 'Log')),
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
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              if (!onPeriod) Text('Estimate only · based on a 28-day cycle', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
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
