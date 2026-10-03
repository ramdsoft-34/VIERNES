import 'package:flutter/foundation.dart';
import 'package:viernes/features/alerts/domain/planned_alert.dart';

/// Texto visible de un aviso.
@immutable
class AlertContent {
  const AlertContent({required this.title, required this.body});

  final String title;
  final String body;
}

/// Programa avisos en el sistema. La implementación real usa las
/// notificaciones y alarmas exactas de Android.
abstract interface class AlertScheduler {
  Future<void> schedule(PlannedAlert alert, AlertContent content);

  Future<void> cancel(Iterable<int> notificationIds);

  /// Cancela todos los avisos de recordatorios.
  Future<void> cancelAll();
}
