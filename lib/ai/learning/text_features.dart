import 'package:viernes/ai/nlu/es/spanish_text.dart';

/// Convierte un título en "palabras clave" comparables para el aprendizaje.
abstract final class TextFeatures {
  static const _stopwords = {
    'el', 'la', 'los', 'las', 'un', 'una', 'unos', 'unas', 'de', 'del', 'a', //
    'al', 'y', 'e', 'o', 'u', 'en', 'con', 'por', 'para', 'que', 'mi', 'mis',
    'tu', 'tus', 'su', 'sus', 'lo', 'le', 'les', 'se', 'me', 'te', 'es',
  };

  static final _separator = RegExp('[^a-z0-9]+');

  /// "Pagar las facturas del banco" → `[pagar, factur, banco]`.
  static List<String> tokens(String text) => SpanishText.fold(text)
      .split(_separator)
      .where((t) => t.length > 1 && !_stopwords.contains(t))
      .map(_stem)
      .toList();

  /// Raíz muy simple: quita plurales para que "factura" y "facturas"
  /// cuenten como la misma palabra.
  static String _stem(String token) {
    if (token.length > 5 && token.endsWith('es')) {
      return token.substring(0, token.length - 2);
    }
    if (token.length > 3 && token.endsWith('s')) {
      return token.substring(0, token.length - 1);
    }
    return token;
  }
}
