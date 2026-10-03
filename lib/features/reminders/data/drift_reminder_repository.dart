import 'package:drift/drift.dart';
import 'package:viernes/core/database/app_database.dart';
import 'package:viernes/core/utils/id_generator.dart';
import 'package:viernes/features/reminders/data/reminder_mapper.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_event.dart';
import 'package:viernes/features/reminders/domain/repositories/reminder_repository.dart';

class DriftReminderRepository implements ReminderRepository {
  DriftReminderRepository(this._db, {this._ids = const UuidIdGenerator()});

  final AppDatabase _db;
  final IdGenerator _ids;

  @override
  Stream<List<Reminder>> watchByStatus(Set<ReminderStatus> statuses) {
    final query = _db.select(_db.reminders)
      ..where((r) => r.status.isIn(statuses.map((s) => s.name)));
    return query.watch().map(
      (rows) =>
          rows.map((row) => row.toDomain()).toList()
            ..sort((a, b) => a.nextTriggerAt.compareTo(b.nextTriggerAt)),
    );
  }

  @override
  Stream<List<Reminder>> watchDueBetween(DateTime from, DateTime to) {
    final query = _db.select(_db.reminders)
      ..where(
        (r) =>
            r.dueAt.isBiggerOrEqualValue(from) & r.dueAt.isSmallerThanValue(to),
      )
      ..orderBy([(r) => OrderingTerm.asc(r.dueAt)]);
    return query.watch().map(
      (rows) => rows.map((row) => row.toDomain()).toList(),
    );
  }

  @override
  Stream<Reminder?> watchById(String id) =>
      (_db.select(_db.reminders)..where((r) => r.id.equals(id)))
          .watchSingleOrNull()
          .map((row) => row?.toDomain());

  @override
  Future<Reminder?> findById(String id) async {
    final row = await (_db.select(
      _db.reminders,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Future<void> save(Reminder reminder, {ReminderEvent? event}) =>
      _db.transaction(() async {
        await _db
            .into(_db.reminders)
            .insertOnConflictUpdate(reminder.toCompanion());
        // Si se restauró tras borrarlo (deshacer), ya no hay que borrarlo en
        // la nube.
        await _forgetTombstone(SyncEntities.reminder, reminder.id);
        if (event != null) await _insertEvent(event);
      });

  @override
  Future<void> delete(String id, {ReminderEvent? event}) =>
      _db.transaction(() async {
        await (_db.delete(_db.reminders)..where((r) => r.id.equals(id))).go();
        await _tombstone(SyncEntities.reminder, id);
        if (event != null) await _insertEvent(event);
      });

  @override
  Future<void> revert(
    Reminder previous, {
    required ReminderEventType undoneEvent,
  }) => _db.transaction(() async {
    await _db
        .into(_db.reminders)
        .insertOnConflictUpdate(previous.toCompanion());
    final last =
        await (_db.select(_db.reminderEvents)
              ..where(
                (e) =>
                    e.reminderId.equals(previous.id) &
                    e.type.equals(undoneEvent.name),
              )
              ..orderBy([(e) => OrderingTerm.desc(e.id)])
              ..limit(1))
            .getSingleOrNull();
    if (last != null) {
      await (_db.delete(
        _db.reminderEvents,
      )..where((e) => e.id.equals(last.id))).go();
      final syncId = last.syncId;
      if (syncId != null) await _tombstone(SyncEntities.event, syncId);
    }
  });

  Future<void> _insertEvent(ReminderEvent event) => _db
      .into(_db.reminderEvents)
      .insert(event.toCompanion(syncId: event.syncId ?? _ids.next()));

  Future<void> _tombstone(String entity, String entityId) => _db
      .into(_db.syncTombstones)
      .insertOnConflictUpdate(
        SyncTombstonesCompanion.insert(
          entity: entity,
          entityId: entityId,
          deletedAt: DateTime.now(),
        ),
      );

  Future<void> _forgetTombstone(String entity, String entityId) =>
      (_db.delete(_db.syncTombstones)..where(
            (t) => t.entity.equals(entity) & t.entityId.equals(entityId),
          ))
          .go();

  @override
  Stream<List<ReminderEvent>> watchEvents({
    Set<ReminderEventType>? types,
    DateTime? since,
  }) {
    final query = _db.select(_db.reminderEvents);
    if (types != null) {
      query.where((e) => e.type.isIn(types.map((t) => t.name)));
    }
    if (since != null) {
      query.where((e) => e.occurredAt.isBiggerOrEqualValue(since));
    }
    query.orderBy([
      (e) => OrderingTerm.desc(e.occurredAt),
      (e) => OrderingTerm.desc(e.id),
    ]);
    return query.watch().map(
      (rows) => rows.map((row) => row.toDomain()).toList(),
    );
  }
}
