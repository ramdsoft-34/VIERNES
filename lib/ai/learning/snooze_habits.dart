import 'package:shared_preferences/shared_preferences.dart';

/// Cuánto suele posponer el usuario cuando lo elige él mismo.
///
/// Ejemplo: si casi siempre toca «10 minutos», ese pasa a ser el tiempo del
/// botón de la notificación y de «recuérdamelo después» por voz.
class SnoozeHabits {
  SnoozeHabits(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'learning.snoozeChoices';

  /// Elecciones recientes que se tienen en cuenta.
  static const window = 20;

  /// Mínimo de elecciones para confiar en la costumbre.
  static const minSamples = 3;

  /// Posponer más de esto (p. ej. «mañana») no es una costumbre de tiempo.
  static const _maxHabit = Duration(hours: 6);

  List<Duration> choices() => [
    for (final value in _prefs.getStringList(_key) ?? const <String>[])
      if (int.tryParse(value) case final minutes?) Duration(minutes: minutes),
  ];

  /// Registra un tiempo elegido a mano (no el automático del botón).
  Future<void> record(Duration delay) async {
    if (delay <= Duration.zero || delay > _maxHabit) return;
    final recent = [...choices(), delay];
    final kept = recent.length > window
        ? recent.sublist(recent.length - window)
        : recent;
    await _prefs.setStringList(_key, [
      for (final d in kept) '${d.inMinutes}',
    ]);
  }

  /// El tiempo más elegido, solo si es claro (al menos la mitad de las
  /// veces).
  Duration? learned() {
    final all = choices();
    if (all.length < minSamples) return null;
    final counts = <Duration, int>{};
    for (final d in all) {
      counts.update(d, (c) => c + 1, ifAbsent: () => 1);
    }
    final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return top.value * 2 >= all.length ? top.key : null;
  }

  /// Lo aprendido o, si aún no hay costumbre, [fallback].
  Duration preferred(Duration fallback, {bool enabled = true}) =>
      enabled ? learned() ?? fallback : fallback;

  /// [options] ordenadas de la más usada a la menos (empates: orden
  /// original).
  List<Duration> ordered(List<Duration> options) {
    final counts = <Duration, int>{};
    for (final d in choices()) {
      counts.update(d, (c) => c + 1, ifAbsent: () => 1);
    }
    final indexed = options.indexed.toList()
      ..sort((a, b) {
        final byCount = (counts[b.$2] ?? 0).compareTo(counts[a.$2] ?? 0);
        return byCount != 0 ? byCount : a.$1.compareTo(b.$1);
      });
    return [for (final (_, d) in indexed) d];
  }

  Future<void> clear() => _prefs.remove(_key);
}
