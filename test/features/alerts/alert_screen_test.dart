import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viernes/ai/ai_providers.dart';
import 'package:viernes/ai/learning/snooze_habits.dart';
import 'package:viernes/ai/speech/speech_recognizer.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/core/utils/clock.dart';
import 'package:viernes/features/alerts/presentation/alert_screen.dart';
import 'package:viernes/features/attachments/domain/attachment.dart';
import 'package:viernes/features/attachments/presentation/attachment_providers.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/presentation/providers/reminder_providers.dart';
import 'package:viernes/l10n/gen/app_localizations.dart';

import '../../helpers/builders.dart';
import '../../helpers/fake_reminder_repository.dart';
import '../../helpers/fake_speech.dart';

void main() {
  final now = DateTime(2026, 10, 1, 8);
  late FakeReminderRepository repository;
  late FakeSpeechRecognizer recognizer;
  late FakeSpeaker speaker;
  late SharedPreferences prefs;

  setUpAll(() => initializeDateFormatting('es'));

  Future<void> pumpAlert(WidgetTester tester) async {
    // El fondo de luz se anima sin fin; en pruebas va quieto.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = FakeReminderRepository();
    await repository.save(
      buildReminder(
        dueAt: DateTime(2026, 10, 1, 8, 30),
      ),
    );
    final router = GoRouter(
      initialLocation: '/alerta',
      routes: [
        GoRoute(path: '/inicio', builder: (_, _) => const Text('INICIO')),
        GoRoute(
          path: '/alerta',
          builder: (_, _) => const AlertScreen(reminderId: 'r1'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          reminderRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(FixedClock(now)),
          nowProvider.overrideWith((ref) => Stream.value(now)),
          speechRecognizerProvider.overrideWithValue(recognizer),
          speakerProvider.overrideWithValue(speaker),
          attachmentsProvider.overrideWith(
            (ref, id) => Stream.value(const <Attachment>[]),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('es'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  setUp(() {
    recognizer = FakeSpeechRecognizer();
    speaker = FakeSpeaker();
  });

  testWidgets('muestra la tarea y la lee en voz alta', (tester) async {
    await pumpAlert(tester);

    expect(find.text('Entregar el informe'), findsOneWidget);
    expect(find.textContaining('Hoy'), findsOneWidget);
    expect(
      speaker.spoken.single,
      'Recordatorio: Entregar el informe. ¿Ya lo hiciste?',
    );
  });

  testWidgets('"Ya lo hice" completa y cierra la alerta', (tester) async {
    await pumpAlert(tester);

    // Completar es un gesto: deslizar la perilla hasta el final.
    await tester.drag(find.byIcon(Icons.arrow_forward), const Offset(600, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('¡Bien hecho! Tarea completada'), findsOneWidget);
    expect(repository.reminders['r1']!.status, ReminderStatus.completed);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('INICIO'), findsOneWidget);
  });

  testWidgets('"Posponer" usa el tiempo de siempre', (tester) async {
    await pumpAlert(tester);

    await tester.tap(find.byTooltip('Posponer 10 min'));
    await tester.pump(const Duration(milliseconds: 400));

    final reminder = repository.reminders['r1']!;
    expect(reminder.status, ReminderStatus.snoozed);
    expect(reminder.snoozedUntil, DateTime(2026, 10, 1, 8, 10));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('"Otro tiempo" deja elegir cuándo y lo aprende', (tester) async {
    await pumpAlert(tester);

    await tester.tap(find.byTooltip('Otro tiempo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.ensureVisible(find.text('En 30 min'));
    await tester.pump();
    await tester.tap(find.text('En 30 min'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    final reminder = repository.reminders['r1']!;
    expect(reminder.status, ReminderStatus.snoozed);
    expect(reminder.snoozedUntil, DateTime(2026, 10, 1, 8, 30));
    expect(SnoozeHabits(prefs).choices(), [const Duration(minutes: 30)]);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('responder "todavía no, en 20 minutos" por voz', (tester) async {
    recognizer = FakeSpeechRecognizer(
      script: const [SpeechHeard('todavía no, en 20 minutos')],
    );
    await pumpAlert(tester);

    await tester.tap(find.byTooltip('Responder por voz'));
    await tester.pump();
    await tester.pump();

    expect(
      repository.reminders['r1']!.snoozedUntil,
      DateTime(2026, 10, 1, 8, 20),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('responder "sí, ya lo hice" por voz', (tester) async {
    recognizer = FakeSpeechRecognizer(
      script: const [SpeechHeard('sí, ya lo hice')],
    );
    await pumpAlert(tester);

    await tester.tap(find.byTooltip('Responder por voz'));
    await tester.pump();
    await tester.pump();

    expect(repository.reminders['r1']!.status, ReminderStatus.completed);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 500));
  });
}
