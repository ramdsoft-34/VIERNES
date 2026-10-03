import 'dart:async';

import 'package:flutter/services.dart';
import 'package:viernes/core/logging/app_logger.dart';

/// Escucha en segundo plano de la palabra "Viernes".
abstract interface class WakeWordService {
  Future<void> start({required String modelPath, required double threshold});

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
}

/// Implementación con el servicio nativo `WakeWordService.kt`.
class AndroidWakeWordService implements WakeWordService {
  AndroidWakeWordService() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onWake') _wakes.add(null);
    });
  }

  static const _channel = MethodChannel('com.ramdsoft.viernes/wake_word');
  final _wakes = StreamController<void>.broadcast();

  @override
  Stream<void> get wakes => _wakes.stream;

  @override
  Future<void> start({required String modelPath, required double threshold}) =>
      _call('start', {'modelPath': modelPath, 'threshold': threshold});

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
