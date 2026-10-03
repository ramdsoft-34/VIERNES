import 'package:flutter/material.dart';

/// Colores del diseño Liquid: grafito, luz ambiental que el vidrio refracta y
/// un único acento («voltio»).
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
    required this.volt,
    required this.onVolt,
    required this.voltText,
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
  final Color volt;
  final Color onVolt;

  /// El acento como texto (legible sobre el fondo).
  final Color voltText;

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
    volt: Color(0xFFD2F25C),
    onVolt: Color(0xFF1B2205),
    voltText: Color(0xFFD2F25C),
    ember: Color(0xFFFF7A45),
    cobalt: Color(0xFF2F5BFF),
    danger: Color(0xFFFF7A6B),
    success: Color(0xFF7BE0A0),
    glassFill: Color(0x3D1A1E26),
    glassBorder: Color(0x29FFFFFF),
    glassHighlight: Color(0x52FFFFFF),
    hairline: Color(0x1FFFFFFF),
    shadow: Color(0x73030614),
    ambientStrength: 1,
  );

  static const light = LiquidPalette(
    ink: Color(0xFFE8EBE5),
    inkRaised: Color(0xFFF6F7F4),
    text: Color(0xFF101318),
    textSecondary: Color(0xA6101318),
    textMuted: Color(0x70101318),
    volt: Color(0xFFC8EC45),
    onVolt: Color(0xFF1B2205),
    voltText: Color(0xFF4C6606),
    ember: Color(0xFFFF8A5C),
    cobalt: Color(0xFF5B7CFF),
    danger: Color(0xFFC8341F),
    success: Color(0xFF1F7A44),
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
      volt: c(volt, other.volt),
      onVolt: c(onVolt, other.onVolt),
      voltText: c(voltText, other.voltText),
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
