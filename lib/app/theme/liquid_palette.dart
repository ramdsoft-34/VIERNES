import 'package:flutter/material.dart';

/// Colores del diseño Liquid: grafito, luz ambiental que el vidrio refracta y
/// un único acento («iris», un índigo violáceo: calma y confianza, sin verdes).
/// Lo «hecho» y «permitido» usan el mismo acento, no un verde aparte.
///
/// Ember y cobalto son solo luz de fondo; nunca se usan en botones ni texto.
@immutable
class LiquidPalette extends ThemeExtension<LiquidPalette> {
  const LiquidPalette({
    required this.ink,
    required this.inkRaised,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
    required this.accentText,
    required this.ember,
    required this.cobalt,
    required this.danger,
    required this.success,
    required this.glassFill,
    required this.glassBorder,
    required this.glassHighlight,
    required this.hairline,
    required this.shadow,
    required this.ambientStrength,
  });

  /// Fondo base.
  final Color ink;

  /// Hojas, diálogos y superficies sólidas.
  final Color inkRaised;
  final Color text;
  final Color textSecondary;
  final Color textMuted;

  /// El acento. Relleno de la acción principal y de lo «ahora».
  final Color accent;
  final Color onAccent;

  /// El acento como texto (legible sobre el fondo).
  final Color accentText;

  /// Luz cálida de fondo y lo vencido.
  final Color ember;

  /// Luz fría de fondo.
  final Color cobalt;
  final Color danger;
  final Color success;

  /// Relleno del vidrio (sobre el desenfoque).
  final Color glassFill;
  final Color glassBorder;

  /// Brillo del borde superior del vidrio (luz que lo atraviesa).
  final Color glassHighlight;
  final Color hairline;
  final Color shadow;

  /// Intensidad de las manchas de luz (0-1).
  final double ambientStrength;

  static const dark = LiquidPalette(
    ink: Color(0xFF0B0D11),
    inkRaised: Color(0xFF151820),
    text: Color(0xFFF2F4F1),
    textSecondary: Color(0x9EF2F4F1),
    textMuted: Color(0x61F2F4F1),
    accent: Color(0xFFA594FF),
    onAccent: Color(0xFF140A3D),
    accentText: Color(0xFFBBAFFF),
    ember: Color(0xFFFF7A59),
    cobalt: Color(0xFF3B5BFF),
    danger: Color(0xFFFF7A6B),
    success: Color(0xFFBBAFFF),
    glassFill: Color(0x3D1A1E26),
    glassBorder: Color(0x29FFFFFF),
    glassHighlight: Color(0x52FFFFFF),
    hairline: Color(0x1FFFFFFF),
    shadow: Color(0x73030614),
    ambientStrength: 1,
  );

  static const light = LiquidPalette(
    ink: Color(0xFFECECF3),
    inkRaised: Color(0xFFF8F8FC),
    text: Color(0xFF12131A),
    textSecondary: Color(0xA612131A),
    textMuted: Color(0x7012131A),
    accent: Color(0xFF5B4BE8),
    onAccent: Color(0xFFFFFFFF),
    accentText: Color(0xFF4B3BD8),
    ember: Color(0xFFFF9B73),
    cobalt: Color(0xFF7086FF),
    danger: Color(0xFFC8341F),
    success: Color(0xFF4B3BD8),
    glassFill: Color(0x8CFFFFFF),
    glassBorder: Color(0xB3FFFFFF),
    glassHighlight: Color(0xE6FFFFFF),
    hairline: Color(0x1A101318),
    shadow: Color(0x2E202838),
    ambientStrength: 0.55,
  );

  static LiquidPalette of(BuildContext context) =>
      Theme.of(context).extension<LiquidPalette>() ?? dark;

  @override
  LiquidPalette copyWith() => this;

  @override
  LiquidPalette lerp(LiquidPalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return LiquidPalette(
      ink: c(ink, other.ink),
      inkRaised: c(inkRaised, other.inkRaised),
      text: c(text, other.text),
      textSecondary: c(textSecondary, other.textSecondary),
      textMuted: c(textMuted, other.textMuted),
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      accentText: c(accentText, other.accentText),
      ember: c(ember, other.ember),
      cobalt: c(cobalt, other.cobalt),
      danger: c(danger, other.danger),
      success: c(success, other.success),
      glassFill: c(glassFill, other.glassFill),
      glassBorder: c(glassBorder, other.glassBorder),
      glassHighlight: c(glassHighlight, other.glassHighlight),
      hairline: c(hairline, other.hairline),
      shadow: c(shadow, other.shadow),
      ambientStrength:
          ambientStrength + (other.ambientStrength - ambientStrength) * t,
    );
  }
}

/// Curvas del movimiento: resorte con un poco de rebote (tras un gesto) y
/// asentamiento suave (sin rebote, lo normal).
abstract final class LiquidMotion {
  static const spring = Cubic(0.32, 1.28, 0.48, 1);
  static const settle = Cubic(0.22, 1, 0.36, 1);
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 420);
  static const slow = Duration(milliseconds: 650);

  /// Respeta «quitar animaciones» de Android.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;
}

/// Radios: una sola escala para toda la app.
abstract final class LiquidRadius {
  static const sm = 14.0;
  static const md = 22.0;
  static const lg = 28.0;
  static const pill = 999.0;
}
