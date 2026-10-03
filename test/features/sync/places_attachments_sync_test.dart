import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viernes/core/database/app_database.dart';
import 'package:viernes/features/attachments/application/attachment_sync.dart';
import 'package:viernes/features/attachments/data/attachments_repository.dart';
import 'package:viernes/features/attachments/domain/attachment.dart';
import 'package:viernes/features/places/data/places_repository.dart';
import 'package:viernes/features/places/domain/place.dart';
import 'package:viernes/features/reminders/data/drift_reminder_repository.dart';
import 'package:viernes/features/sync/application/sync_engine.dart';
import 'package:viernes/features/sync/data/drift_sync_store.dart';

import '../../helpers/builders.dart';
import '../../helpers/fake_cloud.dart';
import 'sync_engine_test.dart' show MemoryCursorStore;

/// Nube de adjuntos en memoria (datos + archivos).
class FakeAttachmentRemote implements AttachmentRemote {
  final meta = <String, Map<String, Attachment?>>{};
  final files = <String, List<int>>{};
  final serverAt = <String, DateTime>{};
  var _clock = DateTime(2026);
  bool offline = false;

  DateTime _tick() => _clock = _clock.add(const Duration(seconds: 1));

  void _check() {
    if (offline) throw const SocketException('sin internet');
  }

  @override
  Future<String> upload(String uid, Attachment a, File file) async {
    _check();
    final path = 'users/$uid/attachments/${a.id}.${a.extension}';
    files[path] = await file.readAsBytes();
    return path;
  }

  @override
  Future<void> saveMeta(String uid, Attachment a) async {
    _check();
    (meta[uid] ??= {})[a.id] = a.copyWith();
    serverAt['$uid/${a.id}'] = _tick();
  }

  @override
  Future<void> delete(String uid, String id) async {
    _check();
    final old = meta[uid]?[id];
    if (old?.remotePath != null) files.remove(old!.remotePath);
    (meta[uid] ??= {})[id] = null;
    serverAt['$uid/$id'] = _tick();
  }

  @override
  Future<RemoteAttachments> pull(String uid, {DateTime? since}) async {
    _check();
    var cursor = since;
    final items = <RemoteAttachment>[];
    for (final MapEntry(:key, :value) in (meta[uid] ?? {}).entries) {
      final at = serverAt['$uid/$key']!;
      if (since != null && !at.isAfter(since)) continue;
      if (cursor == null || at.isAfter(cursor)) cursor = at;
      items.add(
        RemoteAttachment(
          id: key,
          attachment: value == null
              ? null
              : Attachment(
                  id: value.id,
                  reminderId: value.reminderId,
                  kind: value.kind,
                  remotePath: value.remotePath,
                  duration: value.duration,
                  createdAt: value.createdAt,
                ),
        ),
      );
    }
    return RemoteAttachments(items, cursor);
  }

  @override
  Future<void> download(String remotePath, File target) async {
    _check();
    await target.parent.create(recursive: true);
    await target.writeAsBytes(files[remotePath]!);
  }
}

class Phone {
  Phone(this.name, FakeRemoteSyncSource cloud, this.attachmentsCloud)
    : db = AppDatabase(NativeDatabase.memory()) {
    places = PlacesRepository(db, now: () => clock);
    attachments = AttachmentsRepository(db, now: () => clock);
    engine = SyncEngine(
      local: DriftSyncStore(db),
      remote: cloud,
      cursors: MemoryCursorStore(),
    );
  }

  final String name;
  final AppDatabase db;
  final FakeAttachmentRemote attachmentsCloud;
  late final PlacesRepository places;
  late final AttachmentsRepository attachments;
  late final SyncEngine engine;
  late AttachmentSync attachmentSync;
  DateTime clock = DateTime(2026, 10, 3, 10);

  Future<void> setUp(Directory dir) async {
    SharedPreferences.setMockInitialValues({});
    attachmentSync = AttachmentSync(
      local: attachments,
      remote: attachmentsCloud,
      prefs: await SharedPreferences.getInstance(),
      localFile: (a) async => File('${dir.path}/$name-${a.id}.${a.extension}'),
    );
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  const uid = 'ana';
  late FakeRemoteSyncSource cloud;
  late FakeAttachmentRemote attachmentsCloud;
  late Phone phone;
  late Phone tablet;
  late Directory dir;

  setUp(() async {
    cloud = FakeRemoteSyncSource();
    attachmentsCloud = FakeAttachmentRemote();
    dir = await Directory.systemTemp.createTemp('viernes_test');
    phone = Phone('phone', cloud, attachmentsCloud);
    tablet = Phone('tablet', cloud, attachmentsCloud);
    await phone.setUp(dir);
    await tablet.setUp(dir);
  });

  tearDown(() async {
    await phone.db.close();
    await tablet.db.close();
    await dir.delete(recursive: true);
  });

  Place casa({String name = 'Casa'}) => Place(
    id: 'casa',
    name: name,
    latitude: 1.2,
    longitude: -77.3,
    createdAt: DateTime(2026, 10),
  );

  group('lugares', () {
    test('un lugar y su recordatorio llegan al otro teléfono', () async {
      await phone.places.savePlace(casa());
      await phone.places.saveReminder(
        LocationReminder(
          id: 'leche',
          title: 'Comprar leche',
          placeId: 'casa',
          createdAt: DateTime(2026, 10, 3),
        ),
      );

      await phone.engine.sync(uid);
      final report = await tablet.engine.sync(uid);

      expect(report.downloaded, 2);
      expect((await tablet.places.places()).single.name, 'Casa');
      final reminder = (await tablet.places.activeReminders()).single;
      expect(reminder.title, 'Comprar leche');
      expect(reminder.onArrive, isTrue);
      // Lo que llegó de la nube no queda pendiente de subir.
      expect(await DriftSyncStore(tablet.db).pendingCount(), 0);
    });

    test('marcar hecho y borrar se propagan', () async {
      await phone.places.savePlace(casa());
      await phone.places.saveReminder(
        LocationReminder(
          id: 'leche',
          title: 'Comprar leche',
          placeId: 'casa',
          createdAt: DateTime(2026, 10, 3),
        ),
      );
      await phone.engine.sync(uid);
      await tablet.engine.sync(uid);

      tablet.clock = DateTime(2026, 10, 3, 12);
      await tablet.places.setDone('leche', done: true, at: tablet.clock);
      await tablet.engine.sync(uid);
      await phone.engine.sync(uid);
      expect((await phone.places.findReminder('leche'))!.done, isTrue);

      phone.clock = DateTime(2026, 10, 3, 13);
      await phone.places.deletePlace('casa');
      await phone.engine.sync(uid);
      await tablet.engine.sync(uid);
      expect(await tablet.places.places(), isEmpty);
      expect(await tablet.places.findReminder('leche'), isNull);
    });

    test('gana el cambio más reciente', () async {
      await phone.places.savePlace(casa());
      await phone.engine.sync(uid);
      await tablet.engine.sync(uid);

      phone.clock = DateTime(2026, 10, 3, 11);
      await phone.places.savePlace(casa(name: 'Mi casa'));
      tablet.clock = DateTime(2026, 10, 3, 12);
      await tablet.places.savePlace(casa(name: 'Hogar'));

      await phone.engine.sync(uid);
      await tablet.engine.sync(uid);
      await phone.engine.sync(uid);

      expect((await phone.places.places()).single.name, 'Hogar');
      expect((await tablet.places.places()).single.name, 'Hogar');
    });
  });

  group('adjuntos', () {
    Future<Attachment> photo(Phone p) async {
      final file = File('${dir.path}/original.jpg');
      await file.writeAsBytes([1, 2, 3, 4]);
      final a = Attachment(
        id: 'foto1',
        reminderId: 'r1',
        kind: AttachmentKind.photo,
        localPath: file.path,
        createdAt: DateTime(2026, 10, 3),
      );
      await p.attachments.add(a);
      return a;
    }

    test('la foto sube y se descarga en el otro teléfono', () async {
      await photo(phone);

      await phone.attachmentSync.sync(uid);
      await tablet.attachmentSync.sync(uid);

      final remote = attachmentsCloud.files.values.single;
      expect(remote, [1, 2, 3, 4]);
      final onTablet = (await tablet.attachments.forReminder('r1')).single;
      expect(onTablet.remotePath, 'users/ana/attachments/foto1.jpg');
      expect(await File(onTablet.localPath!).readAsBytes(), [1, 2, 3, 4]);
      expect(await phone.attachments.pendingUpload(), isEmpty);
    });

    test('borrar en un teléfono lo borra en la nube y en el otro', () async {
      final a = await photo(phone);
      await phone.attachmentSync.sync(uid);
      await tablet.attachmentSync.sync(uid);

      await phone.attachments.delete(
        (await phone.attachments.find(a.id))!,
      );
      await phone.attachmentSync.sync(uid);
      await tablet.attachmentSync.sync(uid);

      expect(attachmentsCloud.files, isEmpty);
      expect(await tablet.attachments.forReminder('r1'), isEmpty);
    });

    test('sin internet queda pendiente y se sube después', () async {
      await photo(phone);
      attachmentsCloud.offline = true;
      await expectLater(phone.attachmentSync.sync(uid), throwsA(anything));
      expect(await phone.attachments.pendingUpload(), hasLength(1));

      attachmentsCloud.offline = false;
      await phone.attachmentSync.sync(uid);
      expect(await phone.attachments.pendingUpload(), isEmpty);
    });

    test('los adjuntos de recordatorios borrados se limpian', () async {
      final reminders = DriftReminderRepository(phone.db);
      await reminders.save(buildReminder(id: 'vive'));
      await photo(phone);
      await phone.attachments.add(
        Attachment(
          id: 'foto2',
          reminderId: 'vive',
          kind: AttachmentKind.photo,
          createdAt: DateTime(2026, 10, 3),
        ),
      );

      final removed = await phone.attachments.removeOrphans();

      expect(removed, 1);
      expect(await phone.attachments.forReminder('r1'), isEmpty);
      expect(await phone.attachments.forReminder('vive'), hasLength(1));
      // El borrado queda para avisar a la nube.
      expect(await phone.attachments.pendingDeletions(), ['foto1']);
    });
  });
}
