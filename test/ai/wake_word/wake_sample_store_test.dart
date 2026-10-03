import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:viernes/ai/wake_word/wake_sample_store.dart';

void main() {
  late Directory base;
  late WakeSampleStore store;
  final now = DateTime(2026, 10, 3, 10);

  setUp(() {
    base = Directory.systemTemp.createTempSync('wake_samples');
    store = WakeSampleStore(baseDir: () async => base);
  });

  tearDown(() => base.deleteSync(recursive: true));

  File pending(DateTime at, {int score = 80}) {
    final dir = Directory(p.join(base.path, WakeSampleStore.folder))
      ..createSync(recursive: true);
    return File(
      p.join(dir.path, 'pending_${at.millisecondsSinceEpoch}_$score.wav'),
    )..writeAsBytesSync([0, 1, 2]);
  }

  test('etiqueta la activación reciente como real o error', () async {
    pending(now.subtract(const Duration(seconds: 30)));
    await store.labelLatest(real: true, now: now);
    pending(now.subtract(const Duration(seconds: 5)));
    await store.labelLatest(real: false, now: now);

    final counts = await store.counts();
    expect(counts.real, 1);
    expect(counts.errors, 1);
  });

  test('descarta las pendientes viejas sin etiquetar', () async {
    final old = pending(now.subtract(const Duration(hours: 2)));

    await store.labelLatest(real: true, now: now);

    expect(old.existsSync(), isFalse);
    expect((await store.counts()).total, 0);
  });

  test('borrar elimina todo', () async {
    pending(now);
    await store.labelLatest(real: true, now: now);

    await store.clear();

    expect((await store.counts()).total, 0);
  });
}
