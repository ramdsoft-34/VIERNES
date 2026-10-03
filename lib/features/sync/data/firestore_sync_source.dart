import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viernes/features/account/domain/app_user.dart';
import 'package:viernes/features/places/domain/place.dart';
import 'package:viernes/features/sync/data/cloud_codec.dart';
import 'package:viernes/features/sync/domain/remote_sync_source.dart';
import 'package:viernes/features/sync/domain/sync_records.dart';

/// Datos de cada cuenta en Cloud Firestore:
///
/// ```text
/// users/{uid}                    perfil + preferencias
/// users/{uid}/reminders/{id}     recordatorios
/// users/{uid}/events/{syncId}    historial
/// users/{uid}/places/{id}        lugares guardados
/// users/{uid}/location_reminders/{id}  recordatorios por ubicación
/// ```
///
/// Los borrados se guardan como `deleted: true` para que los demás teléfonos
/// se enteren. Las reglas de seguridad (`firebase/firestore.rules`) solo dejan
/// a cada usuario leer y escribir lo suyo.
class FirestoreSyncSource implements RemoteSyncSource {
  FirestoreSyncSource(this._firestore);

  final FirebaseFirestore _firestore;

  /// Firestore admite hasta 500 escrituras por lote.
  static const _batchSize = 400;

  /// Margen al descargar por si los relojes del servidor se cruzan; lo
  /// repetido no se reaplica.
  static const _overlap = Duration(minutes: 2);

  static const _serverUpdatedAt = 'serverUpdatedAt';

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _firestore.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _reminders(String uid) =>
      _user(uid).collection('reminders');

  CollectionReference<Map<String, dynamic>> _events(String uid) =>
      _user(uid).collection('events');

  CollectionReference<Map<String, dynamic>> _places(String uid) =>
      _user(uid).collection('places');

  CollectionReference<Map<String, dynamic>> _locationReminders(String uid) =>
      _user(uid).collection('location_reminders');

  @override
  Future<void> push(String uid, LocalChanges changes) async {
    final writes = <void Function(WriteBatch)>[
      for (final reminder in changes.reminders)
        (batch) => batch.set(_reminders(uid).doc(reminder.id), {
          ...CloudCodec.encodeReminder(reminder),
          _serverUpdatedAt: FieldValue.serverTimestamp(),
        }),
      for (final event in changes.events)
        (batch) => batch.set(_events(uid).doc(event.syncId), {
          ...CloudCodec.encodeEvent(event),
          _serverUpdatedAt: FieldValue.serverTimestamp(),
        }),
      for (final place in changes.places)
        (batch) => batch.set(_places(uid).doc(place.id), {
          ...CloudCodec.encodePlace(place),
          _serverUpdatedAt: FieldValue.serverTimestamp(),
        }),
      for (final reminder in changes.locationReminders)
        (batch) => batch.set(_locationReminders(uid).doc(reminder.id), {
          ...CloudCodec.encodeLocationReminder(reminder),
          _serverUpdatedAt: FieldValue.serverTimestamp(),
        }),
      for (final deletion in changes.deletions)
        (batch) => batch.set(
          switch (deletion.entity) {
            SyncEntity.reminder => _reminders(uid).doc(deletion.entityId),
            SyncEntity.event => _events(uid).doc(deletion.entityId),
            SyncEntity.place => _places(uid).doc(deletion.entityId),
            SyncEntity.locationReminder => _locationReminders(
              uid,
            ).doc(deletion.entityId),
          },
          {
            'v': CloudCodec.formatVersion,
            'deleted': true,
            'updatedAt': deletion.deletedAt,
            _serverUpdatedAt: FieldValue.serverTimestamp(),
          },
        ),
    ];
    for (var i = 0; i < writes.length; i += _batchSize) {
      final batch = _firestore.batch();
      for (final write in writes.skip(i).take(_batchSize)) {
        write(batch);
      }
      await batch.commit();
    }
  }

  @override
  Future<RemoteChanges> pull(String uid, {DateTime? since}) async {
    Query<Map<String, dynamic>> changedSince(
      CollectionReference<Map<String, dynamic>> collection,
    ) => since == null
        ? collection
        : collection.where(
            _serverUpdatedAt,
            isGreaterThan: Timestamp.fromDate(since.subtract(_overlap)),
          );

    const server = GetOptions(source: Source.server);
    final reminderDocs = await changedSince(_reminders(uid)).get(server);
    final eventDocs = await changedSince(_events(uid)).get(server);
    final placeDocs = await changedSince(_places(uid)).get(server);
    final locationDocs = await changedSince(
      _locationReminders(uid),
    ).get(server);

    DateTime? cursor;
    void track(Map<String, dynamic> data) {
      final at = (data[_serverUpdatedAt] as Timestamp?)?.toDate();
      if (at != null && (cursor == null || at.isAfter(cursor!))) cursor = at;
    }

    final reminders = <RemoteReminder>[];
    for (final doc in reminderDocs.docs) {
      final data = doc.data();
      track(data);
      final deleted = data['deleted'] == true;
      reminders.add(
        RemoteReminder(
          id: doc.id,
          updatedAt: CloudCodec.readDate(data['updatedAt']) ?? DateTime(1970),
          reminder: deleted ? null : CloudCodec.decodeReminder(doc.id, data),
        ),
      );
    }
    final events = <RemoteEvent>[];
    for (final doc in eventDocs.docs) {
      final data = doc.data();
      track(data);
      events.add(
        RemoteEvent(
          syncId: doc.id,
          event: data['deleted'] == true
              ? null
              : CloudCodec.decodeEvent(doc.id, data),
        ),
      );
    }
    final places = <RemoteItem<Place>>[
      for (final doc in placeDocs.docs)
        _item(doc, track, CloudCodec.decodePlace),
    ];
    final locationReminders = <RemoteItem<LocationReminder>>[
      for (final doc in locationDocs.docs)
        _item(doc, track, CloudCodec.decodeLocationReminder),
    ];
    return RemoteChanges(
      reminders: reminders,
      events: events,
      places: places,
      locationReminders: locationReminders,
      cursor: cursor ?? since,
    );
  }

  static RemoteItem<T> _item<T>(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    void Function(Map<String, dynamic>) track,
    T Function(String id, Map<String, Object?> data) decode,
  ) {
    final data = doc.data();
    track(data);
    return RemoteItem<T>(
      id: doc.id,
      updatedAt: CloudCodec.readDate(data['updatedAt']) ?? DateTime(1970),
      value: data['deleted'] == true ? null : decode(doc.id, data),
    );
  }

  @override
  Future<void> saveProfile(
    AppUser user, {
    required Map<String, Object?> client,
  }) => _user(user.uid).set({
    'email': user.email,
    'displayName': user.displayName,
    'photoUrl': user.photoUrl,
    'lastSignInAt': FieldValue.serverTimestamp(),
    'client': client,
  }, SetOptions(merge: true));

  @override
  Future<Map<String, Object?>?> loadSettings(String uid) async {
    final doc = await _user(
      uid,
    ).get(const GetOptions(source: Source.server));
    final settings = doc.data()?['settings'];
    return settings is Map ? Map<String, Object?>.from(settings) : null;
  }

  @override
  Future<void> saveSettings(String uid, Map<String, Object?> settings) =>
      _user(uid).set({
        'settings': settings,
        'settingsUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  @override
  Future<void> deleteAll(String uid) async {
    for (final collection in [
      _reminders(uid),
      _events(uid),
      _places(uid),
      _locationReminders(uid),
    ]) {
      while (true) {
        final page = await collection.limit(_batchSize).get();
        if (page.docs.isEmpty) break;
        final batch = _firestore.batch();
        for (final doc in page.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }
    await _user(uid).delete();
  }
}
