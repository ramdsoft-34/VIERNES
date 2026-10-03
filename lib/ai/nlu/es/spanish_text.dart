// Expresiones regulares armadas por partes.
// ignore_for_file: unnecessary_raw_strings

/// Utilidades de texto para español.
abstract final class SpanishText {
  static const _fold = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n', //
    'à': 'a', 'è': 'e', 'ì': 'i', 'ò': 'o', 'ù': 'u',
  };

  /// Minúsculas y sin tildes, **conservando la longitud**: la posición `i`
  /// del resultado corresponde a la posición `i` del original. Así se busca
  /// sobre el texto normalizado y se recorta sobre el original (que conserva
  /// mayúsculas y tildes para el título).
  static String fold(String text) {
    final buffer = StringBuffer();
    for (final unit in text.split('')) {
      final lower = unit.toLowerCase();
      final folded = _fold[lower] ?? lower;
      // Si un carácter cambiara de longitud al pasarlo a minúsculas, se
      // conserva el original para no desalinear las posiciones.
      buffer.write(folded.length == unit.length ? folded : unit);
    }
    return buffer.toString();
  }

  static const _numbers = <String, int>{
    'cero': 0,
    'un': 1,
    'uno': 1,
    'una': 1,
    'primero': 1,
    'dos': 2,
    'tres': 3,
    'cuatro': 4,
    'cinco': 5,
    'seis': 6,
    'siete': 7,
    'ocho': 8,
    'nueve': 9,
    'diez': 10,
    'once': 11,
    'doce': 12,
    'trece': 13,
    'catorce': 14,
    'quince': 15,
    'dieciseis': 16,
    'diecisiete': 17,
    'dieciocho': 18,
    'diecinueve': 19,
    'veinte': 20,
    'veintiun': 21,
    'veintiuno': 21,
    'veintiuna': 21,
    'veintidos': 22,
    'veintitres': 23,
    'veinticuatro': 24,
    'veinticinco': 25,
    'veintiseis': 26,
    'veintisiete': 27,
    'veintiocho': 28,
    'veintinueve': 29,
    'treinta': 30,
    'cuarenta': 40,
    'cincuenta': 50,
  };

  static const _tens = 'treinta|cuarenta|cincuenta';
  static const _digitWords =
      'uno|una|un|dos|tres|cuatro|cinco|seis|siete|'
      'ocho|nueve';

  static final String _wordAlternation =
      (_numbers.keys.toList()..sort((a, b) => b.length.compareTo(a.length)))
          .join('|');

  /// Número en cifras o palabras ("8", "ocho", "treinta y cinco").
  static final String number =
      r'(?:\d{1,4}|(?:'
      '$_tens'
      r')\s+y\s+(?:'
      '$_digitWords'
      r')|'
      '$_wordAlternation)';

  /// Igual que [number] pero sin "un/uno/una", para no confundir
  /// "a las 2 y una reunión" con 2:01.
  static final String minuteNumber =
      r'(?:\d{1,2}|(?:'
      '$_tens'
      r')\s+y\s+(?:'
      '$_digitWords'
      r')|'
      '$_minuteWordAlternation)';

  static const _notMinutes = {'un', 'uno', 'una', 'cero', 'primero'};

  static final String _minuteWordAlternation =
      (_numbers.keys.where((k) => !_notMinutes.contains(k)).toList()
            ..sort((a, b) => b.length.compareTo(a.length)))
          .join('|');

  /// Convierte "8", "ocho" o "treinta y cinco" a entero.
  static int? parseNumber(String? raw) {
    if (raw == null) return null;
    final text = raw.trim();
    final digits = int.tryParse(text);
    if (digits != null) return digits;
    final compound = RegExp(r'^(\w+)\s+y\s+(\w+)$').firstMatch(text);
    if (compound != null) {
      final tens = _numbers[compound.group(1)];
      final units = _numbers[compound.group(2)];
      if (tens != null && units != null) return tens + units;
    }
    return _numbers[text];
  }

  static const weekdays = <String, int>{
    'lunes': DateTime.monday,
    'martes': DateTime.tuesday,
    'miercoles': DateTime.wednesday,
    'jueves': DateTime.thursday,
    'viernes': DateTime.friday,
    'sabado': DateTime.saturday,
    'domingo': DateTime.sunday,
  };

  static const weekdayPattern =
      '(?:lunes|martes|miercoles|jueves|viernes|sabado|domingo)';

  static const months = <String, int>{
    'enero': 1,
    'febrero': 2,
    'marzo': 3,
    'abril': 4,
    'mayo': 5,
    'junio': 6,
    'julio': 7,
    'agosto': 8,
    'septiembre': 9,
    'setiembre': 9,
    'octubre': 10,
    'noviembre': 11,
    'diciembre': 12,
  };

  static final String monthPattern = '(?:${months.keys.join('|')})';
}
