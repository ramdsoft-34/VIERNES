import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:viernes/ai/nlu/ml/nlu_tokenizer.dart';

/// Fragmento de la frase con una etiqueta ("TAREA", "FECHA", "HORA"…).
@immutable
class TaggedSpan {
  const TaggedSpan({
    required this.label,
    required this.start,
    required this.end,
    required this.text,
    required this.confidence,
  });

  final String label;

  /// Posiciones en el texto original (conserva mayúsculas y tildes).
  final int start;
  final int end;
  final String text;

  /// Promedio de la confianza de sus palabras.
  final double confidence;
}

/// Lo que entendió la red sobre una frase.
@immutable
class TaggerResult {
  const TaggerResult({
    required this.intent,
    required this.intentConfidence,
    required this.spans,
  });

  /// `crear`, `consultar`, `cancelar` u `otro`.
  final String intent;
  final double intentConfidence;
  final List<TaggedSpan> spans;

  TaggedSpan? span(String label) {
    for (final s in spans) {
      if (s.label == label) return s;
    }
    return null;
  }
}

/// Intérprete neuronal propio: etiqueta cada palabra (BIO) y clasifica la
/// intención. Corre en Dart puro, sin bibliotecas nativas.
///
/// Arquitectura (ver `training/nlu/train_nlu.py`):
/// embedding → conv1d(k=3) → conv1d(k=3) → por palabra: softmax(etiquetas);
/// máximo global → softmax(intención).
class NeuralTagger {
  NeuralTagger._({
    required this.version,
    required this.metrics,
    required this._maxLen,
    required this._oovBuckets,
    required this._suffixBuckets,
    required this._vocab,
    required this._tags,
    required this._intents,
    required Map<String, _Tensor> tensors,
  }) : _t = tensors;

  /// Carga el modelo exportado (`assets/ai/nlu_model.json`).
  factory NeuralTagger.fromJson(Map<String, Object?> json) {
    final vocab = (json['vocab']! as List).cast<String>();
    final tensors = <String, _Tensor>{};
    for (final MapEntry(:key, :value)
        in (json['tensors']! as Map<String, Object?>).entries) {
      final map = value! as Map<String, Object?>;
      final bytes = base64.decode(map['data']! as String);
      tensors[key] = _Tensor(
        (map['shape']! as List).cast<int>(),
        bytes.buffer.asFloat32List(bytes.offsetInBytes, bytes.length ~/ 4),
      );
    }
    return NeuralTagger._(
      version: json['version']! as String,
      metrics: (json['metrics'] as Map<String, Object?>?) ?? const {},
      maxLen: json['maxLen']! as int,
      oovBuckets: json['oovBuckets']! as int,
      suffixBuckets: json['suffixBuckets']! as int,
      vocab: {for (final (i, w) in vocab.indexed) w: i},
      tags: (json['tags']! as List).cast<String>(),
      intents: (json['intents']! as List).cast<String>(),
      tensors: tensors,
    );
  }

  factory NeuralTagger.fromJsonString(String source) =>
      NeuralTagger.fromJson(jsonDecode(source) as Map<String, Object?>);

  final String version;
  final Map<String, Object?> metrics;
  final int _maxLen;
  final int _oovBuckets;
  final int _suffixBuckets;
  final Map<String, int> _vocab;
  final List<String> _tags;
  final List<String> _intents;
  final Map<String, _Tensor> _t;

  /// Identificador de cada palabra (vocabulario o cubeta por hash).
  int tokenId(String token) {
    final normalized = NluTokenizer.normalize(token);
    return _vocab[normalized] ??
        _vocab.length + NluTokenizer.fnv1a(normalized) % _oovBuckets;
  }

  /// Terminación de la palabra (-ar, -cion…), que ayuda con palabras nuevas.
  int suffixId(String token) {
    final normalized = NluTokenizer.normalize(token);
    final start = normalized.length > 3 ? normalized.length - 3 : 0;
    return NluTokenizer.fnv1a('~${normalized.substring(start)}') %
        _suffixBuckets;
  }

  /// Probabilidades crudas, para verificar contra el entrenamiento.
  ({List<double> intent, List<List<double>> tags}) predictIds(
    List<int> ids,
    List<int> suffixes,
  ) {
    final emb = _t['embedding']!;
    final sfx = _t['suffix']!;
    final dim = emb.shape[1];
    final sdim = sfx.shape[1];
    final x = [
      for (var i = 0; i < ids.length; i++)
        Float32List(dim + sdim)
          ..setRange(0, dim, emb.data, ids[i] * dim)
          ..setRange(dim, dim + sdim, sfx.data, suffixes[i] * sdim),
    ];
    final h1 = _conv(x, _t['conv1.kernel']!, _t['conv1.bias']!);
    final h2 = _conv(h1, _t['conv2.kernel']!, _t['conv2.bias']!);
    final tags = [
      for (final h in h2)
        _softmax(_dense(h, _t['tags.kernel']!, _t['tags.bias']!)),
    ];
    final hidden = h2.isEmpty ? 0 : h2.first.length;
    final pooled = Float32List(hidden);
    for (var j = 0; j < hidden; j++) {
      var best = double.negativeInfinity;
      for (final h in h2) {
        if (h[j] > best) best = h[j];
      }
      pooled[j] = best;
    }
    final intent = _softmax(
      _dense(pooled, _t['intent.kernel']!, _t['intent.bias']!),
    );
    return (intent: intent, tags: tags);
  }

  TaggerResult tag(String text) {
    final tokens = NluTokenizer.tokenize(text).take(_maxLen).toList();
    if (tokens.isEmpty) {
      return const TaggerResult(intent: 'otro', intentConfidence: 1, spans: []);
    }
    final probs = predictIds(
      [for (final t in tokens) tokenId(t.text)],
      [for (final t in tokens) suffixId(t.text)],
    );
    var best = 0;
    for (var i = 1; i < probs.intent.length; i++) {
      if (probs.intent[i] > probs.intent[best]) best = i;
    }

    final spans = <TaggedSpan>[];
    String? label;
    var start = 0;
    var sum = 0.0;
    var count = 0;
    void close(int lastToken) {
      if (label == null) return;
      final s = tokens[start].start;
      final e = tokens[lastToken].end;
      spans.add(
        TaggedSpan(
          label: label!,
          start: s,
          end: e,
          text: text.substring(s, e),
          confidence: sum / count,
        ),
      );
      label = null;
    }

    for (var i = 0; i < tokens.length; i++) {
      final p = probs.tags[i];
      var k = 0;
      for (var c = 1; c < p.length; c++) {
        if (p[c] > p[k]) k = c;
      }
      final tag = _tags[k];
      final current = tag == 'O' ? null : tag.substring(2);
      final continues =
          tag.startsWith('I-') && label != null && current == label;
      if (!continues) {
        close(i - 1);
        if (current != null) {
          label = current;
          start = i;
          sum = 0;
          count = 0;
        }
      }
      if (current != null) {
        sum += p[k];
        count++;
      }
    }
    close(tokens.length - 1);

    return TaggerResult(
      intent: _intents[best],
      intentConfidence: probs.intent[best],
      spans: spans,
    );
  }

  /// Conv1D con relleno "same", k=3, y ReLU. Kernel de Keras: [k, in, out].
  static List<Float32List> _conv(
    List<Float32List> x,
    _Tensor kernel,
    _Tensor bias,
  ) {
    final k = kernel.shape[0];
    final inDim = kernel.shape[1];
    final outDim = kernel.shape[2];
    final pad = k ~/ 2;
    final w = kernel.data;
    return [
      for (var t = 0; t < x.length; t++)
        () {
          final y = Float32List.fromList(bias.data);
          for (var j = 0; j < k; j++) {
            final src = t + j - pad;
            if (src < 0 || src >= x.length) continue;
            final row = x[src];
            for (var i = 0; i < inDim; i++) {
              final v = row[i];
              if (v == 0) continue;
              final base = (j * inDim + i) * outDim;
              for (var o = 0; o < outDim; o++) {
                y[o] += v * w[base + o];
              }
            }
          }
          for (var o = 0; o < outDim; o++) {
            if (y[o] < 0) y[o] = 0;
          }
          return y;
        }(),
    ];
  }

  static Float32List _dense(Float32List x, _Tensor kernel, _Tensor bias) {
    final outDim = kernel.shape[1];
    final y = Float32List.fromList(bias.data);
    for (var i = 0; i < x.length; i++) {
      final v = x[i];
      if (v == 0) continue;
      final base = i * outDim;
      for (var o = 0; o < outDim; o++) {
        y[o] += v * kernel.data[base + o];
      }
    }
    return y;
  }

  static List<double> _softmax(Float32List logits) {
    var maxValue = double.negativeInfinity;
    for (final v in logits) {
      if (v > maxValue) maxValue = v;
    }
    final exps = [for (final v in logits) math.exp(v - maxValue)];
    final total = exps.fold<double>(0, (a, b) => a + b);
    return [for (final e in exps) e / total];
  }
}

class _Tensor {
  const _Tensor(this.shape, this.data);

  final List<int> shape;
  final Float32List data;
}
