import 'package:flutter/foundation.dart';
import 'package:viernes/ai/nlu/es/spanish_rule_interpreter.dart';
import 'package:viernes/ai/nlu/es/spanish_text.dart';
import 'package:viernes/features/places/domain/place.dart';

/// «Comprar leche cuando llegue a casa» / «al salir del trabajo».
@immutable
class PlaceTriggerRequest {
  const PlaceTriggerRequest({
    required this.onArrive,
    required this.placeText,
    required this.task,
  });

  final bool onArrive;

  /// Cómo nombró el lugar («casa», «el súper»).
  final String placeText;
  final String task;
}

/// Reconoce pedidos atados a un lugar en vez de a una hora.
abstract final class SpanishPlaceTrigger {
  static final _arrive = RegExp(
    r'\b(?:cuando\s+(?:llegue|este|pase|vaya|entre|me\s+acerque)|'
    r'al\s+(?:llegar|pasar|entrar|estar)|apenas\s+llegue|llegando)\s+'
    r'(?:(?:a|al|en|por|cerca\s+de(?:l)?|de)\s+)?(?:(?:la|el|mi|los|las)\s+)?'
    r'([a-z0-9 ]+?)\s*$',
  );
  static final _leave = RegExp(
    r'\b(?:cuando\s+(?:salga|me\s+vaya)|al\s+salir|saliendo)\s+'
    r'(?:(?:de|del)\s+)?(?:(?:la|el|mi|los|las)\s+)?'
    r'([a-z0-9 ]+?)\s*$',
  );

  static PlaceTriggerRequest? parse(String input) {
    final text = input.trim().replaceAll(RegExp(r'[.?!¡¿,]+$'), '');
    final folded = SpanishText.fold(text);
    for (final (pattern, onArrive) in [(_leave, false), (_arrive, true)]) {
      final m = pattern.firstMatch(folded);
      if (m == null) continue;
      final place = m[1]!.trim();
      if (place.isEmpty) continue;
      return PlaceTriggerRequest(
        onArrive: onArrive,
        placeText: place,
        task: SpanishRuleInterpreter.cleanTitle(text.substring(0, m.start)),
      );
    }
    return null;
  }

  /// El lugar guardado que corresponde a [placeText].
  static Place? findPlace(String placeText, Iterable<Place> places) {
    final wanted = SpanishText.fold(placeText).trim();
    Place? partial;
    for (final place in places) {
      final key = place.key;
      if (key == wanted) return place;
      if (wanted.contains(key) || key.contains(wanted)) partial ??= place;
    }
    return partial;
  }
}
