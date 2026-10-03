import 'package:viernes/ai/nlu/es/spanish_text.dart';

/// Separa un título con varias tareas: «pagar la luz y llamar a mi mamá» →
/// [«Pagar la luz», «Llamar a mi mamá»].
///
/// Solo corta en «y» o comas cuando lo que sigue empieza con un verbo en
/// infinitivo, para no partir «comprar pan y leche» (una sola tarea).
abstract final class SpanishTaskSplitter {
  /// Separadores: «, y», «y luego», «y también», «y después», «,».
  static final _separator = RegExp(
    r'\s*(?:,\s*(?:y\s+)?|\s+y\s+(?:luego\s+|tambien\s+|despues\s+|ademas\s+)?|'
    r'\s+ademas\s+)',
  );

  /// Infinitivo con pronombres pegados (llamarla, mandarle, tomarme…).
  static final _infinitive = RegExp(
    r'^[a-z]{2,}(?:ar|er|ir)'
    r'(?:me|te|le|les|lo|la|los|las|se|nos)?(?:lo|la|los|las)?$',
  );

  /// Palabras terminadas en -ar/-er/-ir que no son verbos.
  static const _notVerbs = {
    'lugar',
    'hogar',
    'mujer',
    'ayer',
    'bar',
    'mar',
    'collar',
    'azucar',
    'militar',
    'popular',
    'particular',
    'familiar',
    'altar',
    'dolar',
    'par',
    'celular',
    'taller',
    'alquiler',
    'placer',
    'cancer',
    'super',
    'poder',
    'deber',
    'ser',
    'amanecer',
    'atardecer',
    'nectar',
    'radar',
    'solar',
    'regular',
    'escolar',
    'titular',
    'auxiliar',
    'similar',
    'hangar',
    'jaguar',
    'lunar',
    'polar',
    'cuadrar',
    'menor',
    'mayor',
    'motor',
    'zafir',
    'elixir',
    'faquir',
    'tapir',
    'emir',
    'nadir',
  };

  static bool _startsWithVerb(String part) {
    final words = SpanishText.fold(part).trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return false;
    final first = words.first.replaceAll(RegExp('[^a-z]'), '');
    return _infinitive.hasMatch(first) && !_notVerbs.contains(first);
  }

  /// Las tareas del título, o una sola si no hay varias claras.
  static List<String> split(String title) {
    final text = title.trim();
    if (text.isEmpty) return const [];
    final folded = SpanishText.fold(text);
    final cuts = <int>[0];
    final ends = <int>[];
    for (final m in _separator.allMatches(folded)) {
      final rest = folded.substring(m.end);
      final before = folded.substring(cuts.last, m.start);
      if (_startsWithVerb(rest) && _startsWithVerb(before)) {
        ends.add(m.start);
        cuts.add(m.end);
      }
    }
    if (ends.isEmpty) return [text];
    ends.add(text.length);
    return [
      for (var i = 0; i < cuts.length; i++)
        if (text.substring(cuts[i], ends[i]).trim() case final part
            when part.isNotEmpty)
          _capitalize(part),
    ];
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
