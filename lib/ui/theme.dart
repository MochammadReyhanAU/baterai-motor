import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF0B1220);
  static const surface = Color(0xFF131C2E);
  static const surface2 = Color(0xFF1A2540);
  static const line = Color(0xFF26324D);
  static const text = Color(0xFFE8EEF9);
  static const muted = Color(0xFF8D9AB5);
  static const good = Color(0xFF34D399);
  static const caution = Color(0xFFFBBF24);
  static const bad = Color(0xFFF87171);
  static const info = Color(0xFF60A5FA);
  static const accent = Color(0xFF22D3EE);

  static const motorColors = <Color>[
    Color(0xFF22D3EE), // cyan
    Color(0xFFF97316), // oranye
    Color(0xFFE11D48), // merah
    Color(0xFFA3E635), // hijau stabilo
    Color(0xFFE2E8F0), // putih
    Color(0xFF475569), // abu gelap
  ];
}

const tabular = [FontFeature.tabularFigures()];

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: Brightness.dark,
    surface: AppColors.surface,
  ).copyWith(primary: AppColors.accent, onPrimary: const Color(0xFF042F36));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.accent.withValues(alpha: 0.18),
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: AppColors.text),
      bodySmall: TextStyle(color: AppColors.muted),
    ),
    dividerColor: AppColors.line,
    sliderTheme: const SliderThemeData(showValueIndicator: ShowValueIndicator.onDrag),
  );
}
