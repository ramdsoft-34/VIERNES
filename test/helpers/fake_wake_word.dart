import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:viernes/ai/wake_word/voice_profile_service.dart';
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

  final _actions = StreamController<String>.broadcast();
  String? launchAction;
  WakeStats? fakeStats;

  void simulateAction(String action) => _actions.add(action);

  @override
  Stream<String> get actions => _actions.stream;

  @override
  Future<String?> consumeLaunchAction() async {
    final value = launchAction;
    launchAction = null;
    return value;
  }

  @override
  Future<WakeStats?> stats() async => fakeStats;

  @override
  Future<void> resetStats() async => calls.add('resetStats');

  bool? lastLowBatteryPause;

  bool? lastChime;
  bool? lastSaveSamples;

  @override
  Future<void> start({
    required String modelPath,
    required double threshold,
    bool chime = true,
    bool saveSamples = false,
    bool lowBatteryPause = true,
  }) async {
    lastLowBatteryPause = lowBatteryPause;
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

/// Voz registrada falsa: por defecto ya hay una voz.
class FakeVoiceProfileService implements VoiceProfileService {
  FakeVoiceProfileService({this.enrolled = true});

  bool enrolled;
  int recorded = 0;
  VoiceStrictness strictness = VoiceStrictness.normal;

  /// Próximas respuestas de [recordSample] (ok o el problema).
  final List<SampleProblem> nextProblems = [];

  @override
  Future<VoiceProfileStatus> status() async => VoiceProfileStatus(
    enrolled: enrolled,
    samples: enrolled ? VoiceProfileService.samplesNeeded : 0,
    strictness: strictness,
  );

  @override
  Future<void> startEnrollment() async => recorded = 0;

  @override
  Future<VoiceSample> recordSample() async {
    final problem = nextProblems.isEmpty
        ? SampleProblem.none
        : nextProblems.removeAt(0);
    if (problem != SampleProblem.none) {
      return VoiceSample(ok: false, problem: problem, count: recorded);
    }
    recorded++;
    return VoiceSample(ok: true, count: recorded);
  }

  @override
  Future<bool> finishEnrollment() async {
    if (recorded < VoiceProfileService.samplesNeeded) return false;
    enrolled = true;
    return true;
  }

  @override
  Future<VoiceSample> testSample() async =>
      const VoiceSample(ok: true, accepted: true, similarity: 0.9);

  @override
  Future<void> setStrictness(VoiceStrictness value) async => strictness = value;

  @override
  Future<void> delete() async => enrolled = false;
}
