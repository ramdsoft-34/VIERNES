import 'package:viernes/ai/learning/personal_model.dart';
import 'package:viernes/ai/nlu/interpretation.dart';
import 'package:viernes/ai/nlu/reminder_interpreter.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';

/// Intérprete híbrido: las reglas entienden la frase y el modelo personal la
/// ajusta a las costumbres del usuario.
///
/// Las reglas siguen siendo la base (funcionan desde el primer día); lo
/// aprendido solo se aplica cuando hay evidencia suficiente. Cuando exista un
/// modelo neuronal propio, entrará aquí como otra fuente con su confianza.
class HybridInterpreter implements ReminderInterpreter {
  HybridInterpreter({
    required this._rules,
    required this._personal,
  });

  final ReminderInterpreter _rules;

  /// Modelo personal vigente, o `null` si el aprendizaje está apagado o aún
  /// no se ha entrenado.
  final PersonalModel? Function() _personal;

  static const version = 'hybrid-1.0';

  /// Confianza para que el modelo reemplace la categoría de las reglas.
  static const overrideConfidence = 0.75;

  /// Confianza para que el modelo decida cuando las reglas no supieron.
  static const fillConfidence = 0.5;

  @override
  Future<Interpretation> interpret(
    String text,
    DateTime now, {
    MissingSlot? expecting,
  }) async {
    final base = await _rules.interpret(text, now, expecting: expecting);
    final model = _personal();
    if (model == null || base.intent != VoiceIntent.createReminder) {
      return base;
    }
    final adjusted = personalize(base.reminder, model);
    return Interpretation(
      text: base.text,
      intent: base.intent,
      reminder: adjusted,
      agenda: base.agenda,
      confidence: base.confidence,
      interpreterVersion: '$version+${base.interpreterVersion}',
    );
  }

  /// Aplica lo aprendido a una interpretación.
  static ParsedReminder personalize(
    ParsedReminder parsed,
    PersonalModel model,
  ) {
    var result = parsed;

    // 1. Categoría: el modelo conoce el vocabulario propio del usuario.
    if (result.title.isNotEmpty) {
      final prediction = model.category.predict(result.title);
      if (prediction != null &&
          prediction.category != result.category &&
          (prediction.confidence >= overrideConfidence ||
              (result.category == ReminderCategory.other &&
                  prediction.confidence >= fillConfidence))) {
        result = result.copyWith(category: prediction.category);
      }
    }

    // 2. "En la tarde" → la hora a la que el usuario suele agendar.
    final period = result.dayPeriod;
    if (result.time == null && period != null) {
      final learned = model.habits.periodTimes[period];
      if (learned != null) result = result.withPeriodResolvedTo(learned);
    }

    // 3. Anticipación habitual para esa categoría (si no pidió otra y no es
    //    un límite, que ya tiene su propio margen).
    if (result.leadTime == null &&
        !result.isDeadline &&
        result.exactDue == null) {
      final lead = model.habits.leadTimes[result.category];
      if (lead != null) result = result.copyWith(leadTime: lead);
    }
    return result;
  }
}
