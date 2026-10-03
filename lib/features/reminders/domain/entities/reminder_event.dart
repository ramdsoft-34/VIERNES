import 'package:flutter/foundation.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';

/// Hecho ocurrido sobre un recordatorio. Es la fuente del historial y de las
/// estadísticas, y sobrevive aunque el recordatorio se elimine.
@immutable
class ReminderEvent {
  const ReminderEvent({
    required this.reminderId,
    required this.reminderTitle,
    required this.type,
    required this.occurredAt,
    this.id,
    this.onTime,
    this.syncId,
  });

  final int? id;

  /// Identificador global para sincronizar con la cuenta. Lo asigna el
  /// repositorio al guardar.
  final String? syncId;
  final String reminderId;

  /// Título en el momento del evento (el recordatorio puede cambiar o
  /// borrarse).
  final String reminderTitle;
  final ReminderEventType type;
  final DateTime occurredAt;

  /// Solo para [ReminderEventType.completed]: si se cumplió antes de la hora
  /// límite.
  final bool? onTime;

  @override
  bool operator ==(Object other) =>
      other is ReminderEvent &&
      other.id == id &&
      other.reminderId == reminderId &&
      other.reminderTitle == reminderTitle &&
      other.type == type &&
      other.occurredAt == occurredAt &&
      other.onTime == onTime &&
      other.syncId == syncId;

  @override
  int get hashCode => Object.hash(
    id,
    reminderId,
    reminderTitle,
    type,
    occurredAt,
    onTime,
    syncId,
  );
}
