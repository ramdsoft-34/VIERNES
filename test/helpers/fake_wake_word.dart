import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:viernes/ai/wake_word/wake_model_manager.dart';
import 'package:viernes/ai/wake_word/wake_word_service.dart';

class FakeWakeWordService implements WakeWordService {
  final List<String> calls = [];
  bool running = false;
  bool launchWake = false;
  bool ownModel = false;
  double? lastThreshold;
  String? lastModelPath;
  final _wakes = StreamController<void>.broadcast();

  void simulateWake() => _wakes.add(null);

  @override
  Stream<void> get wakes => _wakes.stream;

  bool? lastChime;
  bool? lastSaveSamples;

  @override
  Future<void> start({
    required String modelPath,
    required double threshold,
    bool chime = true,
    bool saveSamples = false,
  }) async {
    lastChime = chime;
    lastSaveSamples = saveSamples;
    calls.add('start');
    lastThreshold = threshold;
    lastModelPath = modelPath;
    running = true;
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    running = false;
  }

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> resume() async => calls.add('resume');

  @override
  Future<bool> isRunning() async => running;

  @override
  Future<bool> hasOwnModel() async => ownModel;

  @override
  Future<bool> consumeLaunchWake() async {
    final value = launchWake;
    launchWake = false;
    return value;
  }

  @override
  Future<bool> canOpenOverOtherApps() async => false;

  @override
  Future<void> requestOpenOverOtherApps() async => calls.add('requestOverlay');
}

class FakeWakeModelManager implements WakeModelManager {
  FakeWakeModelManager({this.installed = false, this.failDownload = false});

  bool installed;
  bool failDownload;
  final List<double> progress = [];

  @override
  Future<String?> installedPath() async => installed ? '/modelo' : null;

  @override
  Future<String> install({ValueChanged<double>? onProgress}) async {
    if (failDownload) throw Exception('sin conexión');
    for (final value in [0.25, 0.5, 1.0]) {
      progress.add(value);
      onProgress?.call(value);
    }
    installed = true;
    return '/modelo';
  }

  @override
  Future<void> remove() async => installed = false;
}
