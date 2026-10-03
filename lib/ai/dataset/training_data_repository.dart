import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:viernes/ai/dataset/training_sample.dart';
import 'package:viernes/core/database/app_database.dart';

abstract interface class TrainingDataRepository {
  Future<void> add(TrainingSample sample);

  Stream<int> watchCount();

  Future<List<TrainingSample>> all();

  /// Borra todos los ejemplos (derecho del usuario a eliminar sus datos).
  Future<void> clear();
}

class DriftTrainingDataRepository implements TrainingDataRepository {
  DriftTrainingDataRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> add(TrainingSample sample) => _db
      .into(_db.nluSamples)
      .insert(
        NluSamplesCompanion.insert(
          utterances: jsonEncode(sample.utterances),
          initialParse: jsonEncode(sample.initialParse),
          finalResult: jsonEncode(sample.finalResult),
          corrected: sample.corrected,
          confidence: sample.confidence,
          interpreterVersion: sample.interpreterVersion,
          createdAt: sample.createdAt,
        ),
      );

  @override
  Stream<int> watchCount() {
    final count = _db.nluSamples.id.count();
    return (_db.selectOnly(
      _db.nluSamples,
    )..addColumns([count])).watchSingle().map((row) => row.read(count) ?? 0);
  }

  @override
  Future<List<TrainingSample>> all() async {
    final rows = await (_db.select(
      _db.nluSamples,
    )..orderBy([(s) => OrderingTerm.asc(s.id)])).get();
    return [
      for (final row in rows)
        TrainingSample(
          id: row.id,
          utterances: (jsonDecode(row.utterances) as List<dynamic>)
              .cast<String>(),
          initialParse: (jsonDecode(row.initialParse) as Map<String, dynamic>)
              .cast<String, Object?>(),
          finalResult: (jsonDecode(row.finalResult) as Map<String, dynamic>)
              .cast<String, Object?>(),
          corrected: row.corrected,
          confidence: row.confidence,
          interpreterVersion: row.interpreterVersion,
          createdAt: row.createdAt,
        ),
    ];
  }

  @override
  Future<void> clear() => _db.delete(_db.nluSamples).go();
}
