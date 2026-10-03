import 'package:flutter/foundation.dart';
import 'package:viernes/ai/dataset/training_sample.dart';

/// Qué tan bien entiende Viernes, medido con las conversaciones guardadas.
@immutable
class AccuracyReport {
  const AccuracyReport({
    required this.total,
    required this.firstTry,
    required this.titleCorrections,
    required this.categoryCorrections,
  });

  factory AccuracyReport.from(Iterable<TrainingSample> samples) {
    var total = 0;
    var firstTry = 0;
    var titles = 0;
    var categories = 0;
    for (final sample in samples) {
      total++;
      if (!sample.corrected) firstTry++;
      final initialTitle = sample.initialParse['title'];
      if (initialTitle is String &&
          initialTitle.isNotEmpty &&
          initialTitle != sample.finalResult['title']) {
        titles++;
      }
      if (sample.initialParse['category'] != sample.finalResult['category']) {
        categories++;
      }
    }
    return AccuracyReport(
      total: total,
      firstTry: firstTry,
      titleCorrections: titles,
      categoryCorrections: categories,
    );
  }

  /// Conversaciones guardadas.
  final int total;

  /// Entendidas sin preguntar ni corregir nada.
  final int firstTry;

  /// Veces que el título final no fue el que entendió.
  final int titleCorrections;

  /// Veces que la categoría final no fue la que propuso.
  final int categoryCorrections;

  /// Proporción entendida a la primera (0–1), o `null` sin datos.
  double? get firstTryRate => total == 0 ? null : firstTry / total;
}
