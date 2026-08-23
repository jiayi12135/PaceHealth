import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../state/profile_store.dart';
import '../navigation/app_shell.dart';

/// 问卷刚填完、profile也存好之后过渡的一个loading页:调用/ai/generate-plan生成
/// 第一份workout plan,生成完(不管成功还是失败)直接把用户带到Plan tab——
/// 失败的话Plan页面自己会显示"生成失败,重试"的入口(见plan_screen.dart的_EmptyState/_ErrorState),
/// 不需要这里处理错误UI。训练日具体排在星期几也不用再问一遍——问卷已经问过了
/// (store.workoutDays),这里直接按顺序自动分配。
class PlanGeneratingScreen extends StatefulWidget {
  final ProfileStore store;
  const PlanGeneratingScreen({super.key, required this.store});

  @override
  State<PlanGeneratingScreen> createState() => _PlanGeneratingScreenState();
}

class _PlanGeneratingScreenState extends State<PlanGeneratingScreen> {
  @override
  void initState() {
    super.initState();
    _generateThenContinue();
  }

  Future<void> _generateThenContinue() async {
    FitnessPlan? plan;
    try {
      plan = await ApiService().generatePlan(accessToken: widget.store.accessToken);
      widget.store.setPlan(plan);
      final assignments = autoAssignWorkoutDays(plan: plan, suggestedWeekdays: widget.store.workoutDays, existing: widget.store.workoutDayAssignments);
      widget.store.setWorkoutDayAssignments(assignments);
      final planId = plan.planId;
      if (planId != null) {
        try {
          await ApiService().saveDayAssignments(planId: planId, assignments: assignments, accessToken: widget.store.accessToken);
        } catch (_) {
          // 存后端失败不拦着用户——本地状态已经是对的了
        }
      }
      if (mounted) await _maybeShowMidweekStartNotice();
    } catch (_) {
      // 生成失败不卡住用户——照样带他进App,Plan tab会显示重试按钮。
    }
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => AppShell(store: widget.store, initialIndex: 1)),
    );
  }

  /// 问卷选的是"一周N次",但如果这周已经过去了几天(比如周四才填完问卷),
  /// 排定的星期几里有几个已经错过了,这周自然凑不满N次——不是bug,只是提前
  /// 告诉用户一声,免得他自己数了发现"怎么这周比说好的少",以为哪里坏了。
  Future<void> _maybeShowMidweekStartNotice() async {
    final chosenWeekdays = widget.store.workoutDays;
    final totalDays = chosenWeekdays.length;
    if (totalDays == 0) return;

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final remainingDays = chosenWeekdays.where((w) => !dateForWeekdayThisWeek(w).isBefore(todayOnly)).length;
    if (remainingDays >= totalDays) return; // 这周还没开始/刚好从周一开始,不用特别提醒

    final freqLabel = '$totalDays session${totalDays == 1 ? '' : 's'} a week';
    final message = remainingDays == 0
        ? "You picked $freqLabel. Since you're starting partway through this week, your first session will be next Monday."
        : "You picked $freqLabel. Since you're starting partway through this week, you'll have $remainingDays session${remainingDays == 1 ? '' : 's'} before Sunday — your full $totalDays/week schedule starts next Monday.";

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Your first week'),
        content: Text(message),
        actions: [FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Got it'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text('Your coach is building your plan…', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Personalizing it around your goals, injuries, and equipment.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
}
