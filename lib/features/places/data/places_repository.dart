import 'package:drift/drift.dart';
import 'package:viernes/core/database/app_database.dart';
import 'package:viernes/features/places/domain/place.dart';

/// Lugares y recordatorios por ubicación (base local).
class PlacesRepository {
  PlacesRepository(this._db);

  final AppDatabase _db;

  Stream<List<Place>> watchPlaces() =>
      (_db.select(_db.places)..orderBy([(p) => OrderingTerm.asc(p.name)]))
          .watch()
          .map((rows) => [for (final r in rows) _place(r)]);

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
        ),
      );

  /// Borra el lugar y sus recordatorios.
  Future<void> deletePlace(String id) => _db.transaction(() async {
    await (_db.delete(
      _db.locationReminders,
    )..where((r) => r.placeId.equals(id))).go();
    await (_db.delete(_db.places)..where((p) => p.id.equals(id))).go();
  });

  /// Pendientes primero, luego los hechos (más recientes arriba).
  Stream<List<LocationReminder>> watchReminders() =>
      (_db.select(_db.locationReminders)..orderBy([
            (r) => OrderingTerm.asc(r.done),
            (r) => OrderingTerm.desc(r.createdAt),
          ]))
          .watch()
          .map((rows) => [for (final r in rows) _reminder(r)]);

  Future<List<LocationReminder>> activeReminders() async => [
    for (final r in await watchReminders().first)
      if (!r.done) r,
  ];

  Future<LocationReminder?> findReminder(String id) async {
    final row = await (_db.select(
      _db.locationReminders,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    return row == null ? null : _reminder(row);
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
        ),
      );

  Future<void> setDone(String id, {required bool done, DateTime? at}) =>
      (_db.update(_db.locationReminders)..where((r) => r.id.equals(id))).write(
        LocationRemindersCompanion(
          done: Value(done),
          completedAt: Value(done ? at : null),
        ),
      );

  Future<void> deleteReminder(String id) => (_db.delete(
    _db.locationReminders,
  )..where((r) => r.id.equals(id))).go();

  static Place _place(PlaceRow r) => Place(
    id: r.id,
    name: r.name,
    latitude: r.latitude,
    longitude: r.longitude,
    radiusMeters: r.radiusMeters,
    createdAt: r.createdAt,
  );

  static LocationReminder _reminder(LocationReminderRow r) => LocationReminder(
    id: r.id,
    title: r.title,
    placeId: r.placeId,
    onArrive: r.onArrive,
    done: r.done,
    createdAt: r.createdAt,
    completedAt: r.completedAt,
  );
}
