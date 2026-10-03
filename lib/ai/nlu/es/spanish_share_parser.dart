import 'package:viernes/ai/nlu/es/spanish_text.dart';

/// «Recuérdale a Sofi recoger el paquete mañana a las 5».
typedef ShareRequest = ({String afterTo});

/// «Agrega leche y pan a la lista del mercado». `assignee`: «… para Sofi»
/// (quién debe hacerlo), tal como se dijo.
typedef ListAddRequest = ({
  List<String> items,
  String listName,
  String? assignee,
});

/// Frases para compartir con otras personas.
abstract final class SpanishShareParser {
  static final _share = RegExp(
    r'^(?:(?:oye\s+)?viernes[,\s]+)?(?:por favor\s+)?'
    r'(?:recuerdale|recordarle|avisale|dile|mandale un recordatorio)\s+a\s+(.+)$',
  );

  static final _listAdd = RegExp(
    r'^(?:(?:oye\s+)?viernes[,\s]+)?(?:por favor\s+)?'
    r'(?:agrega|agregar|agregale|anade|anadir|pon|ponle|anota|apunta|mete)\s+'
    r'(.+?)\s+(?:a|en)\s+(?:la\s+)?lista\s+'
    r'(?:de\s+(?:la\s+|las\s+|los\s+)?|del\s+|para\s+(?:el\s+|la\s+)?)?(.+)$',
  );

  static final _listRead = RegExp(
    r'^(?:(?:oye\s+)?viernes[,\s]+)?(?:que (?:hay|tengo|falta) en|leeme|lee|'
    r'dime|que dice)\s+(?:la\s+)?lista\s+(?:de\s+(?:la\s+|las\s+|los\s+)?|del\s+)?(.+)$',
  );

  static final _listMine = RegExp(
    r'^(?:(?:oye\s+)?viernes[,\s]+)?que\s+(?:me\s+toca(?:\s+hacer)?|'
    r'tengo\s+asignado|me\s+asignaron)\s+(?:en|de)\s+(?:la\s+)?lista\s+'
    r'(?:de\s+(?:la\s+|las\s+|los\s+)?|del\s+)?(.+)$',
  );

  /// «… a la lista de la casa para Sofi»: la persona va al final.
  static final _assignee = RegExp(r'^(.+)\s+para\s+(.+)$');

  static String _clean(String text) => SpanishText.fold(
    text,
  ).replaceAll(RegExp('[¡!¿?.]+'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Devuelve lo que sigue a «a» (nombre + tarea) en el texto original.
  static ShareRequest? parseShare(String text) {
    final original = text.trim().replaceAll(RegExp(r'[.!¡¿?]+$'), '');
    final folded = SpanishText.fold(original);
    final m = _share.firstMatch(folded);
    if (m == null) return null;
    return (afterTo: original.substring(m.end - m[1]!.length).trim());
  }

  static ListAddRequest? parseListAdd(String text) {
    final original = text.trim().replaceAll(RegExp(r'[.!¡¿?]+$'), '');
    final folded = SpanishText.fold(original);
    final m = _listAdd.firstMatch(folded);
    if (m == null) return null;
    final itemsStart = m.start + m[0]!.indexOf(m[1]!);
    final rawItems = original.substring(itemsStart, itemsStart + m[1]!.length);
    final items = [
      for (final part in rawItems.split(RegExp(r'\s*,\s*|\s+y\s+|\s+e\s+')))
        if (part.trim().isNotEmpty) _capitalize(part.trim()),
    ];
    if (items.isEmpty) return null;
    var listName = _clean(m[2]!);
    String? assignee;
    final who = _assignee.firstMatch(listName);
    if (who != null) {
      listName = who[1]!.trim();
      // El nombre se toma del texto original (con mayúsculas y tildes).
      final start =
          original.length - m[2]!.length + m[2]!.lastIndexOf(' para ');
      assignee = original.substring(start + ' para '.length).trim();
    }
    return (items: items, listName: listName, assignee: assignee);
  }

  /// «¿Qué me toca en la lista de la casa?» → «casa».
  static String? parseListMine(String text) {
    final m = _listMine.firstMatch(_clean(text));
    return m?[1]?.trim();
  }

  static String? parseListRead(String text) {
    final m = _listRead.firstMatch(_clean(text));
    return m?[1]?.trim();
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
