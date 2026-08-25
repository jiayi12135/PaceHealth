import 'package:flutter/material.dart';
import 'state/profile_store.dart';
import 'services/api_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/onboarding/questionnaire_screen.dart';
import 'screens/navigation/app_shell.dart';
import 'theme.dart';

void main() => runApp(PaceHealthApp(store: ProfileStore()));

class PaceHealthApp extends StatefulWidget {
  final ProfileStore store;
  const PaceHealthApp({super.key, required this.store});

  @override
  State<PaceHealthApp> createState() => _PaceHealthAppState();
}

class _PaceHealthAppState extends State<PaceHealthApp> {
  // true直到我们查完本地有没有存过登录token——查完之前先显示一个loading,
  // 不要闪一下登录页又跳走,体验很跳。
  bool _restoring = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  /// 尝试恢复上次的登录状态(解决"每次hot restart都要重新登录"的问题)。
  /// 本地存的只是token,不代表一定还有效,所以要先拿它打一次/users/me验证——
  /// 验证通过才signIn+hydrate;token过期/被撤销/网络失败都当作没登录处理,
  /// 照常回登录页,不会用一个失效token硬把用户"卡"在一个访问全部失败的状态里。
  Future<void> _restoreSession() async {
    final persisted = await ProfileStore.readPersistedSession();
    if (persisted != null) {
      try {
        final saved = await ApiService().fetchMyProfile(accessToken: persisted.accessToken);
        // 经验等级/目标起点日期是纯本地存的(不经过backend),重启后也要读回来,
        // 不然Home页的"预计几周达到目标"进度条会看起来像是从没设置过。
        await widget.store.restoreGoalMeta();
        // 跟login_screen.dart一样的顺序:先把要读的东西都准备好,再一次性调用
        // signIn+hydrate,两次notify之间不await——避免main.dart这个reactive的
        // MaterialApp.home在中途用一个"过渡态"抢先重建,把还没走完hydrate的画面吃掉。
        widget.store.signIn(persisted.email, accessToken: persisted.accessToken);
        if (saved != null) {
          widget.store.hydrate(profile: saved.profile, personalInfo: saved.personalInfo);
        }
        // plan之前只存在内存里,重启就没了——顺手把backend存的最近一次plan(连同
        // day assignments)也读回来,不然登录状态恢复了但Home/Calendar还是空的。
        // 没有plan(还没生成过)或者查失败都无所谓,就留着null,Plan tab进去时自己会补。
        try {
          final plan = await ApiService().fetchLatestPlan(accessToken: persisted.accessToken);
          if (plan != null) widget.store.setPlan(plan);
        } catch (_) {
          // 同上,静默放过
        }
      } catch (_) {
        // token失效或网络问题——当作没登录,回登录页重新来一次
      }
    }
    if (mounted) setState(() => _restoring = false);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (_, __) => MaterialApp(
      title: 'PaceHealth',
      theme: paceHealthTheme,
      home: _restoring
          ? const _SplashScreen()
          : !widget.store.signedIn
              ? LoginScreen(store: widget.store)
              : widget.store.completed
                  ? AppShell(store: widget.store)
                  : QuestionnaireScreen(store: widget.store),
    ),
  );
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}
