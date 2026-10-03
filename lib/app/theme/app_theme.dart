import 'package:flutter/material.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';

abstract final class AppTheme {
  /// Color de marca de Viernes.
  static const seed = Color(0xFF5B4CF0);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}

/// Colores semánticos de prioridad, coherentes en claro y oscuro.
extension PriorityColors on ReminderPriority {
  Color color(ColorScheme scheme) => switch (this) {
    ReminderPriority.low => scheme.outline,
    ReminderPriority.normal => scheme.primary,
    ReminderPriority.high => const Color(0xFFE8890C),
    ReminderPriority.urgent => scheme.error,
  };
}

extension CategoryIcons on ReminderCategory {
  IconData get icon => switch (this) {
    ReminderCategory.personal => Icons.person_outline,
    ReminderCategory.work => Icons.work_outline,
    ReminderCategory.study => Icons.school_outlined,
    ReminderCategory.health => Icons.favorite_outline,
    ReminderCategory.home => Icons.home_outlined,
    ReminderCategory.finance => Icons.account_balance_wallet_outlined,
    ReminderCategory.other => Icons.label_outline,
  };
}
