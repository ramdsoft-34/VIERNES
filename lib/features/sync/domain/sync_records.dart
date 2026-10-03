import 'package:flutter/foundation.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_event.dart';

/// Qué tipo de dato se borró.
enum SyncEntity { reminder, event }

/// Un borrado local que falta avisar a la nube.
@immutable
class Tombstone {
  const Tombstone({
    required this.entity,
    required this.entityId,
    required this.deletedAt,
  });

  final SyncEntity entity;

  /// `id` del recordatorio o `syncId` del evento.
  final String entityId;
  final DateTime deletedAt;

  @override
  bool operator ==(Object other) =>
      other is Tombstone &&
      other.entity == entity &&
      other.entityId == entityId &&
      other.deletedAt == deletedAt;

  @override
  int get hashCode => Object.hash(entity, entityId, deletedAt);
}

/// Lo que hay que subir: cambios locales todavía no confirmados por la nube.
@immutable
class LocalChanges {
  const LocalChanges({
    this.reminders = const [],
    this.events = const [],
    this.deletions = const [],
  });

  final List<Reminder> reminders;

  /// Siempre con `syncId`.
  final List<ReminderEvent> events;
  final List<Tombstone> deletions;

  bool get isEmpty => reminders.isEmpty && events.isEmpty && deletions.isEmpty;

  int get length => reminders.length + events.length + deletions.length;
}

/// Un recordatorio como está en la nube. [reminder] es nulo si se borró.
@immutable
class RemoteReminder {
  const RemoteReminder({
    required this.id,
    required this.updatedAt,
    this.reminder,
  });

  final String id;
  final Reminder? reminder;

  /// Hora del último cambio según el teléfono que lo hizo; desempata los
  /// conflictos con cambios locales sin subir.
  final DateTime updatedAt;

  bool get deleted => reminder == null;
}

/// Un evento del historial como está en la nube. [event] es nulo si se
/// borró (al deshacer una acción).
@immutable
class RemoteEvent {
  const RemoteEvent({required this.syncId, this.event});

  final String syncId;
  final ReminderEvent? event;

  bool get deleted => event == null;
}

/// Cambios en la nube desde la última descarga.
@immutable
class RemoteChanges {
  const RemoteChanges({
    this.reminders = const [],
    this.events = const [],
    this.cursor,
  });

  final List<RemoteReminder> reminders;
  final List<RemoteEvent> events;

  /// Marca de tiempo del servidor del cambio más reciente recibido; la
  /// próxima descarga parte de aquí.
  final DateTime? cursor;

  bool get isEmpty => reminders.isEmpty && events.isEmpty;
}

/// Resultado de una sincronización.
@immutable
class SyncReport {
  const SyncReport({this.uploaded = 0, this.downloaded = 0});

  final int uploaded;

  /// Cambios de la nube que modificaron este teléfono.
  final int downloaded;
}
