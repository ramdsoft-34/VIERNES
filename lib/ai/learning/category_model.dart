import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:viernes/ai/learning/text_features.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';

/// Un ejemplo para aprender: título y la categoría que quedó.
@immutable
class CategoryExample {
  const CategoryExample(this.title, this.category, {this.weight = 1});

  final String title;
  final ReminderCategory category;

  /// Las elecciones del usuario pesan más que las automáticas.
  final double weight;
}

@immutable
class CategoryPrediction {
  const CategoryPrediction(this.category, this.confidence);

  final ReminderCategory category;

  /// Probabilidad estimada (0–1) de la categoría elegida.
  final double confidence;

  @override
  String toString() =>
      'CategoryPrediction(${category.name}, ${confidence.toStringAsFixed(2)})';
}

/// Clasificador Naive Bayes multinomial entrenado en el teléfono con los
/// recordatorios del usuario.
///
/// Es pequeño, rápido de reentrenar y explicable: aprende qué palabras usa
/// cada persona para cada categoría (p. ej. que "Sofi" es familia o que
/// "sprint" es trabajo), algo que las reglas fijas no pueden saber.
class CategoryModel {
  CategoryModel._({
    required this._classWeights,
    required this._tokenWeights,
    required this._tokenTotals,
    required this._vocabulary,
    required this.examples,
  });

  factory CategoryModel.train(Iterable<CategoryExample> data) {
    final classWeights = <ReminderCategory, double>{};
    final tokenWeights = <ReminderCategory, Map<String, double>>{};
    final tokenTotals = <ReminderCategory, double>{};
    final vocabulary = <String>{};
    var examples = 0;

    for (final example in data) {
      // "Otra" no enseña nada sobre las categorías.
      if (example.category == ReminderCategory.other) continue;
      final tokens = TextFeatures.tokens(example.title);
      if (tokens.isEmpty) continue;
      examples++;
      classWeights.update(
        example.category,
        (w) => w + example.weight,
        ifAbsent: () => example.weight,
      );
      final counts = tokenWeights.putIfAbsent(example.category, () => {});
      for (final token in tokens) {
        vocabulary.add(token);
        counts.update(
          token,
          (w) => w + example.weight,
          ifAbsent: () => example.weight,
        );
        tokenTotals.update(
          example.category,
          (w) => w + example.weight,
          ifAbsent: () => example.weight,
        );
      }
    }
    return CategoryModel._(
      classWeights: classWeights,
      tokenWeights: tokenWeights,
      tokenTotals: tokenTotals,
      vocabulary: vocabulary,
      examples: examples,
    );
  }

  /// Ejemplos mínimos para empezar a opinar.
  static const minExamples = 5;

  final Map<ReminderCategory, double> _classWeights;
  final Map<ReminderCategory, Map<String, double>> _tokenWeights;
  final Map<ReminderCategory, double> _tokenTotals;
  final Set<String> _vocabulary;

  /// Ejemplos con los que se entrenó.
  final int examples;

  bool get isReady => examples >= minExamples && _classWeights.length >= 2;

  /// Categoría más probable, o `null` si no hay base suficiente o ninguna
  /// palabra del título es conocida.
  CategoryPrediction? predict(String title) {
    if (!isReady) return null;
    final tokens = TextFeatures.tokens(
      title,
    ).where(_vocabulary.contains).toList();
    if (tokens.isEmpty) return null;

    final totalWeight = _classWeights.values.fold<double>(0, (a, b) => a + b);
    final vocabularySize = _vocabulary.length;
    final logScores = <ReminderCategory, double>{};
    for (final MapEntry(key: category, value: weight)
        in _classWeights.entries) {
      var score = math.log(weight / totalWeight);
      final counts = _tokenWeights[category]!;
      final total = _tokenTotals[category]!;
      for (final token in tokens) {
        // Suavizado de Laplace: una palabra nunca vista no anula la clase.
        score += math.log(
          ((counts[token] ?? 0) + 1) / (total + vocabularySize),
        );
      }
      logScores[category] = score;
    }

    // Softmax estable para convertir puntajes en probabilidades.
    final best = logScores.values.reduce(math.max);
    final exp = {
      for (final entry in logScores.entries)
        entry.key: math.exp(entry.value - best),
    };
    final sum = exp.values.fold<double>(0, (a, b) => a + b);
    final top = exp.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return CategoryPrediction(top.key, top.value / sum);
  }

  /// Precisión estimada con validación cruzada de [folds] particiones:
  /// se entrena sin una parte de los datos y se mide en esa parte. Devuelve
  /// `null` si no hay datos suficientes para medir.
  static double? crossValidatedAccuracy(
    List<CategoryExample> data, {
    int folds = 5,
  }) {
    final usable = data
        .where((e) => e.category != ReminderCategory.other)
        .toList();
    if (usable.length < minExamples * 2) return null;
    var correct = 0;
    var tested = 0;
    for (var fold = 0; fold < folds; fold++) {
      final train = <CategoryExample>[];
      final test = <CategoryExample>[];
      for (var i = 0; i < usable.length; i++) {
        (i % folds == fold ? test : train).add(usable[i]);
      }
      final model = CategoryModel.train(train);
      for (final example in test) {
        final prediction = model.predict(example.title);
        if (prediction == null) continue;
        tested++;
        if (prediction.category == example.category) correct++;
      }
    }
    return tested == 0 ? null : correct / tested;
  }
}
