import 'package:flutter/material.dart';

import '../../state/profile_store.dart';
import '../../services/api_service.dart';

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
      final session = await ApiService().authenticate(
        email: _email.text.trim(),
        password: _password.text,
        register: _registering,
      );
      if (mounted) widget.store.signIn(session.email);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
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
