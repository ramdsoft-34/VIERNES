import 'package:flutter/services.dart';
import 'package:viernes/core/logging/app_logger.dart';

/// Puente con el código nativo de Android (`MainActivity.kt`).
class SystemBridge {
  const SystemBridge();

  static const _channel = MethodChannel('com.ramdsoft.viernes/system');

  /// Muestra la app sobre la pantalla de bloqueo (solo durante una alerta).
  Future<void> setShowOverLockScreen({required bool enabled}) async {
    try {
      await _channel.invokeMethod<void>('setShowOverLockScreen', {
        'enabled': enabled,
      });
    } on Object catch (error) {
      AppLogger.error(
        'No se pudo cambiar la pantalla de bloqueo',
        error: error,
      );
    }
  }

  /// Android 14+: si el usuario permitió las alertas a pantalla completa.
  Future<bool> canUseFullScreenIntent() async {
    try {
      return await _channel.invokeMethod<bool>('canUseFullScreenIntent') ??
          true;
    } on Object catch (_) {
      return true;
    }
  }
}
