import 'package:viernes/ai/learning/personal_model.dart';
import 'package:viernes/ai/nlu/es/spanish_rule_interpreter.dart';
import 'package:viernes/ai/nlu/interpretation.dart';
import 'package:viernes/ai/nlu/ml/neural_tagger.dart';
import 'package:viernes/ai/nlu/reminder_interpreter.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';

/// Intérprete híbrido: las reglas entienden la frase, la red neuronal propia
/// llena lo que las reglas no supieron y el modelo personal la ajusta a las
/// costumbres del usuario.
///
/// Las reglas siguen siendo la base (funcionan desde el primer día); lo
/// aprendido solo se aplica cuando hay evidencia suficiente.
class HybridInterpreter implements ReminderInterpreter {
  HybridInterpreter({
    required this._rules,
    required this._personal,
    this._neural,
    this._preferNeuralTitles,
  });

  final ReminderInterpreter _rules;

  /// Modelo personal vigente, o `null` si el aprendizaje está apagado o aún
  /// no se ha entrenado.
  final PersonalModel? Function() _personal;

  /// Red neuronal propia (`assets/ai/nlu_model.json`), o `null` si no cargó.
  final NeuralTagger? Function()? _neural;

  /// Modo experimental: la red decide el título cuando está muy segura.
  final bool Function()? _preferNeuralTitles;

  static const version = 'hybrid-1.1';

  /// Confianza para que el modelo reemplace la categoría de las reglas.
  static const overrideConfidence = 0.75;

  /// Confianza para que el modelo decida cuando las reglas no supieron.
  static const fillConfidence = 0.5;

  /// Confianza de la red para crear un recordatorio que las reglas no
  /// entendieron.
  static const neuralIntentConfidence = 0.85;

  /// Confianza de la red en el título para usarlo.
  static const neuralTitleConfidence = 0.7;

  /// Confianza para reemplazar el título de las reglas (modo experimental).
  static const neuralOverrideConfidence = 0.9;

  @override
  Future<Interpretation> interpret(
    String text,
    DateTime now, {
    MissingSlot? expecting,
  }) async {
    var result = await _rules.interpret(text, now, expecting: expecting);
    final tagger = _neural?.call();
    // Las respuestas cortas a una pregunta ("a las 3") no son frases
    // completas: ahí mandan las reglas.
    if (tagger != null && expecting == null) {
      result = combineWithNeural(
        result,
        tagger.tag(text),
        neuralVersion: tagger.version,
        preferNeuralTitle: _preferNeuralTitles?.call() ?? false,
      );
    }
    final model = _personal();
    if (model == null || result.intent != VoiceIntent.createReminder) {
      return result;
    }
    return Interpretation(
      text: result.text,
      intent: result.intent,
      reminder: personalize(result.reminder, model),
      agenda: result.agenda,
      confidence: result.confidence,
      interpreterVersion: '$version+${result.interpreterVersion}',
    );
  }

  /// Combina lo que dijeron las reglas con lo que entendió la red.
  static Interpretation combineWithNeural(
    Interpretation base,
    TaggerResult neural, {
    required String neuralVersion,
    bool preferNeuralTitle = false,
  }) {
    final task = neural.span('TAREA');
    final title = task == null
        ? ''
        : SpanishRuleInterpreter.cleanTitle(task.text);
    final createsReminder =
        neural.intent == 'crear' &&
        neural.intentConfidence >= neuralIntentConfidence;

    Interpretation withTitle(VoiceIntent intent, double confidence) =>
        Interpretation(
          text: base.text,
          intent: intent,
          reminder: base.reminder.copyWith(title: title),
          agenda: base.agenda,
          confidence: confidence,
          interpreterVersion: '${base.interpreterVersion}+$neuralVersion',
        );

    if (title.isEmpty || task!.confidence < neuralTitleConfidence) return base;

    // 1. Las reglas no entendieron, pero la red ve un recordatorio.
    if (base.intent == VoiceIntent.unknown && createsReminder) {
      return withTitle(
        VoiceIntent.createReminder,
        neural.intentConfidence * task.confidence,
      );
    }
    if (base.intent != VoiceIntent.createReminder) return base;

    // 2. Las reglas entendieron la fecha pero no qué hacer.
    if (base.reminder.title.isEmpty) {
      return withTitle(base.intent, base.confidence);
    }

    // 3. Experimental: la red decide el título si está muy segura.
    if (preferNeuralTitle &&
        task.confidence >= neuralOverrideConfidence &&
        title != base.reminder.title) {
      return withTitle(base.intent, base.confidence);
    }
    return base;
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
