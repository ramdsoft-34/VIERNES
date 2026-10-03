import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viernes/core/database/app_database.dart';
import 'package:viernes/features/account/application/account_service.dart';
import 'package:viernes/features/account/domain/app_user.dart';
import 'package:viernes/features/account/domain/auth_repository.dart';
import 'package:viernes/features/reminders/data/drift_reminder_repository.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/settings/data/settings_repository.dart';
import 'package:viernes/features/sync/application/sync_engine.dart';
import 'package:viernes/features/sync/data/drift_sync_store.dart';

import '../../helpers/builders.dart';
import '../../helpers/fake_cloud.dart';

void main() {
  // Cada "teléfono" de la prueba tiene su propia base en memoria.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  const ana = AppUser(
    uid: 'ana',
    email: 'ana@example.com',
    displayName: 'Ana María',
  );
  const beto = AppUser(uid: 'beto', email: 'beto@example.com');

  late AppDatabase db;
  late FakeRemoteSyncSource cloud;
  late FakeAuthRepository auth;
  late SharedPreferences prefs;
  late DriftReminderRepository repository;
  late AccountService service;
  late int localChanges;
  late int settingsRestored;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    cloud = FakeRemoteSyncSource();
    auth = FakeAuthRepository(nextUser: ana);
    repository = DriftReminderRepository(db);
    localChanges = 0;
    settingsRestored = 0;
    final store = DriftSyncStore(db);
    service = AccountService(
      auth: auth,
      remote: cloud,
      local: store,
      engine: SyncEngine(
        local: store,
        remote: cloud,
        cursors: SyncCursorStore(prefs),
      ),
      binding: AccountBinding(prefs),
      settings: SettingsRepository(prefs),
      onSettingsRestored: () => settingsRestored++,
      onLocalDataChanged: () async => localChanges++,
      clientInfo: () async => {'platform': 'test'},
      timeout: const Duration(seconds: 2),
    );
  });

  tearDown(() => db.close());

  Future<int> localCount() async =>
      (await repository.watchByStatus(ReminderStatus.values.toSet()).first)
          .length;

  test(
    'al iniciar sesión, lo que había sin cuenta se une a la cuenta',
    () async {
      await repository.save(buildReminder(id: 'local'));

      final result = await service.signInWithGoogle();

      expect(result.user, ana);
      expect(result.mergedLocalData, isTrue);
      expect(result.report, isNotNull);
      expect(cloud.liveReminders('ana'), 1);
      expect(cloud.profiles['ana'], ana);
      expect(AccountBinding(prefs).ownerUid, 'ana');
      expect(localChanges, 1);
    },
  );

  test('recupera los datos de la cuenta en un teléfono nuevo', () async {
    cloud.settings['ana'] = {'snoozeDuration': 30};
    // Datos que otro teléfono ya había subido.
    await cloud.push('ana', await () async {
      final other = AppDatabase(NativeDatabase.memory());
      await DriftReminderRepository(other).save(buildReminder(id: 'nube'));
      final changes = await DriftSyncStore(other).pendingChanges();
      await other.close();
      return changes;
    }());

    final result = await service.signInWithGoogle();

    expect(result.mergedLocalData, isFalse);
    expect(await repository.findById('nube'), isNotNull);
    expect(settingsRestored, 1);
    expect(SettingsRepository(prefs).load().snoozeDuration.inMinutes, 30);
  });

  test('una cuenta nueva recibe las preferencias del teléfono', () async {
    await prefs.setInt('settings.snoozeDuration', 15);
    await prefs.setBool('settings.wakeWordEnabled', true);

    await service.signInWithGoogle();

    expect(cloud.settings['ana']?['snoozeDuration'], 15);
    // Depende del teléfono: no viaja con la cuenta.
    expect(cloud.settings['ana']?.containsKey('wakeWordEnabled'), isFalse);
  });

  test(
    'si los datos son de otra cuenta, se reemplazan por los nuevos',
    () async {
      await service.signInWithGoogle();
      await repository.save(buildReminder(id: 'de-ana'));
      await service.signOut();
      // Simula datos que quedaron de Ana (p. ej. un cierre interrumpido).
      await repository.save(buildReminder(id: 'resto'));
      await AccountBinding(prefs).bind('ana');

      auth.nextUser = beto;
      final result = await service.signInWithGoogle();

      expect(result.mergedLocalData, isFalse);
      expect(await localCount(), 0);
      expect(cloud.liveReminders('beto'), 0);
    },
  );

  test('sin internet inicia sesión igual y sincroniza después', () async {
    cloud.offline = true;

    final result = await service.signInWithGoogle();

    expect(result.report, isNull);
    expect(AccountBinding(prefs).ownerUid, 'ana');
  });

  test('cancelar la ventana de Google no cambia nada', () async {
    auth.failWith = AuthErrorCode.cancelled;

    await expectLater(
      service.signInWithGoogle(),
      throwsA(
        isA<AuthException>().having(
          (e) => e.code,
          'code',
          AuthErrorCode.cancelled,
        ),
      ),
    );
    expect(AccountBinding(prefs).ownerUid, isNull);
  });

  test('cerrar sesión sube lo pendiente y limpia el teléfono', () async {
    await service.signInWithGoogle();
    await repository.save(buildReminder(id: 'nuevo'));

    final result = await service.signOut();

    expect(result, isA<SignedOut>());
    expect(cloud.liveReminders('ana'), 1);
    expect(await localCount(), 0);
    expect(AccountBinding(prefs).ownerUid, isNull);
    expect(auth.currentUser, isNull);
  });

  test('sin internet, cerrar sesión avisa antes de perder cambios', () async {
    await service.signInWithGoogle();
    await repository.save(buildReminder(id: 'nuevo'));
    cloud.offline = true;

    final blocked = await service.signOut();
    expect(blocked, isA<SignOutBlocked>());
    expect((blocked as SignOutBlocked).pendingChanges, 1);
    expect(auth.currentUser, isNotNull);

    final forced = await service.signOut(force: true);
    expect(forced, isA<SignedOut>());
    expect(await localCount(), 0);
  });

  test('al volver a iniciar sesión se recupera todo', () async {
    await service.signInWithGoogle();
    await repository.save(buildReminder(id: 'guardado'));
    await service.signOut();
    expect(await localCount(), 0);

    await service.signInWithGoogle();

    expect(await repository.findById('guardado'), isNotNull);
  });

  test('eliminar la cuenta confirma identidad y borra todo', () async {
    await service.signInWithGoogle();
    await repository.save(buildReminder(id: 'x'));
    await service.signOut(); // sube
    await service.signInWithGoogle();

    await service.deleteAccount();

    expect(auth.reauthentications, 1);
    expect(auth.deleted, isTrue);
    expect(cloud.liveReminders('ana'), 0);
    expect(await localCount(), 0);
  });

  test('si no confirma su identidad, no se borra nada', () async {
    await service.signInWithGoogle();
    await repository.save(buildReminder(id: 'x'));
    await service.signOut();
    await service.signInWithGoogle();
    auth.failWith = AuthErrorCode.cancelled;

    await expectLater(service.deleteAccount(), throwsA(isA<AuthException>()));

    expect(cloud.liveReminders('ana'), 1);
    expect(auth.deleted, isFalse);
  });
}
