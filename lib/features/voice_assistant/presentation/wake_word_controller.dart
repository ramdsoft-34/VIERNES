import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viernes/ai/ai_providers.dart';
import 'package:viernes/ai/speech/speech_recognizer.dart';
import 'package:viernes/ai/wake_word/wake_model_manager.dart';
import 'package:viernes/ai/wake_word/wake_word_service.dart';
import 'package:viernes/app/router/app_router.dart';
import 'package:viernes/core/logging/app_logger.dart';
import 'package:viernes/features/settings/presentation/settings_controller.dart';
import 'package:viernes/features/voice_assistant/presentation/voice_assistant_sheet.dart';
import 'package:viernes/l10n/gen/app_localizations.dart';

final wakeWordServiceProvider = Provider<WakeWordService>(
  (ref) => AndroidWakeWordService(),
);

final wakeModelManagerProvider = Provider<WakeModelManager>(
  (ref) => VoskModelManager(),
);

enum WakeWordPhase { off, preparing, downloading, listening, error }

@immutable
class WakeWordState {
  const WakeWordState({
    this.phase = WakeWordPhase.off,
    this.progress = 0,
    this.modelInstalled = false,
    this.canOpenOverOtherApps = false,
    this.error,
  });

  final WakeWordPhase phase;

  /// Progreso de la descarga del modelo (0–1).
  final double progress;
  final bool modelInstalled;
  final bool canOpenOverOtherApps;
  final String? error;

  bool get isBusy =>
      phase == WakeWordPhase.preparing || phase == WakeWordPhase.downloading;

  WakeWordState copyWith({
    WakeWordPhase? phase,
    double? progress,
    bool? modelInstalled,
    bool? canOpenOverOtherApps,
    String? error,
    bool clearError = false,
  }) => WakeWordState(
    phase: phase ?? this.phase,
    progress: progress ?? this.progress,
    modelInstalled: modelInstalled ?? this.modelInstalled,
    canOpenOverOtherApps: canOpenOverOtherApps ?? this.canOpenOverOtherApps,
    error: clearError ? null : error ?? this.error,
  );
}

final NotifierProvider<WakeWordController, WakeWordState>
wakeWordControllerProvider =
    NotifierProvider<WakeWordController, WakeWordState>(
      WakeWordController.new,
    );

/// Activa, pausa y configura la escucha de "Viernes".
class WakeWordController extends Notifier<WakeWordState> {
  late WakeWordService _service;
  late WakeModelManager _models;
  final AppLocalizations _l10n = lookupAppLocalizations(const Locale('es'));

  bool get _enabled => ref.read(settingsControllerProvider).wakeWordEnabled;

  @override
  WakeWordState build() {
    _service = ref.read(wakeWordServiceProvider);
    _models = ref.read(wakeModelManagerProvider);
    unawaited(refresh());
    return const WakeWordState();
  }

  /// Lee el estado real del servicio y del modelo.
  Future<void> refresh() async {
    final bool installed;
    final bool running;
    final bool overlay;
    try {
      installed = await _models.installedPath() != null;
      running = await _service.isRunning();
      overlay = await _service.canOpenOverOtherApps();
    } on Object catch (error) {
      AppLogger.error('Estado de la activación por voz', error: error);
      return;
    }
    if (!ref.mounted || state.isBusy) return;
    state = state.copyWith(
      modelInstalled: installed,
      canOpenOverOtherApps: overlay,
      phase: running ? WakeWordPhase.listening : WakeWordPhase.off,
    );
  }

  Future<void> enable() async {
    if (state.isBusy) return;
    state = state.copyWith(phase: WakeWordPhase.preparing, clearError: true);

    // Pide el permiso de micrófono (si aún no lo tiene).
    final mic = await ref.read(speechRecognizerProvider).initialize();
    if (mic != SpeechAvailability.available) {
      _fail(_l10n.wakeErrorMic);
      return;
    }

    var path = await _models.installedPath();
    if (path == null) {
      state = state.copyWith(phase: WakeWordPhase.downloading, progress: 0);
      try {
        path = await _models.install(
          onProgress: (value) {
            if (ref.mounted) state = state.copyWith(progress: value);
          },
        );
      } on Object catch (error, stack) {
        AppLogger.error(
          'No se pudo descargar el modelo',
          error: error,
          stackTrace: stack,
        );
        _fail(_l10n.wakeErrorDownload);
        return;
      }
    }

    ref
        .read(settingsControllerProvider.notifier)
        .update((s) => s.copyWith(wakeWordEnabled: true));
    await _start(path);
    state = state.copyWith(
      phase: WakeWordPhase.listening,
      modelInstalled: true,
    );
  }

  Future<void> disable() async {
    ref
        .read(settingsControllerProvider.notifier)
        .update((s) => s.copyWith(wakeWordEnabled: false));
    await _service.stop();
    state = state.copyWith(phase: WakeWordPhase.off, clearError: true);
  }

  Future<void> setSensitivity(double value) async {
    ref
        .read(settingsControllerProvider.notifier)
        .update((s) => s.copyWith(wakeSensitivity: value));
    if (state.phase != WakeWordPhase.listening) return;
    final path = await _models.installedPath();
    // Volver a iniciar actualiza el umbral del servicio en marcha.
    if (path != null) await _start(path);
  }

  /// Al abrir la app: si estaba activada, que siga escuchando.
  Future<void> ensureRunning() async {
    if (!_enabled || state.isBusy || await _service.isRunning()) return;
    final path = await _models.installedPath();
    if (path == null) return;
    await _start(path);
    if (ref.mounted) state = state.copyWith(phase: WakeWordPhase.listening);
  }

  /// Suelta el micrófono mientras la app lo usa.
  Future<void> pause() async {
    if (_enabled) await _service.pause();
  }

  Future<void> resume() async {
    if (_enabled) await _service.resume();
  }

  Future<void> removeModel() async {
    await disable();
    await _models.remove();
    state = state.copyWith(modelInstalled: false);
  }

  Future<void> requestOpenOverOtherApps() =>
      _service.requestOpenOverOtherApps();

  Future<void> _start(String path) => _service.start(
    modelPath: path,
    threshold: ref.read(settingsControllerProvider).wakeThreshold,
  );

  void _fail(String message) {
    if (!ref.mounted) return;
    state = state.copyWith(phase: WakeWordPhase.error, error: message);
  }
}

final wakeCoordinatorProvider = Provider<WakeCoordinator>((ref) {
  final coordinator = WakeCoordinator(ref);
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// Abre la conversación cuando se dice "Viernes" y mantiene la escucha
/// encendida al volver a la app.
class WakeCoordinator with WidgetsBindingObserver {
  WakeCoordinator(this._ref);

  final Ref _ref;
  StreamSubscription<void>? _subscription;

  void start() {
    final service = _ref.read(wakeWordServiceProvider);
    _subscription = service.wakes.listen((_) => _openConversation());
    WidgetsBinding.instance.addObserver(this);
    unawaited(_onStart(service));
  }

  Future<void> _onStart(WakeWordService service) async {
    await _ref.read(wakeWordControllerProvider.notifier).ensureRunning();
    if (await service.consumeLaunchWake()) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openConversation(),
      );
    }
  }

  void _openConversation() {
    final context = rootNavigatorKey.currentContext;
    if (context == null || VoiceAssistantSheet.isOpen) return;
    unawaited(showVoiceAssistant(context, fromWake: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final controller = _ref.read(wakeWordControllerProvider.notifier);
    unawaited(controller.ensureRunning().then((_) => controller.refresh()));
  }

  void dispose() {
    unawaited(_subscription?.cancel());
    WidgetsBinding.instance.removeObserver(this);
  }
}
