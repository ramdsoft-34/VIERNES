import 'dart:async';

import 'package:viernes/features/account/domain/app_user.dart';
import 'package:viernes/features/account/domain/auth_repository.dart';
import 'package:viernes/features/places/domain/place.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_event.dart';
import 'package:viernes/features/sync/domain/remote_sync_source.dart';
import 'package:viernes/features/sync/domain/sync_records.dart';

class _Doc<T> {
  _Doc(this.value, this.updatedAt, this.serverAt);

  final T? value;
  final DateTime updatedAt;
  final DateTime serverAt;
}

/// Nube en memoria con reloj de servidor propio, compartible entre varios
/// "teléfonos" en una prueba.
class FakeRemoteSyncSource implements RemoteSyncSource {
  final reminders = <String, Map<String, _Doc<Reminder>>>{};
  final events = <String, Map<String, _Doc<ReminderEvent>>>{};
  final places = <String, Map<String, _Doc<Place>>>{};
  final locationReminders = <String, Map<String, _Doc<LocationReminder>>>{};
  final settings = <String, Map<String, Object?>>{};
  final profiles = <String, AppUser>{};

  /// Simula no tener internet.
  bool offline = false;

  /// Tipos de dato que la nube rechaza (reglas viejas).
  Set<SyncEntity> denied = {};
  int pushes = 0;

  var _serverClock = DateTime(2026);

  DateTime _tick() => _serverClock = _serverClock.add(
    const Duration(seconds: 1),
  );

  void _check() {
    if (offline) throw TimeoutException('sin internet');
  }

  @override
  Future<Set<SyncEntity>> push(String uid, LocalChanges all) async {
    _check();
    pushes++;
    final changes = all.without(denied);
    final userReminders = reminders.putIfAbsent(uid, () => {});
    final userEvents = events.putIfAbsent(uid, () => {});
    for (final r in changes.reminders) {
      userReminders[r.id] = _Doc(r, r.updatedAt, _tick());
    }
    for (final e in changes.events) {
      userEvents[e.syncId!] = _Doc(e, e.occurredAt, _tick());
    }
    final userPlaces = places.putIfAbsent(uid, () => {});
    final userLocation = locationReminders.putIfAbsent(uid, () => {});
    for (final p in changes.places) {
      userPlaces[p.id] = _Doc(p, p.updatedAt ?? p.createdAt, _tick());
    }
    for (final r in changes.locationReminders) {
      userLocation[r.id] = _Doc(r, r.updatedAt ?? r.createdAt, _tick());
    }
    for (final d in changes.deletions) {
      switch (d.entity) {
        case SyncEntity.reminder:
          userReminders[d.entityId] = _Doc(null, d.deletedAt, _tick());
        case SyncEntity.event:
          userEvents[d.entityId] = _Doc(null, d.deletedAt, _tick());
        case SyncEntity.place:
          userPlaces[d.entityId] = _Doc(null, d.deletedAt, _tick());
        case SyncEntity.locationReminder:
          userLocation[d.entityId] = _Doc(null, d.deletedAt, _tick());
      }
    }
    return denied;
  }

  @override
  Future<RemoteChanges> pull(String uid, {DateTime? since}) async {
    _check();
    bool isNew(_Doc<Object?> doc) =>
        since == null || doc.serverAt.isAfter(since);
    var cursor = since;
    void track(_Doc<Object?> doc) {
      if (cursor == null || doc.serverAt.isAfter(cursor!)) {
        cursor = doc.serverAt;
      }
    }

    final changedReminders = <RemoteReminder>[];
    for (final MapEntry(:key, :value) in (reminders[uid] ?? {}).entries) {
      if (!isNew(value)) continue;
      track(value);
      changedReminders.add(
        RemoteReminder(
          id: key,
          updatedAt: value.updatedAt,
          reminder: value.value,
        ),
      );
    }
    final changedEvents = <RemoteEvent>[];
    for (final MapEntry(:key, :value) in (events[uid] ?? {}).entries) {
      if (!isNew(value)) continue;
      track(value);
      changedEvents.add(RemoteEvent(syncId: key, event: value.value));
    }
    List<RemoteItem<T>> changed<T>(Map<String, _Doc<T>>? docs) => [
      for (final MapEntry(:key, :value) in (docs ?? {}).entries)
        if (isNew(value)) ...[
          RemoteItem<T>(
            id: key,
            updatedAt: value.updatedAt,
            value: value.value,
          ),
        ],
    ];
    final changedPlaces = changed(places[uid]);
    final changedLocation = changed(locationReminders[uid]);
    for (final doc in [
      ...(places[uid] ?? {}).values,
      ...(locationReminders[uid] ?? {}).values,
    ]) {
      if (isNew(doc)) track(doc);
    }
    return RemoteChanges(
      reminders: changedReminders,
      events: changedEvents,
      places: denied.contains(SyncEntity.place) ? const [] : changedPlaces,
      locationReminders: denied.contains(SyncEntity.locationReminder)
          ? const []
          : changedLocation,
      cursor: cursor,
      skipped: denied,
    );
  }

  @override
  Future<void> saveProfile(
    AppUser user, {
    required Map<String, Object?> client,
  }) async {
    _check();
    profiles[user.uid] = user;
  }

  @override
  Future<Map<String, Object?>?> loadSettings(String uid) async {
    _check();
    return settings[uid];
  }

  @override
  Future<void> saveSettings(String uid, Map<String, Object?> values) async {
    _check();
    settings[uid] = Map.of(values);
  }

  @override
  Future<void> deleteAll(String uid) async {
    _check();
    reminders.remove(uid);
    events.remove(uid);
    places.remove(uid);
    locationReminders.remove(uid);
    settings.remove(uid);
    profiles.remove(uid);
  }

  /// Recordatorios vivos (no borrados) de la cuenta.
  int liveReminders(String uid) =>
      (reminders[uid] ?? {}).values.where((d) => d.value != null).length;
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.nextUser});

  /// Cuenta que "elige" el usuario en la ventana de Google.
  AppUser? nextUser;
  AuthErrorCode? failWith;
  bool deleted = false;
  int reauthentications = 0;

  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _current;

  @override
  bool get isAvailable => true;

  @override
  AppUser? get currentUser => _current;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    final code = failWith;
    if (code != null) throw AuthException(code);
    final user = nextUser!;
    _current = user;
    _controller.add(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _controller.add(null);
  }

  @override
  Future<void> reauthenticate() async {
    final code = failWith;
    if (code != null) throw AuthException(code);
    reauthentications++;
  }

  @override
  Future<void> deleteUser() async {
    deleted = true;
    await signOut();
  }
}
