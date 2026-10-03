// Herramienta de pruebas: usa la memoria falsa de SharedPreferences.
// ignore_for_file: invalid_use_of_visible_for_testing_member
// Capturas del diseño para revisarlo sin teléfono:
//   flutter test tool/screenshots/screens_test.dart --update-goldens
// Las imágenes quedan en tool/screenshots/out/.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viernes/app/app.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/app/router/app_router.dart';
import 'package:viernes/app/router/routes.dart';
import 'package:viernes/core/utils/clock.dart';
import 'package:viernes/features/attachments/domain/attachment.dart';
import 'package:viernes/features/attachments/presentation/attachment_providers.dart';
import 'package:viernes/features/reminders/domain/entities/recurrence.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/presentation/providers/reminder_providers.dart';
import 'package:viernes/features/sharing/domain/friend_invite.dart';

import '../../test/helpers/builders.dart';
import '../../test/helpers/fake_reminder_repository.dart';

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File(f).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await load('Geist', [
    'assets/fonts/Geist-Light.ttf',
    'assets/fonts/Geist-Regular.ttf',
    'assets/fonts/Geist-Medium.ttf',
    'assets/fonts/Geist-SemiBold.ttf',
  ]);
  await load('GeistMono', [
    'assets/fonts/GeistMono-Regular.ttf',
    'assets/fonts/GeistMono-Medium.ttf',
  ]);
  final sdk = File(Platform.resolvedExecutable).parent.parent.parent.parent;
  final icons =
      '${sdk.path}/artifacts/material_fonts/materialicons-regular.otf';
  if (File(icons).existsSync()) await load('MaterialIcons', [icons]);
}

void main() {
  final now = DateTime(2026, 10, 3, 9, 41);

  setUpAll(() async {
    await initializeDateFormatting('es');
    await _loadFonts();
  });

  Future<void> shoot(
    WidgetTester tester,
    String name, {
    String location = AppRoutes.home,
    bool light = false,
  }) async {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    SharedPreferences.setMockInitialValues({
      'account.welcomeSeen': true,
      if (light) 'settings.themeMode': 'light',
    });
    final prefs = await SharedPreferences.getInstance();
    final repository = FakeReminderRepository();
    await repository.save(
      buildReminder(
        id: 'a',
        title: 'Pagar la luz antes del corte',
        dueAt: DateTime(2026, 10, 3, 11, 55),
        recurrence: Recurrence.daily.withUntil(DateTime(2026, 10, 30)),
      ),
    );
    await repository.save(
      buildReminder(
        id: 'b',
        title: 'Recoger el paquete',
        dueAt: DateTime(2026, 10, 3, 13),
      ),
    );
    await repository.save(
      buildReminder(
        id: 'c',
        title: 'Llamar a mamá',
        dueAt: DateTime(2026, 10, 3, 18, 30),
        priority: ReminderPriority.high,
      ),
    );
    await repository.save(
      buildReminder(
        id: 'd',
        title: 'Renovar el pasaporte',
        dueAt: DateTime(2026, 10, 2, 9),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          reminderRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(FixedClock(now)),
          nowProvider.overrideWith((ref) => Stream.value(now)),
          remindersWithAttachmentsProvider.overrideWith(
            (ref) => Stream.value({'b'}),
          ),
          attachmentsProvider.overrideWith(
            (ref, id) => Stream.value(const <Attachment>[]),
          ),
          initialLocationProvider.overrideWith(() => _Location(location)),
        ],
        child: const ViernesApp(),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(ViernesApp),
      matchesGoldenFile('out/$name.png'),
    );
  }

  testWidgets('ahora', (t) => shoot(t, '1_ahora'));
  testWidgets('ahora claro', (t) => shoot(t, '1b_ahora_claro', light: true));
  testWidgets(
    'pendientes',
    (t) => shoot(t, '2_pendientes', location: AppRoutes.reminders),
  );
  testWidgets(
    'calendario',
    (t) => shoot(t, '3_calendario', location: AppRoutes.calendar),
  );
  testWidgets(
    'progreso',
    (t) => shoot(t, '4_progreso', location: AppRoutes.history),
  );
  testWidgets(
    'ajustes',
    (t) => shoot(t, '5_ajustes', location: AppRoutes.settings),
  );
  testWidgets(
    'alerta',
    (t) => shoot(t, '6_alerta', location: AppRoutes.alert('a')),
  );
  testWidgets(
    'editor',
    (t) => shoot(t, '7_editor', location: AppRoutes.editReminder('c')),
  );
  testWidgets(
    'voz',
    (t) => shoot(t, '8_voz', location: AppRoutes.voiceEnrollment),
  );
  testWidgets(
    'invitacion',
    (t) => shoot(
      t,
      '9_invitacion',
      location: AppRoutes.friendInvite(
        const FriendInvite(name: 'Sofía', email: 'sofia@gmail.com').code,
      ),
    ),
  );
}

class _Location extends InitialLocation {
  _Location(this._value);

  final String _value;

  @override
  String build() => _value;
}
