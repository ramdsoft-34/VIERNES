import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:viernes/ai/dataset/training_data_repository.dart';
import 'package:viernes/ai/dataset/training_sample.dart';
import 'package:viernes/ai/speech/speech_recognizer.dart';

/// Reconocedor guionado: cada `listen` entrega la siguiente respuesta. Si
/// no quedan, se queda escuchando hasta que lo cancelen.
class FakeSpeechRecognizer implements SpeechRecognizer {
  FakeSpeechRecognizer({
    List<SpeechResult> script = const [],
    this.availability = SpeechAvailability.available,
  }) : _script = Queue.of(script);

  final Queue<SpeechResult> _script;
  final SpeechAvailability availability;
  Completer<SpeechResult>? _waiting;
  int listenCount = 0;

  void say(String text) => _script.add(SpeechHeard(text));

  @override
  Future<SpeechAvailability> initialize() async => availability;

  @override
  Future<SpeechResult> listen({
    ValueChanged<String>? onPartial,
    Duration silence = const Duration(seconds: 3),
    Duration maxDuration = const Duration(seconds: 20),
  }) {
    listenCount++;
    if (_script.isNotEmpty) {
      final next = _script.removeFirst();
      if (next is SpeechHeard) onPartial?.call(next.text);
      return Future.value(next);
    }
    return (_waiting = Completer<SpeechResult>()).future;
  }

  @override
  Future<void> cancel() async {
    final waiting = _waiting;
    _waiting = null;
    if (waiting != null && !waiting.isCompleted) {
      waiting.complete(const SpeechCancelled());
    }
  }
}

class FakeSpeaker implements Speaker {
  final List<String> spoken = [];

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async {}
}

class FakeTrainingDataRepository implements TrainingDataRepository {
  final List<TrainingSample> samples = [];

  @override
  Future<void> add(TrainingSample sample) async => samples.add(sample);

  @override
  Future<List<TrainingSample>> all() async => samples;

  @override
  Future<void> clear() async => samples.clear();

  @override
  Stream<int> watchCount() => Stream.value(samples.length);
}
