import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:viernes/ai/nlu/ml/neural_tagger.dart';
import 'package:viernes/ai/nlu/ml/nlu_tokenizer.dart';

/// Verifica que la red en Dart calcule lo mismo que en el entrenamiento
/// (Keras). Los casos los exporta `training/nlu/train_nlu.py`.
void main() {
  final model = File('assets/ai/nlu_model.json');
  final parity = File('test/fixtures/nlu_parity.json');

  test('el tokenizador conserva posiciones y normaliza como Python', () {
    final tokens = NluTokenizer.tokenize(
      'Recuérdame, a las 8:30 ¡llamar a Ñoño!',
    );
    expect(tokens.map((t) => t.text), [
      'recuerdame',
      'a',
      'las',
      '8',
      '30',
      'llamar',
      'a',
      'nono',
    ]);
    expect(NluTokenizer.normalize('8'), NluTokenizer.num);
    // FNV-1a de 32 bits (vectores de prueba oficiales), igual que Python.
    expect(NluTokenizer.fnv1a(''), 0x811C9DC5);
    expect(NluTokenizer.fnv1a('a'), 0xE40C292C);
    expect(NluTokenizer.fnv1a('foobar'), 0xBF9CF968);
  });

  test(
    'da las mismas probabilidades que Keras',
    () {
      final tagger = NeuralTagger.fromJsonString(model.readAsStringSync());
      final cases = (jsonDecode(parity.readAsStringSync()) as List)
          .cast<Map<String, Object?>>();
      expect(cases, isNotEmpty);
      for (final c in cases) {
        final text = c['text']! as String;
        final tokens = NluTokenizer.tokenize(text);
        final ids = [for (final t in tokens) tagger.tokenId(t.text)];
        expect(ids, (c['ids']! as List).cast<int>(), reason: text);
        final sfx = [for (final t in tokens) tagger.suffixId(t.text)];
        expect(sfx, (c['sfx']! as List).cast<int>(), reason: text);

        final probs = tagger.predictIds(ids, sfx);
        final expected = (c['intent']! as List).cast<num>();
        for (var i = 0; i < expected.length; i++) {
          expect(probs.intent[i], closeTo(expected[i], 1e-3), reason: text);
        }
        final tags = (c['tags']! as List).cast<String>();
        final result = tagger.tag(text);
        expect(result.intentConfidence, closeTo(expected.reduce(_max), 1e-3));
        expect(tags.length, ids.length, reason: text);
      }
    },
    skip: model.existsSync() && parity.existsSync()
        ? false
        : 'Falta el modelo entrenado (assets/ai/nlu_model.json)',
  );

  test(
    'entiende una frase completa',
    () {
      final tagger = NeuralTagger.fromJsonString(model.readAsStringSync());
      final result = tagger.tag('Recuérdame mañana a las 8 llamar a Juan');

      expect(result.intent, 'crear');
      expect(result.span('TAREA')?.text, 'llamar a Juan');
      expect(result.span('FECHA')?.text, 'mañana');
      expect(result.span('HORA')?.text, 'a las 8');
    },
    skip: model.existsSync() ? false : 'Falta el modelo entrenado',
  );
}

num _max(num a, num b) => a > b ? a : b;
