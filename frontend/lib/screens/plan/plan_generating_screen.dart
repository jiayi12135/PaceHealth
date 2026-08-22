import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../state/profile_store.dart';
import '../navigation/app_shell.dart';

/// 问卷刚填完、profile也存好之后过渡的一个loading页:调用/ai/generate-plan生成
/// 第一份workout plan,生成完(不管成功还是失败)直接把用户带到Plan tab——
/// 失败的话Plan页面自己会显示"生成失败,重试"的入口(见plan_screen.dart的_EmptyState/_ErrorState),
/// 不需要这里处理错误UI。
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
    try {
      final plan = await ApiService().generatePlan(accessToken: widget.store.accessToken);
      widget.store.setPlan(plan);
    } catch (_) {
      // 生成失败不卡住用户——照样带他进App,Plan tab会显示重试按钮。
    }
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => AppShell(store: widget.store, initialIndex: 1)),
      );
    }
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
