import 'package:flutter/material.dart';

import '../../state/profile_store.dart';
import '../../services/api_service.dart';
import '../navigation/app_shell.dart';
import '../onboarding/questionnaire_screen.dart';
import '../../widgets/app_toast.dart';

class LoginScreen extends StatefulWidget {
  final ProfileStore store;
  const LoginScreen({super.key, required this.store});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registering = false;
  bool _obscurePassword = true;
  bool _submitting = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      final api = ApiService();
      final session = await api.authenticate(
        email: _email.text.trim(),
        password: _password.text,
        register: _registering,
      );
      // 关键顺序:先查有没有存过的问卷资料,这一步还没碰store、不会触发任何notify。
      // 查完(不管有没有查到)才一次性调用signIn()+hydrate(),两次notify中间不await——
      // 这样main.dart那个反应式的MaterialApp.home只会用"最终状态"重新求值一次。
      // 之前的bug就出在这里:signIn()单独先notify一次时completed还是false,
      // main.dart会把home换成QuestionnaireScreen,把这个正在等fetchMyProfile结果的
      // LoginScreen直接dispose掉——等fetchMyProfile真的查到资料时,mounted已经是
      // false,hydrate()被静默跳过,completed永远没机会变成true,所以每次登录都被
      // 送去问卷,即使profile其实早就存在(backend那边GET /users/me其实是200的)。
      SavedProfile? saved;
      try {
        saved = await api.fetchMyProfile(accessToken: session.accessToken);
      } catch (_) {
        saved = null; // 查失败就当没填过处理,不阻断登录,顶多是又让他填一次问卷
      }

      widget.store.signIn(session.email, accessToken: session.accessToken);
      if (saved != null) {
        widget.store.hydrate(profile: saved.profile, personalInfo: saved.personalInfo);
      }

      // 即使上面已经让store状态一步到位,还是显式导航一次而不是依赖reactive rebuild——
      // 更可靠,行为也更好预测。
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => widget.store.completed ? AppShell(store: widget.store) : QuestionnaireScreen(store: widget.store),
          ),
          (route) => false,
        );
      }
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      // 邮箱确认这种情况不是"失败",是流程的一步——用弹窗讲清楚要去邮箱点确认链接,
      // 比一条一闪而过的SnackBar明显得多。
      if (message.toLowerCase().contains('confirm')) {
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.mark_email_unread_outlined, size: 40),
            title: const Text('Check your email'),
            content: Text(
              'We sent a confirmation link to ${_email.text.trim()}. Open your inbox (e.g. Gmail), tap the link, then come back and sign in.',
            ),
            actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Got it'))],
          ),
        );
      } else {
        showAppToast(context, message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: scheme.primary,
                      child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 34),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _registering ? 'Create your account' : 'Welcome to PaceHealth',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _registering
                        ? 'Start building healthy habits at your pace.'
                        : 'Sign in to continue your health journey.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 32),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline)),
                              validator: (value) => value != null && value.contains('@') ? null : 'Enter a valid email address',
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _password,
                              obscureText: _obscurePassword,
                              autofillHints: [_registering ? AutofillHints.newPassword : AutofillHints.password],
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                                  icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (value) => value != null && value.length >= 8 ? null : 'Use at least 8 characters',
                              onFieldSubmitted: (_) => _submit(),
                            ),
                            if (!_registering) ...[
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(onPressed: () {}, child: const Text('Forgot password?')),
                              ),
                            ] else const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _submitting ? null : _submit,
                                child: _submitting
                                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : Text(_registering ? 'Create account' : 'Sign in'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _submitting ? null : () => setState(() => _registering = !_registering),
                    child: Text(_registering ? 'Already have an account? Sign in' : 'New to PaceHealth? Create an account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
