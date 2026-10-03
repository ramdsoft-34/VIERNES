import 'package:drift/drift.dart';
import 'package:viernes/core/database/app_database.dart';
import 'package:viernes/features/places/data/places_repository.dart';
import 'package:viernes/features/places/domain/place.dart';
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
    final places = await (_db.select(
      _db.places,
    )..where((p) => p.dirty.equals(true))).get();
    final locationReminders = await (_db.select(
      _db.locationReminders,
    )..where((r) => r.dirty.equals(true))).get();
    return LocalChanges(
      reminders: [for (final row in reminders) row.toDomain()],
      events: [for (final row in events) row.toDomain()],
      places: [for (final row in places) PlacesRepository.placeFromRow(row)],
      locationReminders: [
        for (final row in locationReminders)
          PlacesRepository.reminderFromRow(row),
      ],
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
    for (final place in changes.places) {
      await (_db.update(_db.places)..where(
            (p) =>
                p.id.equals(place.id) &
                (place.updatedAt == null
                    ? p.updatedAt.isNull()
                    : p.updatedAt.equals(place.updatedAt!)),
          ))
          .write(const PlacesCompanion(dirty: Value(false)));
    }
    for (final reminder in changes.locationReminders) {
      await (_db.update(_db.locationReminders)..where(
            (r) =>
                r.id.equals(reminder.id) &
                (reminder.updatedAt == null
                    ? r.updatedAt.isNull()
                    : r.updatedAt.equals(reminder.updatedAt!)),
          ))
          .write(const LocationRemindersCompanion(dirty: Value(false)));
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
        '(SELECT COUNT(*) FROM places WHERE dirty = 1) + '
        '(SELECT COUNT(*) FROM location_reminders WHERE dirty = 1) + '
        '(SELECT COUNT(*) FROM sync_tombstones '
        "WHERE entity != 'attachment') AS pending",
        readsFrom: {
          _db.reminders,
          _db.reminderEvents,
          _db.places,
          _db.locationReminders,
          _db.syncTombstones,
        },
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
    for (final remote in changes.places) {
      if (await _applyPlace(remote)) applied++;
    }
    for (final remote in changes.locationReminders) {
      if (await _applyLocationReminder(remote)) applied++;
    }
    return applied;
  });

  /// Misma regla que los recordatorios: si aquí no hay cambios pendientes,
  /// manda la nube; si los hay, gana el más reciente.
  Future<bool> _applyPlace(RemoteItem<Place> remote) async {
    final local = await (_db.select(
      _db.places,
    )..where((p) => p.id.equals(remote.id))).getSingleOrNull();
    final place = remote.value;
    final apply = await _resolve(
      SyncEntity.place,
      remote.id,
      remote.updatedAt,
      deleted: place == null,
      localDirty: local?.dirty ?? false,
      localUpdatedAt: local?.updatedAt ?? local?.createdAt,
      exists: local != null,
    );
    if (!apply) return false;
    if (place == null) {
      await (_db.delete(_db.places)..where((p) => p.id.equals(remote.id))).go();
      return true;
    }
    if (local != null &&
        !local.dirty &&
        PlacesRepository.placeFromRow(local) == place) {
      return false;
    }
    await _db
        .into(_db.places)
        .insertOnConflictUpdate(
          PlacesCompanion.insert(
            id: place.id,
            name: place.name,
            latitude: place.latitude,
            longitude: place.longitude,
            radiusMeters: Value(place.radiusMeters),
            createdAt: place.createdAt,
            updatedAt: Value(place.updatedAt),
            dirty: const Value(false),
          ),
        );
    return true;
  }

  Future<bool> _applyLocationReminder(
    RemoteItem<LocationReminder> remote,
  ) async {
    final local = await (_db.select(
      _db.locationReminders,
    )..where((r) => r.id.equals(remote.id))).getSingleOrNull();
    final reminder = remote.value;
    final apply = await _resolve(
      SyncEntity.locationReminder,
      remote.id,
      remote.updatedAt,
      deleted: reminder == null,
      localDirty: local?.dirty ?? false,
      localUpdatedAt: local?.updatedAt ?? local?.createdAt,
      exists: local != null,
    );
    if (!apply) return false;
    if (reminder == null) {
      await (_db.delete(
        _db.locationReminders,
      )..where((r) => r.id.equals(remote.id))).go();
      return true;
    }
    if (local != null &&
        !local.dirty &&
        PlacesRepository.reminderFromRow(local) == reminder &&
        local.completedAt == reminder.completedAt) {
      return false;
    }
    await _db
        .into(_db.locationReminders)
        .insertOnConflictUpdate(
          LocationRemindersCompanion.insert(
            id: reminder.id,
            title: reminder.title,
            placeId: reminder.placeId,
            onArrive: Value(reminder.onArrive),
            done: Value(reminder.done),
            createdAt: reminder.createdAt,
            completedAt: Value(reminder.completedAt),
            updatedAt: Value(reminder.updatedAt),
            dirty: const Value(false),
          ),
        );
    return true;
  }

  /// Decide si un cambio de la nube se aplica, según los borrados y los
  /// cambios locales pendientes.
  Future<bool> _resolve(
    SyncEntity entity,
    String id,
    DateTime remoteUpdatedAt, {
    required bool deleted,
    required bool localDirty,
    required DateTime? localUpdatedAt,
    required bool exists,
  }) async {
    final tombstone = await _tombstone(entity, id);
    if (deleted) {
      if (tombstone != null) await _forget(entity, id);
      if (!exists) return false;
      // Se editó aquí después de borrarlo allá: se volverá a subir.
      return !(localDirty &&
          localUpdatedAt != null &&
          localUpdatedAt.isAfter(remoteUpdatedAt));
    }
    if (tombstone != null) {
      if (!remoteUpdatedAt.isAfter(tombstone.deletedAt)) return false;
      await _forget(entity, id);
    }
    return !(exists &&
        localDirty &&
        localUpdatedAt != null &&
        !remoteUpdatedAt.isAfter(localUpdatedAt));
  }

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
    await _db
        .update(_db.places)
        .write(const PlacesCompanion(dirty: Value(true)));
    await _db
        .update(_db.locationReminders)
        .write(const LocationRemindersCompanion(dirty: Value(true)));
  });

  Future<bool> hasData() async {
    final count = await _db
        .customSelect(
          'SELECT (SELECT COUNT(*) FROM reminders) + '
          '(SELECT COUNT(*) FROM reminder_events) + '
          '(SELECT COUNT(*) FROM places) AS total',
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
    await _db.delete(_db.locationReminders).go();
    await _db.delete(_db.places).go();
    await _db.delete(_db.attachments).go();
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
    SyncEntity.place => SyncEntities.place,
    SyncEntity.locationReminder => SyncEntities.locationReminder,
  };

  static SyncEntity? _entity(String name) => switch (name) {
    SyncEntities.reminder => SyncEntity.reminder,
    SyncEntities.event => SyncEntity.event,
    SyncEntities.place => SyncEntity.place,
    SyncEntities.locationReminder => SyncEntity.locationReminder,
    _ => null,
  };
}
