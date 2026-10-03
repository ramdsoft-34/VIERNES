import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:viernes/core/logging/app_logger.dart';

/// Consumo de la escucha de «Viernes» medido en el teléfono.
@immutable
class WakeStats {
  const WakeStats({
    required this.listening,
    required this.frames,
    required this.skippedFrames,
    required this.averageInferenceMs,
    this.batteryPercentPerHour,
    this.cpuPercent,
  });

  factory WakeStats.fromMap(Map<Object?, Object?> map) {
    double? optional(Object? v) => v is num && v >= 0 ? v.toDouble() : null;
    return WakeStats(
      listening: Duration(
        milliseconds: (map['listeningMs'] as num?)?.toInt() ?? 0,
      ),
      frames: (map['frames'] as num?)?.toInt() ?? 0,
      skippedFrames: (map['skipped'] as num?)?.toInt() ?? 0,
      averageInferenceMs: (map['avgInferenceMs'] as num?)?.toDouble() ?? 0,
      batteryPercentPerHour: optional(map['batteryPerHour']),
      cpuPercent: optional(map['cpuPercent']),
    );
  }

  /// Tiempo total escuchando desde que se reiniciaron las cifras.
  final Duration listening;

  /// Bloques de 80 ms analizados.
  final int frames;

  /// Bloques en silencio en los que se ahorró el modelo pesado.
  final int skippedFrames;

  /// Tiempo medio del modelo por bloque analizado.
  final double averageInferenceMs;

  /// Batería gastada por hora de escucha (sin cargar). Nulo si aún no hay
  /// datos suficientes.
  final double? batteryPercentPerHour;

  /// Uso de procesador de la app mientras escucha.
  final double? cpuPercent;

  /// Parte del tiempo en silencio (ahorro).
  double get savedRatio => frames == 0 ? 0 : skippedFrames / frames;
}

/// Escucha en segundo plano de la palabra "Viernes".
abstract interface class WakeWordService {
  /// [chime]: sonido corto al oír «Viernes». [saveSamples]: guardar el audio
  /// de cada activación para reentrenar el detector (con consentimiento).
  Future<void> start({
    required String modelPath,
    required double threshold,
    bool chime = true,
    bool saveSamples = false,
    bool lowBatteryPause = true,
  });

  Future<void> stop();

  /// Suelta el micrófono (p. ej. mientras la app escucha una frase).
  Future<void> pause();

  Future<void> resume();

  Future<bool> isRunning();

  /// El APK trae el detector propio de «Viernes» (`assets/wakeword`).
  Future<bool> hasOwnModel();

  /// `true` si la app se abrió porque se dijo "Viernes" (y lo marca como
  /// atendido).
  Future<bool> consumeLaunchWake();

  /// Permiso "mostrar sobre otras apps": abre Viernes al instante.
  Future<bool> canOpenOverOtherApps();

  Future<void> requestOpenOverOtherApps();

  /// Se emite cada vez que se dice "Viernes" con la app abierta.
  Stream<void> get wakes;

  /// Accesos directos (ícono, botón de ajustes rápidos): `briefing` (leer el
  /// resumen) o `new` (nuevo recordatorio).
  Stream<String> get actions;

  /// Acción con la que se abrió la app, si fue un acceso directo (y la marca
  /// como atendida).
  Future<String?> consumeLaunchAction();

  /// Consumo medido de la escucha.
  Future<WakeStats?> stats();

  Future<void> resetStats();
}

/// Implementación con el servicio nativo `WakeWordService.kt`.
class AndroidWakeWordService implements WakeWordService {
  AndroidWakeWordService() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onWake':
          _wakes.add(null);
        case 'onAction':
          if (call.arguments case final String action) _actions.add(action);
      }
    });
  }

  static const _channel = MethodChannel('com.ramdsoft.viernes/wake_word');
  final _wakes = StreamController<void>.broadcast();
  final _actions = StreamController<String>.broadcast();

  @override
  Stream<void> get wakes => _wakes.stream;

  @override
  Stream<String> get actions => _actions.stream;

  @override
  Future<String?> consumeLaunchAction() => _call<String>('consumeLaunchAction');

  @override
  Future<WakeStats?> stats() async {
    final map = await _call<Map<Object?, Object?>>('stats');
    return map == null ? null : WakeStats.fromMap(map);
  }

  @override
  Future<void> resetStats() => _call('resetStats');

  @override
  Future<void> start({
    required String modelPath,
    required double threshold,
    bool chime = true,
    bool saveSamples = false,
    bool lowBatteryPause = true,
  }) => _call('start', {
    'modelPath': modelPath,
    'threshold': threshold,
    'chime': chime,
    'saveSamples': saveSamples,
    'lowBatteryPause': lowBatteryPause,
  });

  @override
  Future<void> stop() => _call('stop');

  @override
  Future<void> pause() => _call('pause');

  @override
  Future<void> resume() => _call('resume');

  @override
  Future<bool> isRunning() async => await _call<bool>('isRunning') ?? false;

  @override
  Future<bool> hasOwnModel() async => await _call<bool>('hasOwnModel') ?? false;

  @override
  Future<bool> consumeLaunchWake() async =>
      await _call<bool>('consumeLaunchWake') ?? false;

  @override
  Future<bool> canOpenOverOtherApps() async =>
      await _call<bool>('canDrawOverlays') ?? false;

  @override
  Future<void> requestOpenOverOtherApps() => _call('requestDrawOverlays');

  Future<T?> _call<T>(String method, [Map<String, Object?>? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      AppLogger.error('Activación por voz: $method', error: error);
      return null;
    }
  }
}
