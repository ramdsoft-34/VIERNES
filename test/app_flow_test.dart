import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viernes/app/app.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/core/utils/clock.dart';
import 'package:viernes/features/attachments/presentation/attachment_providers.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/presentation/providers/reminder_providers.dart';

import 'helpers/builders.dart';
import 'helpers/fake_reminder_repository.dart';

void main() {
  late FakeReminderRepository repository;
  final now = DateTime(2026, 10, 1, 10);

  setUpAll(() => initializeDateFormatting('es'));

  Future<void> pumpApp(WidgetTester tester) async {
    // El fondo de luz se anima sin fin; en pruebas va quieto.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repository = FakeReminderRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          reminderRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(FixedClock(now)),
          idGeneratorProvider.overrideWithValue(SequentialIds()),
          nowProvider.overrideWith((ref) => Stream.value(now)),
          remindersWithAttachmentsProvider.overrideWith(
            (ref) => Stream.value(const <String>{}),
          ),
        ],
        child: const ViernesApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Inicio muestra el saludo y el estado vacío', (tester) async {
    await pumpApp(tester);

    expect(find.text('Buenos días'), findsOneWidget);
    expect(find.text('No tienes pendientes para hoy'), findsOneWidget);
    expect(find.text('Todo en orden'), findsOneWidget);
  });

  testWidgets('crear un recordatorio a mano y completarlo', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Nuevo recordatorio'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo recordatorio'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Llamar a mamá');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // De vuelta en Inicio, con el recordatorio para hoy a las 11:00 (en la
    // cuenta regresiva y en el río).
    expect(find.text('Llamar a mamá'), findsWidgets);
    expect(find.text('Hoy tienes 1 pendiente'), findsOneWidget);
    final saved = repository.reminders.values.single;
    expect(saved.dueAt, DateTime(2026, 10, 1, 11));
    expect(saved.leadTime, const Duration(minutes: 15));

    await tester.tap(find.byTooltip('Ya lo hice'));
    await tester.pumpAndSettle();

    expect(find.text('¡Bien hecho! Tarea completada'), findsOneWidget);
    expect(repository.reminders.values.single.status, ReminderStatus.completed);
    expect(find.text('Llamar a mamá'), findsNothing);
  });

  testWidgets('el editor no guarda sin título', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Nuevo recordatorio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Escribe qué necesitas recordar'), findsOneWidget);
    expect(repository.reminders, isEmpty);
  });

  testWidgets('los vencidos aparecen destacados en Inicio', (tester) async {
    await pumpApp(tester);
    await repository.save(
      buildReminder(title: 'Pagar el arriendo', dueAt: DateTime(2026, 10)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vencidos sin confirmar'), findsOneWidget);
    expect(find.text('Vencido'), findsOneWidget);
  });

  testWidgets('navega por las pestañas principales', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Pendientes').last);
    await tester.pumpAndSettle();
    expect(find.text('Sin pendientes'), findsOneWidget);

    await tester.tap(find.byTooltip('Calendario').last);
    await tester.pumpAndSettle();
    expect(find.text('No hay recordatorios este día'), findsOneWidget);

    await tester.tap(find.byTooltip('Progreso').last);
    await tester.pumpAndSettle();
    expect(find.text('Tu historial está vacío'), findsOneWidget);
  });
}
