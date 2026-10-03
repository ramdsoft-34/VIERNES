import 'package:flutter/foundation.dart';

/// Un aviso programado para un recordatorio.
@immutable
class PlannedAlert {
  const PlannedAlert({
    required this.notificationId,
    required this.reminderId,
    required this.at,
    required this.step,
    required this.silent,
    required this.fullScreen,
    required this.urgent,
    required this.insistent,
  });

  /// Id de la notificación en Android (estable por recordatorio y paso).
  final int notificationId;
  final String reminderId;
  final DateTime at;

  /// 0 = aviso principal; 1, 2, 3… = insistencias.
  final int step;

  /// Dentro del horario de silencio: sin sonido ni vibración.
  final bool silent;

  /// Mostrar como alarma a pantalla completa (si el sistema lo permite).
  final bool fullScreen;

  /// Prioridad urgente: canal de máxima importancia y sonido de alarma.
  final bool urgent;

  /// El sonido se repite hasta que el usuario atienda la notificación.
  final bool insistent;

  bool get isEscalation => step > 0;

  @override
  bool operator ==(Object other) =>
      other is PlannedAlert &&
      other.notificationId == notificationId &&
      other.reminderId == reminderId &&
      other.at == at &&
      other.step == step &&
      other.silent == silent &&
      other.fullScreen == fullScreen &&
      other.urgent == urgent &&
      other.insistent == insistent;

  @override
  int get hashCode => Object.hash(
    notificationId,
    reminderId,
    at,
    step,
    silent,
    fullScreen,
    urgent,
    insistent,
  );

  @override
  String toString() => 'PlannedAlert($reminderId #$step @ $at)';
}
