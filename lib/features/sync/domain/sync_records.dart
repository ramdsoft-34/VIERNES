import 'package:flutter/foundation.dart';
import 'package:viernes/features/places/domain/place.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_event.dart';

/// Qué tipo de dato se borró.
enum SyncEntity { reminder, event, place, locationReminder }

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
    this.places = const [],
    this.locationReminders = const [],
  });

  final List<Reminder> reminders;

  /// Siempre con `syncId`.
  final List<ReminderEvent> events;
  final List<Tombstone> deletions;

  /// Lugares guardados (con `updatedAt`).
  final List<Place> places;
  final List<LocationReminder> locationReminders;

  bool get isEmpty =>
      reminders.isEmpty &&
      events.isEmpty &&
      deletions.isEmpty &&
      places.isEmpty &&
      locationReminders.isEmpty;

  int get length =>
      reminders.length +
      events.length +
      deletions.length +
      places.length +
      locationReminders.length;

  /// Los mismos cambios sin los tipos de dato de [skipped] (los que la nube
  /// rechazó y quedan pendientes para la próxima vez).
  LocalChanges without(Set<SyncEntity> skipped) => skipped.isEmpty
      ? this
      : LocalChanges(
          reminders: skipped.contains(SyncEntity.reminder)
              ? const []
              : reminders,
          events: skipped.contains(SyncEntity.event) ? const [] : events,
          places: skipped.contains(SyncEntity.place) ? const [] : places,
          locationReminders: skipped.contains(SyncEntity.locationReminder)
              ? const []
              : locationReminders,
          deletions: [
            for (final d in deletions)
              if (!skipped.contains(d.entity)) d,
          ],
        );
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

/// Un dato sencillo (lugar o recordatorio por ubicación) como está en la
/// nube. [value] es nulo si se borró.
@immutable
class RemoteItem<T> {
  const RemoteItem({required this.id, required this.updatedAt, this.value});

  final String id;
  final T? value;
  final DateTime updatedAt;

  bool get deleted => value == null;
}

/// Cambios en la nube desde la última descarga.
@immutable
class RemoteChanges {
  const RemoteChanges({
    this.reminders = const [],
    this.events = const [],
    this.places = const [],
    this.locationReminders = const [],
    this.cursor,
    this.skipped = const {},
  });

  final List<RemoteReminder> reminders;
  final List<RemoteEvent> events;
  final List<RemoteItem<Place>> places;
  final List<RemoteItem<LocationReminder>> locationReminders;

  /// Marca de tiempo del servidor del cambio más reciente recibido; la
  /// próxima descarga parte de aquí.
  final DateTime? cursor;

  /// Tipos de dato que la nube no dejó leer (reglas sin publicar).
  final Set<SyncEntity> skipped;

  bool get isEmpty =>
      reminders.isEmpty &&
      events.isEmpty &&
      places.isEmpty &&
      locationReminders.isEmpty;

  /// Cambiaron lugares o recordatorios por ubicación (hay que rehacer las
  /// geocercas).
  bool get touchesPlaces => places.isNotEmpty || locationReminders.isNotEmpty;
}

/// Resultado de una sincronización.
@immutable
class SyncReport {
  const SyncReport({
    this.uploaded = 0,
    this.downloaded = 0,
    this.skipped = const {},
  });

  final int uploaded;

  /// Cambios de la nube que modificaron este teléfono.
  final int downloaded;

  /// Tipos de dato que no se pudieron sincronizar porque la nube los
  /// rechazó (reglas de seguridad sin publicar). El resto sí se sincronizó.
  final Set<SyncEntity> skipped;
}
