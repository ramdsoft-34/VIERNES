import 'package:drift/drift.dart';
import 'package:viernes/core/database/app_database.dart';
import 'package:viernes/features/reminders/data/reminder_mapper.dart';
import 'package:viernes/features/sync/domain/sync_records.dart';

/// Lado local de la sincronización: qué falta subir y cómo aplicar lo que
/// llega de la nube.
///
/// Regla de conflictos: si el dato local no tiene cambios pendientes, manda
/// la nube. Si los tiene, gana el cambio más reciente (`updatedAt`).
class DriftSyncStore {
  DriftSyncStore(this._db);

  final AppDatabase _db;

  Future<LocalChanges> pendingChanges() async {
    final reminders = await (_db.select(
      _db.reminders,
    )..where((r) => r.dirty.equals(true))).get();
    final events = await (_db.select(
      _db.reminderEvents,
    )..where((e) => e.dirty.equals(true) & e.syncId.isNotNull())).get();
    final tombstones = await _db.select(_db.syncTombstones).get();
    return LocalChanges(
      reminders: [for (final row in reminders) row.toDomain()],
      events: [for (final row in events) row.toDomain()],
      deletions: [
        for (final row in tombstones)
          if (_entity(row.entity) case final entity?)
            Tombstone(
              entity: entity,
              entityId: row.entityId,
              deletedAt: row.deletedAt,
            ),
      ],
    );
  }

  /// Marca como subido lo que no volvió a cambiar mientras se subía.
  Future<void> markUploaded(LocalChanges changes) => _db.transaction(() async {
    for (final reminder in changes.reminders) {
      await (_db.update(_db.reminders)..where(
            (r) =>
                r.id.equals(reminder.id) &
                r.updatedAt.equals(reminder.updatedAt),
          ))
          .write(const RemindersCompanion(dirty: Value(false)));
    }
    final syncIds = [for (final e in changes.events) ?e.syncId];
    if (syncIds.isNotEmpty) {
      await (_db.update(_db.reminderEvents)
            ..where((e) => e.syncId.isIn(syncIds)))
          .write(const ReminderEventsCompanion(dirty: Value(false)));
    }
    for (final deletion in changes.deletions) {
      await (_db.delete(_db.syncTombstones)..where(
            (t) =>
                t.entity.equals(_entityName(deletion.entity)) &
                t.entityId.equals(deletion.entityId) &
                t.deletedAt.equals(deletion.deletedAt),
          ))
          .go();
    }
  });

  /// Cantidad de cambios sin subir.
  Stream<int> watchPendingCount() => _db
      .customSelect(
        'SELECT '
        '(SELECT COUNT(*) FROM reminders WHERE dirty = 1) + '
        '(SELECT COUNT(*) FROM reminder_events WHERE dirty = 1) + '
        '(SELECT COUNT(*) FROM sync_tombstones) AS pending',
        readsFrom: {_db.reminders, _db.reminderEvents, _db.syncTombstones},
      )
      .watchSingle()
      .map((row) => row.read<int>('pending'));

  Future<int> pendingCount() => watchPendingCount().first;

  /// Aplica los cambios de la nube. Devuelve cuántos modificaron este
  /// teléfono.
  Future<int> applyRemote(RemoteChanges changes) => _db.transaction(() async {
    var applied = 0;
    for (final remote in changes.reminders) {
      if (await _applyReminder(remote)) applied++;
    }
    for (final remote in changes.events) {
      if (await _applyEvent(remote)) applied++;
    }
    return applied;
  });

  Future<bool> _applyReminder(RemoteReminder remote) async {
    final local = await (_db.select(
      _db.reminders,
    )..where((r) => r.id.equals(remote.id))).getSingleOrNull();
    final tombstone = await _tombstone(SyncEntity.reminder, remote.id);

    final reminder = remote.reminder;
    if (reminder == null) {
      if (tombstone != null) {
        // Borrado en los dos lados: no queda nada por avisar.
        await _forget(SyncEntity.reminder, remote.id);
      }
      if (local == null) return false;
      if (local.dirty && local.updatedAt.isAfter(remote.updatedAt)) {
        return false; // Se editó aquí después: se volverá a subir.
      }
      await (_db.delete(
        _db.reminders,
      )..where((r) => r.id.equals(remote.id))).go();
      return true;
    }

    if (tombstone != null) {
      if (!remote.updatedAt.isAfter(tombstone.deletedAt)) return false;
      // Se editó en otro teléfono después de borrarlo aquí: gana la edición.
      await _forget(SyncEntity.reminder, remote.id);
    }
    if (local != null) {
      if (local.dirty && !remote.updatedAt.isAfter(local.updatedAt)) {
        return false;
      }
      if (!local.dirty && local.toDomain() == reminder) return false;
    }
    await _db
        .into(_db.reminders)
        .insertOnConflictUpdate(reminder.toCompanion(dirty: false));
    return true;
  }

  Future<bool> _applyEvent(RemoteEvent remote) async {
    final event = remote.event;
    if (event == null) {
      await _forget(SyncEntity.event, remote.syncId);
      final deleted = await (_db.delete(
        _db.reminderEvents,
      )..where((e) => e.syncId.equals(remote.syncId))).go();
      return deleted > 0;
    }
    if (await _tombstone(SyncEntity.event, remote.syncId) != null) {
      return false;
    }
    final exists = await (_db.select(
      _db.reminderEvents,
    )..where((e) => e.syncId.equals(remote.syncId))).getSingleOrNull();
    if (exists != null) return false;
    await _db
        .into(_db.reminderEvents)
        .insert(event.toCompanion(syncId: remote.syncId, dirty: false));
    return true;
  }

  /// Marca todo como pendiente de subir (al asociar los datos de este
  /// teléfono a una cuenta).
  Future<void> markAllDirty() => _db.transaction(() async {
    await _db
        .update(_db.reminders)
        .write(const RemindersCompanion(dirty: Value(true)));
    await _db
        .update(_db.reminderEvents)
        .write(const ReminderEventsCompanion(dirty: Value(true)));
  });

  Future<bool> hasData() async {
    final count = await _db
        .customSelect(
          'SELECT (SELECT COUNT(*) FROM reminders) + '
          '(SELECT COUNT(*) FROM reminder_events) AS total',
        )
        .getSingle();
    return count.read<int>('total') > 0;
  }

  /// Borra los datos personales de este teléfono (al cerrar sesión).
  Future<void> wipe() => _db.transaction(() async {
    await _db.delete(_db.reminders).go();
    await _db.delete(_db.reminderEvents).go();
    await _db.delete(_db.syncTombstones).go();
    await _db.delete(_db.nluSamples).go();
  });

  Future<SyncTombstoneRow?> _tombstone(SyncEntity entity, String id) =>
      (_db.select(_db.syncTombstones)..where(
            (t) => t.entity.equals(_entityName(entity)) & t.entityId.equals(id),
          ))
          .getSingleOrNull();

  Future<void> _forget(SyncEntity entity, String id) =>
      (_db.delete(_db.syncTombstones)..where(
            (t) => t.entity.equals(_entityName(entity)) & t.entityId.equals(id),
          ))
          .go();

  static String _entityName(SyncEntity entity) => switch (entity) {
    SyncEntity.reminder => SyncEntities.reminder,
    SyncEntity.event => SyncEntities.event,
  };

  static SyncEntity? _entity(String name) => switch (name) {
    SyncEntities.reminder => SyncEntity.reminder,
    SyncEntities.event => SyncEntity.event,
    _ => null,
  };
}
