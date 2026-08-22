import 'package:flutter/material.dart';

/// PaceHealth的视觉主题:暖色调、圆角、有活力,参考Headspace这类健康类app的风格,
/// 跟之前偏"临床冷淡"的绿色+直角卡片风格区分开。
const _coral = Color(0xFFFF6B4A);
const _cream = Color(0xFFFFF6EE);
const _sunshine = Color(0xFFFFB648);
const _leaf = Color(0xFF3FA796);
const _ink = Color(0xFF3A2E28);

final ThemeData paceHealthTheme = _buildTheme();

ThemeData _buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: _coral,
    brightness: Brightness.light,
  ).copyWith(
    primary: _coral,
    secondary: _sunshine,
    surface: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: _cream,
    appBarTheme: const AppBarTheme(
      backgroundColor: _cream,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w800),
      iconTheme: IconThemeData(color: _ink),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: _sunshine.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, color: _ink),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _coral,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _coral,
        side: const BorderSide(color: _coral, width: 1.4),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: _coral, textStyle: const TextStyle(fontWeight: FontWeight.w700)),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _coral,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _coral, width: 1.6)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: _coral.withOpacity(0.16),
      elevation: 0,
      height: 68,
      labelTextStyle: MaterialStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(MaterialState.selected) ? FontWeight.w800 : FontWeight.w500,
          color: states.contains(MaterialState.selected) ? _coral : Colors.grey.shade600,
        ),
      ),
      iconTheme: MaterialStateProperty.resolveWith(
        (states) => IconThemeData(color: states.contains(MaterialState.selected) ? _coral : Colors.grey.shade500),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.selected) ? _coral : Colors.grey.shade300),
      trackColor: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.selected) ? _coral.withOpacity(0.4) : Colors.grey.shade200),
    ),
    dividerTheme: DividerThemeData(color: Colors.grey.shade200, space: 1),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontWeight: FontWeight.w800, color: _ink),
      titleLarge: TextStyle(fontWeight: FontWeight.w800, color: _ink),
      titleMedium: TextStyle(fontWeight: FontWeight.w700, color: _ink),
      titleSmall: TextStyle(fontWeight: FontWeight.w700, color: _ink),
      bodyLarge: TextStyle(color: _ink),
      bodyMedium: TextStyle(color: Color(0xFF5B4D45)),
    ),
  );
}

/// 一组暖色调的强调色,给不同卡片/标签配色用,避免整个app只有一个珊瑚色显得单调。
const List<Color> paceHealthAccents = [_coral, _sunshine, _leaf, Color(0xFF6FA8DC), Color(0xFFB07CC6)];
