import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viernes/ai/dataset/training_data_repository.dart';
import 'package:viernes/ai/dataset/training_sample.dart';
import 'package:viernes/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  late DriftTrainingDataRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftTrainingDataRepository(db);
  });

  tearDown(() => db.close());

  TrainingSample sample(String text) => TrainingSample(
    utterances: [text],
    initialParse: const {'title': 'Correr', 'time': '8:0'},
    finalResult: const {'title': 'Correr', 'dueAt': '2026-10-02T09:00:00.000'},
    corrected: true,
    confidence: 0.85,
    interpreterVersion: 'rules-es-1.0',
    createdAt: DateTime(2026, 10, 1, 10),
  );

  test('guarda, cuenta, lee y borra los ejemplos', () async {
    await repository.add(sample('mañana a las 8 correr'));
    await repository.add(sample('el lunes pagar'));

    expect(await repository.watchCount().first, 2);
    final all = await repository.all();
    expect(all.first.utterances, ['mañana a las 8 correr']);
    expect(all.first.initialParse['time'], '8:0');
    expect(all.first.corrected, isTrue);
    expect(all.first.toJson()['interpreter'], 'rules-es-1.0');

    await repository.clear();
    expect(await repository.watchCount().first, 0);
  });
}
