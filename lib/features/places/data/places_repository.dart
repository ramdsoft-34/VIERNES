import 'package:drift/drift.dart';
import 'package:viernes/core/database/app_database.dart';
import 'package:viernes/features/places/domain/place.dart';

/// Lugares y recordatorios por ubicación (base local).
///
/// Cada cambio queda pendiente de subir a la cuenta (`dirty`); los borrados
/// dejan una marca en `sync_tombstones` para borrarlos en los otros
/// teléfonos.
class PlacesRepository {
  PlacesRepository(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  Stream<List<Place>> watchPlaces() =>
      (_db.select(_db.places)..orderBy([(p) => OrderingTerm.asc(p.name)]))
          .watch()
          .map((rows) => [for (final r in rows) placeFromRow(r)]);

  Future<List<Place>> places() => watchPlaces().first;

  Future<void> savePlace(Place place) => _db
      .into(_db.places)
      .insertOnConflictUpdate(
        PlacesCompanion.insert(
          id: place.id,
          name: place.name,
          latitude: place.latitude,
          longitude: place.longitude,
          radiusMeters: Value(place.radiusMeters),
          createdAt: place.createdAt,
          updatedAt: Value(_now()),
          dirty: const Value(true),
        ),
      );

  /// Borra el lugar y sus recordatorios.
  Future<void> deletePlace(String id) => _db.transaction(() async {
    final reminders = await (_db.select(
      _db.locationReminders,
    )..where((r) => r.placeId.equals(id))).get();
    for (final r in reminders) {
      await _tombstone(SyncEntities.locationReminder, r.id);
    }
    await (_db.delete(
      _db.locationReminders,
    )..where((r) => r.placeId.equals(id))).go();
    await (_db.delete(_db.places)..where((p) => p.id.equals(id))).go();
    await _tombstone(SyncEntities.place, id);
  });

  /// Pendientes primero, luego los hechos (más recientes arriba).
  Stream<List<LocationReminder>> watchReminders() =>
      (_db.select(_db.locationReminders)..orderBy([
            (r) => OrderingTerm.asc(r.done),
            (r) => OrderingTerm.desc(r.createdAt),
          ]))
          .watch()
          .map((rows) => [for (final r in rows) reminderFromRow(r)]);

  Future<List<LocationReminder>> activeReminders() async => [
    for (final r in await watchReminders().first)
      if (!r.done) r,
  ];

  Future<LocationReminder?> findReminder(String id) async {
    final row = await (_db.select(
      _db.locationReminders,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    return row == null ? null : reminderFromRow(row);
  }

  Future<void> saveReminder(LocationReminder r) => _db
      .into(_db.locationReminders)
      .insertOnConflictUpdate(
        LocationRemindersCompanion.insert(
          id: r.id,
          title: r.title,
          placeId: r.placeId,
          onArrive: Value(r.onArrive),
          done: Value(r.done),
          createdAt: r.createdAt,
          completedAt: Value(r.completedAt),
          updatedAt: Value(_now()),
          dirty: const Value(true),
        ),
      );

  Future<void> setDone(String id, {required bool done, DateTime? at}) =>
      (_db.update(_db.locationReminders)..where((r) => r.id.equals(id))).write(
        LocationRemindersCompanion(
          done: Value(done),
          completedAt: Value(done ? at : null),
          updatedAt: Value(_now()),
          dirty: const Value(true),
        ),
      );

  Future<void> deleteReminder(String id) => _db.transaction(() async {
    await (_db.delete(
      _db.locationReminders,
    )..where((r) => r.id.equals(id))).go();
    await _tombstone(SyncEntities.locationReminder, id);
  });

  Future<void> _tombstone(String entity, String id) => _db
      .into(_db.syncTombstones)
      .insertOnConflictUpdate(
        SyncTombstonesCompanion.insert(
          entity: entity,
          entityId: id,
          deletedAt: _now(),
        ),
      );

  static Place placeFromRow(PlaceRow r) => Place(
    id: r.id,
    name: r.name,
    latitude: r.latitude,
    longitude: r.longitude,
    radiusMeters: r.radiusMeters,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  );

  static LocationReminder reminderFromRow(LocationReminderRow r) =>
      LocationReminder(
        id: r.id,
        title: r.title,
        placeId: r.placeId,
        onArrive: r.onArrive,
        done: r.done,
        createdAt: r.createdAt,
        completedAt: r.completedAt,
        updatedAt: r.updatedAt,
      );
}
