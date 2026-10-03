import 'package:viernes/ai/nlu/interpretation.dart';

/// Convierte una frase dictada en una intención con sus datos.
///
/// Hoy lo implementa un motor de reglas en español. En la Fase 6 se suma un
/// modelo propio entrenado; ambos cumplen este contrato y un intérprete
/// híbrido decide cuál usar según la confianza.
abstract interface class ReminderInterpreter {
  /// [expecting] indica qué se le acaba de preguntar al usuario, para
  /// aceptar respuestas cortas ("a las 3", "tres", "mañana").
  Future<Interpretation> interpret(
    String text,
    DateTime now, {
    MissingSlot? expecting,
  });
}
