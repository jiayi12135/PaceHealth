import 'package:flutter/material.dart';
import 'state/profile_store.dart';
import 'screens/auth/login_screen.dart';
import 'screens/onboarding/questionnaire_screen.dart';
import 'screens/navigation/app_shell.dart';

void main() => runApp(PaceHealthApp(store: ProfileStore()));

class PaceHealthApp extends StatelessWidget {
  final ProfileStore store;
  const PaceHealthApp({super.key, required this.store});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (_, __) => MaterialApp(
      title: 'PaceHealth',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xff287d68), scaffoldBackgroundColor: const Color(0xfff6faf8), cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero)),
      home: !store.signedIn
          ? LoginScreen(store: store)
          : store.completed
              ? AppShell(store: store)
              : QuestionnaireScreen(store: store),
    ),
  );
}
