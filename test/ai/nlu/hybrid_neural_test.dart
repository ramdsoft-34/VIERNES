import 'package:flutter_test/flutter_test.dart';
import 'package:viernes/ai/nlu/hybrid_interpreter.dart';
import 'package:viernes/ai/nlu/interpretation.dart';
import 'package:viernes/ai/nlu/ml/neural_tagger.dart';

void main() {
  Interpretation rules(VoiceIntent intent, {String title = ''}) =>
      Interpretation(
        text: 'frase',
        intent: intent,
        reminder: ParsedReminder(title: title),
        confidence: 0.9,
        interpreterVersion: 'rules-es-1.0',
      );

  TaggerResult neural({
    String intent = 'crear',
    double intentConfidence = 0.97,
    String task = 'xilofonear el informe',
    double taskConfidence = 0.95,
  }) => TaggerResult(
    intent: intent,
    intentConfidence: intentConfidence,
    spans: [
      TaggedSpan(
        label: 'TAREA',
        start: 0,
        end: task.length,
        text: task,
        confidence: taskConfidence,
      ),
    ],
  );

  Interpretation combine(
    Interpretation base,
    TaggerResult nn, {
    bool prefer = false,
  }) => HybridInterpreter.combineWithNeural(
    base,
    nn,
    neuralVersion: 'nn-es-1.1',
    preferNeuralTitle: prefer,
  );

  test('si las reglas no entendieron, la red crea el recordatorio', () {
    final result = combine(rules(VoiceIntent.unknown), neural());

    expect(result.intent, VoiceIntent.createReminder);
    expect(result.reminder.title, 'Xilofonear el informe');
    expect(result.interpreterVersion, contains('nn-es-1.1'));
  });

  test('con poca confianza no inventa nada', () {
    final unsure = combine(
      rules(VoiceIntent.unknown),
      neural(intentConfidence: 0.6),
    );
    expect(unsure.intent, VoiceIntent.unknown);

    final vague = combine(
      rules(VoiceIntent.unknown),
      neural(taskConfidence: 0.4),
    );
    expect(vague.intent, VoiceIntent.unknown);
  });

  test('llena el título cuando las reglas solo entendieron la fecha', () {
    final result = combine(rules(VoiceIntent.createReminder), neural());

    expect(result.reminder.title, 'Xilofonear el informe');
  });

  test('no cambia el título de las reglas salvo en modo experimental', () {
    final base = rules(VoiceIntent.createReminder, title: 'Entregar informe');

    expect(combine(base, neural()).reminder.title, 'Entregar informe');
    expect(
      combine(base, neural(), prefer: true).reminder.title,
      'Xilofonear el informe',
    );
  });

  test('las consultas de agenda siguen siendo de las reglas', () {
    final base = rules(VoiceIntent.queryAgenda);

    expect(combine(base, neural()).intent, VoiceIntent.queryAgenda);
  });
}
