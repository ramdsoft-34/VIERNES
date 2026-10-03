import 'package:flutter/foundation.dart';
import 'package:viernes/ai/dataset/training_sample.dart';
import 'package:viernes/ai/nlu/es/spanish_rule_interpreter.dart';
import 'package:viernes/ai/nlu/es/spanish_text.dart';
import 'package:viernes/ai/nlu/ml/neural_tagger.dart';

/// Quién acierta más el título con las frases reales del usuario: las reglas
/// o la red neuronal. Sirve para decidir si activar «Títulos con la red».
@immutable
class NeuralComparison {
  const NeuralComparison({
    required this.samples,
    required this.rulesCorrect,
    required this.neuralCorrect,
  });

  factory NeuralComparison.compute(
    Iterable<TrainingSample> data,
    NeuralTagger tagger,
  ) {
    var samples = 0;
    var rules = 0;
    var neural = 0;
    for (final sample in data) {
      final expected = sample.finalResult['title'];
      if (expected is! String ||
          expected.isEmpty ||
          sample.utterances.isEmpty) {
        continue;
      }
      samples++;
      final byRules = sample.initialParse['title'];
      if (byRules is String && _same(byRules, expected)) rules++;
      final task = tagger.tag(sample.utterances.first).span('TAREA');
      if (task != null &&
          _same(SpanishRuleInterpreter.cleanTitle(task.text), expected)) {
        neural++;
      }
    }
    return NeuralComparison(
      samples: samples,
      rulesCorrect: rules,
      neuralCorrect: neural,
    );
  }

  /// Conversaciones con título final para comparar.
  final int samples;
  final int rulesCorrect;
  final int neuralCorrect;

  double get rulesAccuracy => samples == 0 ? 0 : rulesCorrect / samples;
  double get neuralAccuracy => samples == 0 ? 0 : neuralCorrect / samples;

  /// Hay datos suficientes para que la comparación diga algo.
  bool get meaningful => samples >= 10;

  static bool _same(String a, String b) =>
      SpanishText.fold(a).trim() == SpanishText.fold(b).trim();
}
