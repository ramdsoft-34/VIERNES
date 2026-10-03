import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viernes/core/database/app_database.dart';
import 'package:viernes/features/sync/data/drift_sync_store.dart';

void main() {
  test(
    'migra de v2 a v3: todo queda pendiente de subir y con sync_id',
    () async {
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw
              ..execute('''
              CREATE TABLE reminders (
                id TEXT NOT NULL PRIMARY KEY, title TEXT NOT NULL,
                notes TEXT, due_at INTEGER NOT NULL,
                lead_time_minutes INTEGER NOT NULL DEFAULT 0,
                recurrence TEXT NOT NULL DEFAULT '', priority TEXT NOT NULL,
                category TEXT NOT NULL, status TEXT NOT NULL,
                snoozed_until INTEGER,
                snooze_count INTEGER NOT NULL DEFAULT 0,
                source TEXT NOT NULL, raw_utterance TEXT,
                nlu_confidence REAL, created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL, completed_at INTEGER)''')
              ..execute('''
              CREATE TABLE reminder_events (
                id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                reminder_id TEXT NOT NULL, reminder_title TEXT NOT NULL,
                type TEXT NOT NULL, occurred_at INTEGER NOT NULL,
                on_time INTEGER)''')
              ..execute('''
              CREATE TABLE nlu_samples (
                id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                utterances TEXT NOT NULL, initial_parse TEXT NOT NULL,
                final_result TEXT NOT NULL, corrected INTEGER NOT NULL,
                confidence REAL NOT NULL, interpreter_version TEXT NOT NULL,
                created_at INTEGER NOT NULL)''')
              ..execute(
                'INSERT INTO reminders VALUES '
                "('r1', 'Pagar', NULL, 1790000000, "
                "0, '', 'normal', 'finance', 'pending', NULL, 0, 'manual', "
                'NULL, NULL, 1780000000, 1780000000, NULL)',
              )
              ..execute(
                'INSERT INTO reminder_events '
                '(reminder_id, reminder_title, type, occurred_at) VALUES '
                "('r1', 'Pagar', 'created', 1780000000), "
                "('r1', 'Pagar', 'snoozed', 1780000100)",
              )
              ..userVersion = 2;
          },
        ),
      );
      addTearDown(db.close);

      final changes = await DriftSyncStore(db).pendingChanges();

      expect(changes.reminders.single.title, 'Pagar');
      expect(changes.events, hasLength(2));
      final ids = changes.events.map((e) => e.syncId).toSet();
      expect(ids, hasLength(2));
      expect(ids, everyElement(isNotNull));
      expect(changes.deletions, isEmpty);
    },
  );

  test(
    'migra de v4 a v5: los lugares quedan por subir y hay adjuntos',
    () async {
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw
              ..execute('''
            CREATE TABLE reminders (
              id TEXT NOT NULL PRIMARY KEY, title TEXT NOT NULL,
              notes TEXT, due_at INTEGER NOT NULL,
              lead_time_minutes INTEGER NOT NULL DEFAULT 0,
              recurrence TEXT NOT NULL DEFAULT '', priority TEXT NOT NULL,
              category TEXT NOT NULL, status TEXT NOT NULL,
              snoozed_until INTEGER,
              snooze_count INTEGER NOT NULL DEFAULT 0,
              source TEXT NOT NULL, raw_utterance TEXT,
              nlu_confidence REAL, created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL, completed_at INTEGER,
              dirty INTEGER NOT NULL DEFAULT 1)''')
              ..execute('''
            CREATE TABLE reminder_events (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              reminder_id TEXT NOT NULL, reminder_title TEXT NOT NULL,
              type TEXT NOT NULL, occurred_at INTEGER NOT NULL,
              on_time INTEGER, sync_id TEXT,
              dirty INTEGER NOT NULL DEFAULT 1)''')
              ..execute('''
            CREATE TABLE nlu_samples (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              utterances TEXT NOT NULL, initial_parse TEXT NOT NULL,
              final_result TEXT NOT NULL, corrected INTEGER NOT NULL,
              confidence REAL NOT NULL, interpreter_version TEXT NOT NULL,
              created_at INTEGER NOT NULL)''')
              ..execute('''
            CREATE TABLE sync_tombstones (
              entity TEXT NOT NULL, entity_id TEXT NOT NULL,
              deleted_at INTEGER NOT NULL,
              PRIMARY KEY (entity, entity_id))''')
              ..execute('''
            CREATE TABLE places (
              id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL,
              latitude REAL NOT NULL, longitude REAL NOT NULL,
              radius_meters REAL NOT NULL DEFAULT 150,
              created_at INTEGER NOT NULL)''')
              ..execute('''
            CREATE TABLE location_reminders (
              id TEXT NOT NULL PRIMARY KEY, title TEXT NOT NULL,
              place_id TEXT NOT NULL,
              on_arrive INTEGER NOT NULL DEFAULT 1,
              done INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL, completed_at INTEGER)''')
              ..execute(
                'INSERT INTO places '
                '(id, name, latitude, longitude, created_at) '
                "VALUES ('casa', 'Casa', 1.2, -77.3, 1780000000)",
              )
              ..execute(
                'INSERT INTO location_reminders '
                '(id, title, place_id, created_at) VALUES '
                "('leche', 'Comprar leche', 'casa', 1780000000)",
              )
              ..userVersion = 4;
          },
        ),
      );
      addTearDown(db.close);

      final changes = await DriftSyncStore(db).pendingChanges();

      expect(changes.places.single.name, 'Casa');
      expect(changes.locationReminders.single.title, 'Comprar leche');
      expect(await db.select(db.attachments).get(), isEmpty);
    },
  );
}
