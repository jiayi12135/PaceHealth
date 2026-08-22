import 'package:flutter/material.dart';
import 'state/profile_store.dart';
import 'screens/auth/login_screen.dart';
import 'screens/onboarding/questionnaire_screen.dart';
import 'screens/navigation/app_shell.dart';
import 'theme.dart';

void main() => runApp(PaceHealthApp(store: ProfileStore()));

class PaceHealthApp extends StatelessWidget {
  final ProfileStore store;
  const PaceHealthApp({super.key, required this.store});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (_, __) => MaterialApp(
      title: 'PaceHealth',
      theme: paceHealthTheme,
      home: !store.signedIn
          ? LoginScreen(store: store)
          : store.completed
              ? AppShell(store: store)
              : QuestionnaireScreen(store: store),
    ),
  );
}
