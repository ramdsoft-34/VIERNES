import 'package:flutter/foundation.dart';

/// Un ejemplo de entrenamiento: lo que dijo el usuario, lo que entendió
/// Viernes y lo que finalmente se guardó.
///
/// Las diferencias entre [initialParse] y [finalResult] son justamente lo que
/// el modelo propio debe aprender (Fase 6).
@immutable
class TrainingSample {
  const TrainingSample({
    required this.utterances,
    required this.initialParse,
    required this.finalResult,
    required this.corrected,
    required this.confidence,
    required this.interpreterVersion,
    required this.createdAt,
    this.id,
  });

  final int? id;
  final List<String> utterances;
  final Map<String, Object?> initialParse;
  final Map<String, Object?> finalResult;

  /// `true` si el usuario tuvo que corregir o completar algo.
  final bool corrected;
  final double confidence;
  final String interpreterVersion;
  final DateTime createdAt;

  /// Una línea JSONL para exportar el dataset.
  Map<String, Object?> toJson() => {
    'utterances': utterances,
    'initial': initialParse,
    'final': finalResult,
    'corrected': corrected,
    'confidence': confidence,
    'interpreter': interpreterVersion,
    'createdAt': createdAt.toIso8601String(),
  };
}
