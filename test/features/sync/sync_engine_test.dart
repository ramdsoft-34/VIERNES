import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viernes/core/database/app_database.dart';
import 'package:viernes/features/reminders/data/drift_reminder_repository.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_event.dart';
import 'package:viernes/features/sync/application/sync_engine.dart';
import 'package:viernes/features/sync/data/drift_sync_store.dart';

import '../../helpers/builders.dart';
import '../../helpers/fake_cloud.dart';

class MemoryCursorStore implements SyncCursorStore {
  final _cursors = <String, DateTime>{};

  @override
  DateTime? read(String uid) => _cursors[uid];

  @override
  Future<void> write(String uid, DateTime cursor) async =>
      _cursors[uid] = cursor;

  @override
  Future<void> clear(String uid) async => _cursors.remove(uid);
}

/// Un teléfono con su propia base local.
class Device {
  Device(FakeRemoteSyncSource cloud)
    : db = AppDatabase(NativeDatabase.memory()) {
    repository = DriftReminderRepository(db);
    store = DriftSyncStore(db);
    engine = SyncEngine(
      local: store,
      remote: cloud,
      cursors: MemoryCursorStore(),
    );
  }

  final AppDatabase db;
  late final DriftReminderRepository repository;
  late final DriftSyncStore store;
  late final SyncEngine engine;

  Future<List<Reminder>> all() =>
      repository.watchByStatus(ReminderStatus.values.toSet()).first;

  Future<List<ReminderEvent>> events() => repository.watchEvents().first;
}

void main() {
  // Cada "teléfono" de la prueba tiene su propia base en memoria.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  const uid = 'ana';
  late FakeRemoteSyncSource cloud;
  late Device phone;
  late Device tablet;

  setUp(() {
    cloud = FakeRemoteSyncSource();
    phone = Device(cloud);
    tablet = Device(cloud);
  });

  tearDown(() async {
    await phone.db.close();
    await tablet.db.close();
  });

  ReminderEvent created(String id, String title) => ReminderEvent(
    reminderId: id,
    reminderTitle: title,
    type: ReminderEventType.created,
    occurredAt: DateTime(2026, 10, 1, 9),
  );

  test('cada cambio local queda pendiente hasta subirlo', () async {
    await phone.repository.save(
      buildReminder(),
      event: created('r1', 'Entregar el informe'),
    );
    expect(await phone.store.pendingCount(), 2);

    final report = await phone.engine.sync(uid);

    expect(report.uploaded, 2);
    expect(await phone.store.pendingCount(), 0);
    expect(cloud.liveReminders(uid), 1);
  });

  test(
    'lo creado en un teléfono aparece en el otro con su historial',
    () async {
      await phone.repository.save(
        buildReminder(title: 'Llamar a Juan'),
        event: created('r1', 'Llamar a Juan'),
      );
      await phone.engine.sync(uid);

      final report = await tablet.engine.sync(uid);

      expect(report.downloaded, 2);
      expect((await tablet.all()).single.title, 'Llamar a Juan');
      expect((await tablet.events()).single.reminderTitle, 'Llamar a Juan');
      // Lo bajado no vuelve a subirse.
      expect(await tablet.store.pendingCount(), 0);
    },
  );

  test('sincronizar dos veces no reaplica ni duplica nada', () async {
    await phone.repository.save(buildReminder(), event: created('r1', 'x'));
    await phone.engine.sync(uid);
    await tablet.engine.sync(uid);

    final again = await tablet.engine.sync(uid);

    expect(again.downloaded, 0);
    expect(await tablet.events(), hasLength(1));
  });

  test('un borrado llega a los demás teléfonos', () async {
    await phone.repository.save(buildReminder());
    await phone.engine.sync(uid);
    await tablet.engine.sync(uid);

    await tablet.repository.delete('r1');
    await tablet.engine.sync(uid);
    await phone.engine.sync(uid);

    expect(await phone.all(), isEmpty);
    expect(await tablet.store.pendingCount(), 0);
  });

  test('deshacer una acción quita su evento también en la nube', () async {
    final reminder = buildReminder();
    await phone.repository.save(reminder);
    final done = reminder.copyWith(
      status: ReminderStatus.completed,
      updatedAt: DateTime(2026, 10, 1, 10),
    );
    await phone.repository.save(
      done,
      event: ReminderEvent(
        reminderId: 'r1',
        reminderTitle: reminder.title,
        type: ReminderEventType.completed,
        occurredAt: DateTime(2026, 10, 1, 10),
      ),
    );
    await phone.engine.sync(uid);
    await tablet.engine.sync(uid);
    expect(await tablet.events(), hasLength(1));

    await phone.repository.revert(
      reminder,
      undoneEvent: ReminderEventType.completed,
    );
    await phone.engine.sync(uid);
    await tablet.engine.sync(uid);

    expect(await tablet.events(), isEmpty);
    // La nube manda sobre lo que no se tocó en la tableta, aunque la versión
    // restaurada tenga una fecha anterior.
    expect((await tablet.all()).single.status, ReminderStatus.pending);
  });

  test('en un conflicto gana el cambio más reciente', () async {
    await phone.repository.save(buildReminder());
    await phone.engine.sync(uid);
    await tablet.engine.sync(uid);

    final base = (await tablet.all()).single;
    await phone.repository.save(
      base.copyWith(
        title: 'Del teléfono',
        updatedAt: DateTime(2026, 10, 1, 11),
      ),
    );
    await tablet.repository.save(
      base.copyWith(
        title: 'De la tableta',
        updatedAt: DateTime(2026, 10, 1, 12),
      ),
    );

    await phone.engine.sync(uid);
    await tablet.engine.sync(uid);
    await phone.engine.sync(uid);

    expect((await phone.all()).single.title, 'De la tableta');
    expect((await tablet.all()).single.title, 'De la tableta');
  });

  test('un borrado local pendiente no se pierde al bajar cambios', () async {
    await phone.repository.save(buildReminder());
    await phone.engine.sync(uid);
    await tablet.engine.sync(uid);

    await tablet.repository.delete('r1');
    // La tableta baja antes de subir su borrado: la versión vieja de la nube
    // no debe revivir el recordatorio.
    await tablet.store.applyRemote(
      await cloud.pull(uid),
    );

    expect(await tablet.all(), isEmpty);
    await tablet.engine.sync(uid);
    expect(cloud.liveReminders(uid), 0);
  });

  test(
    'restaurar tras borrar (deshacer) cancela el borrado pendiente',
    () async {
      final reminder = buildReminder();
      await phone.repository.save(reminder);
      await phone.repository.delete('r1');
      await phone.repository.save(reminder);

      await phone.engine.sync(uid);

      expect(cloud.liveReminders(uid), 1);
    },
  );

  test('sin internet los cambios quedan pendientes', () async {
    await phone.repository.save(buildReminder());
    cloud.offline = true;

    await expectLater(phone.engine.sync(uid), throwsA(anything));

    expect(await phone.store.pendingCount(), 1);
    cloud.offline = false;
    await phone.engine.sync(uid);
    expect(await phone.store.pendingCount(), 0);
  });

  test('wipe borra los datos personales del teléfono', () async {
    await phone.repository.save(buildReminder(), event: created('r1', 'x'));

    await phone.store.wipe();

    expect(await phone.store.hasData(), isFalse);
    expect(await phone.store.pendingCount(), 0);
  });
}
