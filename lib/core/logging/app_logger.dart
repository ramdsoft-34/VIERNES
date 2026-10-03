import 'dart:developer' as developer;

/// Registro centralizado. Hoy escribe en la consola de depuración; en la fase
/// de publicación se conecta aquí el reporte de errores (con consentimiento).
abstract final class AppLogger {
  static void info(String message, {String tag = 'viernes'}) =>
      developer.log(message, name: tag);

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String tag = 'viernes',
  }) => developer.log(
    message,
    name: tag,
    error: error,
    stackTrace: stackTrace,
    level: 1000,
  );
}
