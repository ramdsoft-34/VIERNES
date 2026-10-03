import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viernes/ai/ai_providers.dart';
import 'package:viernes/ai/speech/speech_recognizer.dart';
import 'package:viernes/ai/wake_word/voice_profile_service.dart';
import 'package:viernes/ai/wake_word/wake_model_manager.dart';
import 'package:viernes/ai/wake_word/wake_sample_store.dart';
import 'package:viernes/ai/wake_word/wake_word_service.dart';
import 'package:viernes/app/router/app_router.dart';
import 'package:viernes/app/router/routes.dart';
import 'package:viernes/core/logging/app_logger.dart';
import 'package:viernes/features/alerts/presentation/alert_providers.dart';
import 'package:viernes/features/settings/domain/app_settings.dart';
import 'package:viernes/features/settings/presentation/settings_controller.dart';
import 'package:viernes/features/voice_assistant/presentation/voice_assistant_sheet.dart';
import 'package:viernes/l10n/gen/app_localizations.dart';

final wakeWordServiceProvider = Provider<WakeWordService>(
  (ref) => AndroidWakeWordService(),
);

/// Voz registrada del dueño. En pruebas se sobrescribe con una falsa.
final voiceProfileServiceProvider = Provider<VoiceProfileService>(
  (ref) => AndroidVoiceProfileService(),
);

/// Estado de la voz registrada (se refresca al invalidarlo).
final FutureProvider<VoiceProfileStatus> voiceProfileStatusProvider =
    FutureProvider.autoDispose<VoiceProfileStatus>(
      (ref) => ref.watch(voiceProfileServiceProvider).status(),
    );

/// Modelo de Vosk (respaldo). En pruebas se sobrescribe con uno falso.
final voskModelManagerProvider = Provider<WakeModelManager>(
  (ref) => VoskModelManager(),
);

/// Modelo del detector elegido en Ajustes: el propio (incluido en la app) o
/// Vosk. Si la app no trae el propio, se usa Vosk.
final wakeModelManagerProvider = Provider<WakeModelManager>((ref) {
  final vosk = ref.watch(voskModelManagerProvider);
  final engine = ref.watch(
    settingsControllerProvider.select((s) => s.wakeEngine),
  );
  if (engine == WakeEngine.vosk) return vosk;
  final service = ref.watch(wakeWordServiceProvider);
  return BundledWakeModelManager(
    available: service.hasOwnModel,
    fallback: vosk,
  );
});

enum WakeWordPhase { off, preparing, downloading, listening, error }

@immutable
class WakeWordState {
  const WakeWordState({
    this.phase = WakeWordPhase.off,
    this.progress = 0,
    this.modelInstalled = false,
    this.ownModel = false,
    this.canOpenOverOtherApps = false,
    this.needsVoice = false,
    this.error,
  });

  final WakeWordPhase phase;

  /// Progreso de la descarga del modelo (0–1).
  final double progress;
  final bool modelInstalled;

  /// Usa el detector propio incluido en la app (no hay nada que borrar).
  final bool ownModel;
  final bool canOpenOverOtherApps;

  /// Se intentó activar sin una voz registrada.
  final bool needsVoice;
  final String? error;

  bool get isBusy =>
      phase == WakeWordPhase.preparing || phase == WakeWordPhase.downloading;

  WakeWordState copyWith({
    WakeWordPhase? phase,
    double? progress,
    bool? modelInstalled,
    bool? ownModel,
    bool? canOpenOverOtherApps,
    bool? needsVoice,
    String? error,
    bool clearError = false,
  }) => WakeWordState(
    phase: phase ?? this.phase,
    progress: progress ?? this.progress,
    modelInstalled: modelInstalled ?? this.modelInstalled,
    ownModel: ownModel ?? this.ownModel,
    canOpenOverOtherApps: canOpenOverOtherApps ?? this.canOpenOverOtherApps,
    needsVoice: !clearError && (needsVoice ?? this.needsVoice),
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

  /// Se lee cada vez: cambia si el usuario elige otro detector.
  WakeModelManager get _models => ref.read(wakeModelManagerProvider);
  final AppLocalizations _l10n = lookupAppLocalizations(const Locale('es'));

  bool get _enabled => ref.read(settingsControllerProvider).wakeWordEnabled;

  /// La activación solo funciona con la voz del dueño registrada.
  Future<bool> _hasVoice() async {
    try {
      return (await ref.read(voiceProfileServiceProvider).status()).enrolled;
    } on Object catch (error) {
      AppLogger.error('Estado de la voz registrada', error: error);
      return false;
    }
  }

  @override
  WakeWordState build() {
    _service = ref.read(wakeWordServiceProvider);
    unawaited(refresh());
    return const WakeWordState();
  }

  /// Lee el estado real del servicio y del modelo.
  Future<void> refresh() async {
    final String? path;
    final bool running;
    final bool overlay;
    try {
      path = await _models.installedPath();
      running = await _service.isRunning();
      overlay = await _service.canOpenOverOtherApps();
    } on Object catch (error) {
      AppLogger.error('Estado de la activación por voz', error: error);
      return;
    }
    if (!ref.mounted || state.isBusy) return;
    state = state.copyWith(
      modelInstalled: path != null,
      ownModel: path == BundledWakeModelManager.assetPath,
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

    if (!await _hasVoice()) {
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: WakeWordPhase.off,
        needsVoice: true,
        error: _l10n.wakeNeedsVoice,
      );
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
      ownModel: path == BundledWakeModelManager.assetPath,
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
    if (!_enabled || state.isBusy) return;
    if (!await _hasVoice()) {
      // Se borró la voz (o es una instalación anterior al registro): sin
      // voz no se escucha a nadie.
      if (await _service.isRunning()) await _service.stop();
      if (ref.mounted) {
        state = state.copyWith(phase: WakeWordPhase.off, needsVoice: true);
      }
      return;
    }
    if (await _service.isRunning()) return;
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

  /// Al terminar de registrar (o borrar) la voz: si la activación estaba
  /// pedida, arranca o se detiene según corresponda.
  Future<void> voiceChanged() async {
    ref.invalidate(voiceProfileStatusProvider);
    if (!ref.mounted) return;
    state = state.copyWith(clearError: true);
    if (_enabled) {
      await ensureRunning();
      await resume();
    }
    await refresh();
  }

  /// Borra la voz registrada; la activación por voz deja de funcionar.
  Future<void> deleteVoice() async {
    await ref.read(voiceProfileServiceProvider).delete();
    await disable();
    ref.invalidate(voiceProfileStatusProvider);
  }

  Future<void> removeModel() async {
    await disable();
    await _models.remove();
    state = state.copyWith(modelInstalled: false);
  }

  Future<void> requestOpenOverOtherApps() =>
      _service.requestOpenOverOtherApps();

  /// Cambia de detector. Si estaba escuchando, sigue con el nuevo (Vosk se
  /// descarga si hace falta).
  Future<void> setEngine(WakeEngine engine) async {
    if (state.isBusy) return;
    ref
        .read(settingsControllerProvider.notifier)
        .update((s) => s.copyWith(wakeEngine: engine));
    if (_enabled) {
      await enable();
    } else {
      await refresh();
    }
  }

  Future<void> _start(String path) {
    final settings = ref.read(settingsControllerProvider);
    final own = path == BundledWakeModelManager.assetPath;
    return _service.start(
      modelPath: path,
      threshold: own ? settings.ownWakeThreshold : settings.wakeThreshold,
      chime: settings.wakeChime,
      saveSamples: settings.dataCollectionConsent,
      lowBatteryPause: settings.lowBatteryPause,
    );
  }

  /// Aplica al servicio en marcha un cambio de ajustes (sonido o
  /// consentimiento).
  Future<void> applySettings() async {
    if (state.phase != WakeWordPhase.listening) return;
    final path = await _models.installedPath();
    if (path != null) await _start(path);
  }

  void _fail(String message) {
    if (!ref.mounted) return;
    state = state.copyWith(phase: WakeWordPhase.error, error: message);
  }
}

/// Grabaciones de cada activación, para reentrenar el detector.
final wakeSampleStoreProvider = Provider<WakeSampleStore>(
  (ref) => WakeSampleStore(),
);

/// Cuántas grabaciones de activación hay (se refresca al invalidarlo).
final FutureProvider<WakeSampleCounts> wakeSampleCountsProvider =
    FutureProvider.autoDispose<WakeSampleCounts>(
      (ref) => ref.watch(wakeSampleStoreProvider).counts(),
    );

final wakeCoordinatorProvider = Provider<WakeCoordinator>((ref) {
  final coordinator = WakeCoordinator(ref);
  ref
    ..listen<AppSettings>(settingsControllerProvider, (previous, next) {
      if (previous == null) return;
      if (previous.wakeChime != next.wakeChime ||
          previous.dataCollectionConsent != next.dataCollectionConsent ||
          previous.lowBatteryPause != next.lowBatteryPause) {
        unawaited(
          ref.read(wakeWordControllerProvider.notifier).applySettings(),
        );
      }
    })
    ..onDispose(coordinator.dispose);
  return coordinator;
});

/// Abre la conversación cuando se dice "Viernes" y mantiene la escucha
/// encendida al volver a la app.
class WakeCoordinator with WidgetsBindingObserver {
  WakeCoordinator(this._ref);

  final Ref _ref;
  final _subscriptions = <StreamSubscription<Object?>>[];

  void start() {
    final service = _ref.read(wakeWordServiceProvider);
    final briefings = _ref.read(briefingRequestsProvider);
    _subscriptions
      ..add(service.wakes.listen((_) => _openConversation()))
      ..add(service.actions.listen(_onAction))
      ..add(
        briefings.stream.listen((_) {
          if (briefings.consume()) _openBriefing();
        }),
      );
    WidgetsBinding.instance.addObserver(this);
    unawaited(_onStart(service));
  }

  Future<void> _onStart(WakeWordService service) async {
    await _ref.read(wakeWordControllerProvider.notifier).ensureRunning();
    final action = await service.consumeLaunchAction();
    final wake = await service.consumeLaunchWake();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (action != null) {
        _onAction(action);
      } else if (wake) {
        _openConversation();
      } else if (_ref.read(briefingRequestsProvider).consume()) {
        _openBriefing();
      }
    });
  }

  /// Acceso directo del ícono o del botón de ajustes rápidos.
  void _onAction(String action) {
    if (action.startsWith('invite:')) {
      unawaited(
        _ref
            .read(appRouterProvider)
            .push(AppRoutes.friendInvite(action.substring('invite:'.length))),
      );
      return;
    }
    switch (action) {
      case 'briefing':
        _openBriefing();
      case 'new':
        unawaited(_ref.read(appRouterProvider).push(AppRoutes.newReminder()));
      default:
        _openConversation();
    }
  }

  void _openConversation() {
    final context = rootNavigatorKey.currentContext;
    if (context == null || VoiceAssistantSheet.isOpen) return;
    unawaited(showVoiceAssistant(context, fromWake: true));
  }

  void _openBriefing() {
    final context = rootNavigatorKey.currentContext;
    if (context == null || VoiceAssistantSheet.isOpen) return;
    unawaited(showVoiceAssistant(context, briefing: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final controller = _ref.read(wakeWordControllerProvider.notifier);
    unawaited(controller.ensureRunning().then((_) => controller.refresh()));
  }

  void dispose() {
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    WidgetsBinding.instance.removeObserver(this);
  }
}

/// Consumo de la escucha (se refresca al invalidarlo).
final FutureProvider<WakeStats?> wakeStatsProvider =
    FutureProvider.autoDispose<WakeStats?>(
      (ref) => ref.watch(wakeWordServiceProvider).stats(),
    );
