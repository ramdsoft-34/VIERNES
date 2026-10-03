import 'package:flutter/material.dart';
import 'package:viernes/app/theme/liquid_palette.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';

export 'package:viernes/app/theme/liquid_palette.dart';

/// Tema «Liquid»: grafito con luz ambiental, vidrio y un único acento.
///
/// Unifica los skills de diseño instalados: taste (sin clichés, Geist, un
/// acento), apple-design (respuesta inmediata, resortes, tipografía con
/// tracking según el tamaño) y ui-ux-pro-max (contraste, toques de 44 px).
abstract final class AppTheme {
  /// Acento de Viernes (iris).
  static const seed = Color(0xFFA594FF);

  static const font = 'Geist';
  static const mono = 'GeistMono';

  static ThemeData light() => _build(LiquidPalette.light, Brightness.light);

  static ThemeData dark() => _build(LiquidPalette.dark, Brightness.dark);

  /// Texto con números de ancho fijo (horas, cuentas regresivas).
  static TextStyle monoStyle(TextStyle? base) =>
      (base ?? const TextStyle()).copyWith(
        fontFamily: mono,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextTheme _text(LiquidPalette p) {
    // Tracking según el tamaño: negativo en títulos grandes, casi cero en
    // el cuerpo y un poco positivo en lo pequeño.
    TextStyle s(
      double size,
      FontWeight weight,
      double tracking,
      double height, {
      Color? color,
    }) => TextStyle(
      fontFamily: font,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: size * tracking,
      height: height,
      color: color ?? p.text,
    );
    return TextTheme(
      displayLarge: s(88, FontWeight.w400, -0.06, 0.92),
      displayMedium: s(64, FontWeight.w500, -0.055, 0.94),
      displaySmall: s(48, FontWeight.w500, -0.05, 0.98),
      headlineLarge: s(40, FontWeight.w500, -0.045, 1),
      headlineMedium: s(32, FontWeight.w500, -0.04, 1.05),
      headlineSmall: s(26, FontWeight.w500, -0.03, 1.1),
      titleLarge: s(21, FontWeight.w500, -0.02, 1.2),
      titleMedium: s(16, FontWeight.w500, -0.01, 1.3),
      titleSmall: s(14, FontWeight.w500, 0, 1.3),
      bodyLarge: s(16, FontWeight.w400, 0, 1.5),
      bodyMedium: s(14, FontWeight.w400, 0, 1.45, color: p.textSecondary),
      bodySmall: s(12.5, FontWeight.w400, 0.005, 1.4, color: p.textSecondary),
      labelLarge: s(15, FontWeight.w500, 0, 1.2),
      labelMedium: s(13, FontWeight.w500, 0.005, 1.2),
      labelSmall: s(11.5, FontWeight.w500, 0.02, 1.2, color: p.textSecondary),
    );
  }

  static ThemeData _build(LiquidPalette p, Brightness brightness) {
    final text = _text(p);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.accent,
      onPrimary: p.onAccent,
      primaryContainer: p.accent.withValues(alpha: 0.18),
      onPrimaryContainer: p.accentText,
      secondary: p.textSecondary,
      onSecondary: p.ink,
      secondaryContainer: p.glassFill,
      onSecondaryContainer: p.text,
      tertiary: p.ember,
      onTertiary: p.ink,
      tertiaryContainer: p.ember.withValues(alpha: 0.18),
      onTertiaryContainer: p.text,
      error: p.danger,
      onError: p.ink,
      surface: p.ink,
      onSurface: p.text,
      onSurfaceVariant: p.textSecondary,
      surfaceContainerLowest: p.ink,
      surfaceContainerLow: p.inkRaised.withValues(alpha: 0.6),
      surfaceContainer: p.inkRaised,
      surfaceContainerHigh: p.inkRaised,
      surfaceContainerHighest: p.text.withValues(alpha: 0.08),
      outline: p.textMuted,
      outlineVariant: p.hairline,
      shadow: p.shadow,
      inverseSurface: p.text,
      onInverseSurface: p.ink,
    );
    final pill = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LiquidRadius.md),
    );
    final glassSide = BorderSide(color: p.glassBorder);
    final field = BorderRadius.circular(LiquidRadius.sm + 4);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: font,
      textTheme: text,
      extensions: [p],
      scaffoldBackgroundColor: p.ink,
      canvasColor: p.ink,
      highlightColor: p.text.withValues(alpha: 0.04),
      dividerTheme: DividerThemeData(color: p.hairline, space: 1),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: p.text,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: p.glassFill,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LiquidRadius.md),
          side: glassSide,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.text,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodySmall,
        minVerticalPadding: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LiquidRadius.md),
        ),
      ),
      iconTheme: IconThemeData(color: p.text, size: 22),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          textStyle: text.labelLarge,
          shape: pill,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: p.glassFill,
          foregroundColor: p.text,
          minimumSize: const Size(64, 52),
          shape: pill,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          backgroundColor: p.text.withValues(alpha: 0.05),
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          side: glassSide,
          textStyle: text.labelLarge,
          shape: pill,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.text,
          minimumSize: const Size(48, 44),
          textStyle: text.labelLarge,
          shape: pill,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: p.text,
          minimumSize: const Size(44, 44),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        elevation: 0,
        highlightElevation: 0,
        shape: pill,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.text.withValues(alpha: 0.06),
        labelStyle: text.bodyMedium,
        floatingLabelStyle: text.labelMedium?.copyWith(color: p.accentText),
        hintStyle: text.bodyMedium?.copyWith(color: p.textMuted),
        prefixIconColor: p.textSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: field,
          borderSide: BorderSide(color: p.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: field,
          borderSide: BorderSide(color: p.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: field,
          borderSide: BorderSide(color: p.accentText, width: 1.4),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? p.onAccent : p.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? p.accent
              : p.text.withValues(alpha: 0.1),
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accent : null,
        ),
        checkColor: WidgetStateProperty.all(p.onAccent),
        side: BorderSide(color: p.textMuted, width: 1.5),
        shape: const CircleBorder(),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accentText : p.textMuted,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.text.withValues(alpha: 0.07),
        selectedColor: p.accent,
        side: BorderSide(color: p.hairline),
        labelStyle: text.labelMedium,
        secondaryLabelStyle: text.labelMedium?.copyWith(color: p.onAccent),
        checkmarkColor: p.onAccent,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: p.text.withValues(alpha: 0.05),
          selectedBackgroundColor: p.accent,
          selectedForegroundColor: p.onAccent,
          foregroundColor: p.text,
          side: BorderSide(color: p.hairline),
          textStyle: text.labelMedium,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.accent,
        inactiveTrackColor: p.text.withValues(alpha: 0.12),
        thumbColor: p.accent,
        overlayColor: p.accent.withValues(alpha: 0.16),
        valueIndicatorColor: p.inkRaised,
        valueIndicatorTextStyle: text.labelMedium,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        linearTrackColor: p.text.withValues(alpha: 0.08),
        circularTrackColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.inkRaised,
        contentTextStyle: text.bodyMedium?.copyWith(color: p.text),
        actionTextColor: p.accentText,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LiquidRadius.md),
          side: glassSide,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.inkRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyLarge?.copyWith(color: p.textSecondary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LiquidRadius.lg),
          side: glassSide,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.inkRaised,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: p.shadow,
        dragHandleColor: p.textMuted,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.inkRaised,
        surfaceTintColor: Colors.transparent,
        textStyle: text.bodyLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LiquidRadius.md),
          side: glassSide,
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: p.inkRaised,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: p.inkRaised,
        headerForegroundColor: p.text,
        todayForegroundColor: WidgetStatePropertyAll(p.accentText),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LiquidRadius.lg),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: p.inkRaised,
        dialHandColor: p.accent,
        hourMinuteColor: p.text.withValues(alpha: 0.07),
        dayPeriodColor: p.accent.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LiquidRadius.lg),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        indicator: BoxDecoration(
          color: p.accent,
          borderRadius: BorderRadius.circular(LiquidRadius.pill),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerHeight: 0,
        labelColor: p.onAccent,
        unselectedLabelColor: p.textSecondary,
        labelStyle: text.labelMedium,
        unselectedLabelStyle: text.labelMedium,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.inkRaised,
          borderRadius: BorderRadius.circular(LiquidRadius.sm),
          border: Border.fromBorderSide(glassSide),
        ),
        textStyle: text.labelMedium,
      ),
    );
  }
}

/// Colores semánticos de prioridad.
extension PriorityColors on ReminderPriority {
  Color color(ColorScheme scheme) => switch (this) {
    ReminderPriority.low => scheme.outline,
    ReminderPriority.normal => scheme.onSurfaceVariant,
    ReminderPriority.high => scheme.tertiary,
    ReminderPriority.urgent => scheme.error,
  };
}

extension CategoryIcons on ReminderCategory {
  IconData get icon => switch (this) {
    ReminderCategory.personal => Icons.person_outline_rounded,
    ReminderCategory.work => Icons.work_outline_rounded,
    ReminderCategory.study => Icons.school_outlined,
    ReminderCategory.health => Icons.favorite_outline_rounded,
    ReminderCategory.home => Icons.home_outlined,
    ReminderCategory.finance => Icons.account_balance_wallet_outlined,
    ReminderCategory.other => Icons.label_outline_rounded,
  };
}
