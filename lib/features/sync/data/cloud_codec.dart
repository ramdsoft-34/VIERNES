import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viernes/core/utils/enum_x.dart';
import 'package:viernes/features/places/domain/place.dart';
import 'package:viernes/features/reminders/domain/entities/recurrence.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_event.dart';

/// Conversión entre las entidades y los documentos de la nube.
///
/// Las fechas se redondean al segundo, igual que en la base local, para que
/// un dato que va y vuelve sea idéntico y no se reaplique sin fin.
abstract final class CloudCodec {
  /// Versión del formato de los documentos, por si cambia en el futuro.
  static const formatVersion = 1;

  static Map<String, Object?> encodeReminder(Reminder r) => {
    'v': formatVersion,
    'title': r.title,
    'notes': r.notes,
    'dueAt': _seconds(r.dueAt),
    'leadTimeMinutes': r.leadTime.inMinutes,
    'recurrence': r.recurrence.repeats ? r.recurrence.encode() : '',
    'priority': r.priority.name,
    'category': r.category.name,
    'status': r.status.name,
    'snoozedUntil': _secondsOrNull(r.snoozedUntil),
    'snoozeCount': r.snoozeCount,
    'source': r.source.name,
    'rawUtterance': r.rawUtterance,
    'nluConfidence': r.nluConfidence,
    'createdAt': _seconds(r.createdAt),
    'updatedAt': _seconds(r.updatedAt),
    'completedAt': _secondsOrNull(r.completedAt),
    'deleted': false,
  };

  static Reminder decodeReminder(String id, Map<String, Object?> data) =>
      Reminder(
        id: id,
        title: data['title'] as String? ?? '',
        notes: data['notes'] as String?,
        dueAt: readDate(data['dueAt']) ?? DateTime(1970),
        leadTime: Duration(minutes: _int(data['leadTimeMinutes'])),
        recurrence: Recurrence.decode(data['recurrence'] as String?),
        priority: enumByName(
          ReminderPriority.values,
          data['priority'] as String? ?? '',
          ReminderPriority.normal,
        ),
        category: enumByName(
          ReminderCategory.values,
          data['category'] as String? ?? '',
          ReminderCategory.other,
        ),
        status: enumByName(
          ReminderStatus.values,
          data['status'] as String? ?? '',
          ReminderStatus.pending,
        ),
        snoozedUntil: readDate(data['snoozedUntil']),
        snoozeCount: _int(data['snoozeCount']),
        source: enumByName(
          ReminderSource.values,
          data['source'] as String? ?? '',
          ReminderSource.manual,
        ),
        rawUtterance: data['rawUtterance'] as String?,
        nluConfidence: (data['nluConfidence'] as num?)?.toDouble(),
        createdAt: readDate(data['createdAt']) ?? DateTime(1970),
        updatedAt: readDate(data['updatedAt']) ?? DateTime(1970),
        completedAt: readDate(data['completedAt']),
      );

  static Map<String, Object?> encodeEvent(ReminderEvent e) => {
    'v': formatVersion,
    'reminderId': e.reminderId,
    'reminderTitle': e.reminderTitle,
    'type': e.type.name,
    'occurredAt': _seconds(e.occurredAt),
    'onTime': e.onTime,
    'deleted': false,
  };

  static ReminderEvent decodeEvent(String syncId, Map<String, Object?> data) =>
      ReminderEvent(
        syncId: syncId,
        reminderId: data['reminderId'] as String? ?? '',
        reminderTitle: data['reminderTitle'] as String? ?? '',
        type: enumByName(
          ReminderEventType.values,
          data['type'] as String? ?? '',
          ReminderEventType.updated,
        ),
        occurredAt: readDate(data['occurredAt']) ?? DateTime(1970),
        onTime: data['onTime'] as bool?,
      );

  static Map<String, Object?> encodePlace(Place p) => {
    'v': formatVersion,
    'name': p.name,
    'latitude': p.latitude,
    'longitude': p.longitude,
    'radiusMeters': p.radiusMeters,
    'createdAt': _seconds(p.createdAt),
    'updatedAt': _seconds(p.updatedAt ?? p.createdAt),
    'deleted': false,
  };

  static Place decodePlace(String id, Map<String, Object?> data) => Place(
    id: id,
    name: data['name'] as String? ?? '',
    latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
    longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
    radiusMeters:
        (data['radiusMeters'] as num?)?.toDouble() ?? Place.defaultRadius,
    createdAt: readDate(data['createdAt']) ?? DateTime(1970),
    updatedAt: readDate(data['updatedAt']),
  );

  static Map<String, Object?> encodeLocationReminder(LocationReminder r) => {
    'v': formatVersion,
    'title': r.title,
    'placeId': r.placeId,
    'onArrive': r.onArrive,
    'done': r.done,
    'createdAt': _seconds(r.createdAt),
    'completedAt': _secondsOrNull(r.completedAt),
    'updatedAt': _seconds(r.updatedAt ?? r.createdAt),
    'deleted': false,
  };

  static LocationReminder decodeLocationReminder(
    String id,
    Map<String, Object?> data,
  ) => LocationReminder(
    id: id,
    title: data['title'] as String? ?? '',
    placeId: data['placeId'] as String? ?? '',
    onArrive: data['onArrive'] != false,
    done: data['done'] == true,
    createdAt: readDate(data['createdAt']) ?? DateTime(1970),
    completedAt: readDate(data['completedAt']),
    updatedAt: readDate(data['updatedAt']),
  );

  /// Acepta `Timestamp` (lo que devuelve Firestore) o `DateTime`.
  static DateTime? readDate(Object? value) => switch (value) {
    final Timestamp t => _seconds(t.toDate()),
    final DateTime d => _seconds(d),
    _ => null,
  };

  static DateTime _seconds(DateTime d) => DateTime.fromMillisecondsSinceEpoch(
    d.millisecondsSinceEpoch ~/ 1000 * 1000,
  );

  static DateTime? _secondsOrNull(DateTime? d) =>
      d == null ? null : _seconds(d);

  static int _int(Object? value) => (value as num?)?.toInt() ?? 0;
}
