import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viernes/ai/ai_providers.dart';
import 'package:viernes/ai/nlu/es/spanish_speech.dart';
import 'package:viernes/ai/speech/speech_recognizer.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/core/database/app_database.dart';
import 'package:viernes/core/platform/device_data.dart';
import 'package:viernes/core/utils/clock.dart';
import 'package:viernes/features/account/domain/app_user.dart';
import 'package:viernes/features/account/presentation/account_providers.dart';
import 'package:viernes/features/device/device_providers.dart';
import 'package:viernes/features/places/data/places_repository.dart';
import 'package:viernes/features/places/domain/place.dart';
import 'package:viernes/features/places/presentation/places_providers.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/presentation/providers/reminder_providers.dart';
import 'package:viernes/features/sharing/domain/sharing_models.dart';
import 'package:viernes/features/sharing/presentation/sharing_providers.dart';
import 'package:viernes/features/voice_assistant/domain/voice_state.dart';
import 'package:viernes/features/voice_assistant/presentation/voice_assistant_controller.dart';

import '../../helpers/builders.dart';
import '../../helpers/fake_cloud.dart';
import '../../helpers/fake_device.dart';
import '../../helpers/fake_location.dart';
import '../../helpers/fake_reminder_repository.dart';
import '../../helpers/fake_sharing.dart';
import '../../helpers/fake_speech.dart';

void main() {
  // Jueves 1 de octubre de 2026, 10:00 a. m.
  final now = DateTime(2026, 10, 1, 10);

  late FakeReminderRepository repository;
  late FakeSpeaker speaker;
  late FakeTrainingDataRepository training;

  Future<ProviderContainer> buildContainer(
    FakeSpeechRecognizer recognizer, {
    Map<String, Object> prefs = const {},
    List<Override> extra = const [],
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final sharedPrefs = await SharedPreferences.getInstance();
    repository = FakeReminderRepository();
    speaker = FakeSpeaker();
    training = FakeTrainingDataRepository();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
        reminderRepositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(FixedClock(now)),
        idGeneratorProvider.overrideWithValue(SequentialIds()),
        speechRecognizerProvider.overrideWithValue(recognizer),
        speakerProvider.overrideWithValue(speaker),
        trainingDataRepositoryProvider.overrideWithValue(training),
        ...extra,
      ],
    );
    addTearDown(container.dispose);
    // Mantiene vivo el provider autoDispose durante la prueba.
    container.listen(voiceAssistantProvider, (_, _) {});
    return container;
  }

  VoiceState stateOf(ProviderContainer c) => c.read(voiceAssistantProvider);

  Future<void> run(ProviderContainer c) =>
      c.read(voiceAssistantProvider.notifier).start();

  test('flujo completo: entiende, confirma y guarda', () async {
    final recognizer = FakeSpeechRecognizer(
      script: const [
        SpeechHeard('mañana antes de las 8 tengo que entregar el informe'),
        SpeechHeard('sí'),
      ],
    );
    final c = await buildContainer(recognizer);

    await run(c);

    final reminder = repository.reminders.values.single;
    expect(reminder.title, 'Entregar el informe');
    expect(reminder.dueAt, DateTime(2026, 10, 2, 8));
    // "Antes de las 8": al menos 30 minutos de margen.
    expect(reminder.leadTime, const Duration(minutes: 30));
    expect(reminder.source, ReminderSource.voice);
    expect(reminder.rawUtterance, contains('entregar el informe'));

    expect(speaker.spoken.first, SpanishSpeech.listening);
    expect(speaker.spoken[1], contains('¿Lo guardo?'));
    expect(
      speaker.spoken.last,
      'Listo. Te lo recuerdo mañana a las 7 y media de la mañana.',
    );
    expect(stateOf(c).stage, VoiceStage.done);
    expect(stateOf(c).saved, isNotNull);
  });

  test('si no oye nada dice "No te escuché" y vuelve a escuchar', () async {
    final recognizer = FakeSpeechRecognizer(
      script: const [
        SpeechSilence(),
        SpeechHeard('a las 3 de la tarde llamar a Juan'),
        SpeechHeard('dale'),
      ],
    );
    final c = await buildContainer(recognizer);

    await run(c);

    expect(speaker.spoken.take(2), [
      SpanishSpeech.listening,
      SpanishSpeech.noSpeech,
    ]);
    expect(repository.reminders.values.single.dueAt, DateTime(2026, 10, 1, 15));
  });

  test('tras varios silencios se rinde sin guardar', () async {
    final recognizer = FakeSpeechRecognizer(
      script: const [SpeechSilence(), SpeechSilence(), SpeechSilence()],
    );
    final c = await buildContainer(recognizer);

    await run(c);

    expect(stateOf(c).stage, VoiceStage.failed);
    expect(stateOf(c).message, SpanishSpeech.gaveUp);
    expect(repository.reminders, isEmpty);
  });

  test('pregunta la hora si falta', () async {
    final recognizer = FakeSpeechRecognizer(
      script: const [
        SpeechHeard('el día 20 tengo una cita'),
        SpeechHeard('a las tres'),
        SpeechHeard('sí'),
      ],
    );
    final c = await buildContainer(recognizer);

    await run(c);

    expect(speaker.spoken, contains(SpanishSpeech.askTime));
    final reminder = repository.reminders.values.single;
    expect(reminder.title, 'Cita');
    expect(reminder.dueAt, DateTime(2026, 10, 20, 15));
  });

  test('pregunta qué recordar si solo se dice el momento', () async {
    final recognizer = FakeSpeechRecognizer(
      script: const [
        SpeechHeard('mañana a las 9'),
        SpeechHeard('pagar el arriendo'),
        SpeechHeard('sí'),
      ],
    );
    final c = await buildContainer(recognizer);

    await run(c);

    expect(speaker.spoken, contains(SpanishSpeech.askTitle));
    final reminder = repository.reminders.values.single;
    expect(reminder.title, 'Pagar el arriendo');
    expect(reminder.category, ReminderCategory.finance);
  });

  test('acepta correcciones antes de guardar', () async {
    final recognizer = FakeSpeechRecognizer(
      script: const [
        SpeechHeard('mañana a las 8 salir a correr'),
        SpeechHeard('no, a las 9'),
        SpeechHeard('sí'),
      ],
    );
    final c = await buildContainer(recognizer);

    await run(c);

    final reminder = repository.reminders.values.single;
    expect(reminder.title, 'Salir a correr');
    expect(reminder.dueAt, DateTime(2026, 10, 2, 9));
  });

  test('"no" pregunta qué cambiar y acepta un título nuevo', () async {
    final recognizer = FakeSpeechRecognizer(
      script: const [
        SpeechHeard('mañana a las 8 llamar a Pedro'),
        SpeechHeard('no'),
        SpeechHeard('llamar a Pablo'),
        SpeechHeard('sí'),
      ],
    );
    final c = await buildContainer(recognizer);

    await run(c);

    expect(speaker.spoken, contains(SpanishSpeech.askWhatToChange));
    expect(repository.reminders.values.single.title, 'Llamar a Pablo');
  });

  test('cancelar por voz no guarda nada', () async {
    final recognizer = FakeSpeechRecognizer(
      script: const [
        SpeechHeard('mañana a las 8 correr'),
        SpeechHeard('cancela'),
      ],
    );
    final c = await buildContainer(recognizer);

    await run(c);

    expect(repository.reminders, isEmpty);
    expect(stateOf(c).message, SpanishSpeech.cancelled);
  });

  test('si se activó por error, «nada» o «me equivoqué» lo cierra', () async {
    for (final phrase in [
      'nada',
      'me equivoqué',
      'Viernes, ya no lo necesito',
    ]) {
      final recognizer = FakeSpeechRecognizer(
        script: [SpeechHeard(phrase)],
      );
      final c = await buildContainer(recognizer);

      await run(c);

      expect(repository.reminders, isEmpty, reason: phrase);
      expect(stateOf(c).message, SpanishSpeech.dismissed, reason: phrase);
    }
  });

  test('«ya no quiero» al preguntar la hora cancela', () async {
    final recognizer = FakeSpeechRecognizer(
      script: const [
        SpeechHeard('mañana llamar a Juan'),
        SpeechHeard('no, ya no quiero, gracias'),
      ],
    );
    final c = await buildContainer(recognizer);

    await run(c);

    expect(repository.reminders, isEmpty);
    expect(stateOf(c).message, SpanishSpeech.cancelled);
  });

  test('«ya no lo necesito» en la confirmación cancela', () async {
    final recognizer = FakeSpeechRecognizer(
      script: const [
        SpeechHeard('mañana a las 8 correr'),
        SpeechHeard('ya no lo necesito'),
      ],
    );
    final c = await buildContainer(recognizer);

    await run(c);

    expect(repository.reminders, isEmpty);
    expect(stateOf(c).message, SpanishSpeech.cancelled);
  });

  test('varias tareas en una frase crean un recordatorio por tarea', () async {
    final recognizer = FakeSpeechRecognizer(
      script: const [
        SpeechHeard(
          'recuérdame mañana a las 8 pagar la luz y llamar a mi mamá',
        ),
        SpeechHeard('sí'),
      ],
    );
    final c = await buildContainer(recognizer);

    await run(c);

    final titles = repository.reminders.values.map((r) => r.title).toSet();
    expect(titles, {'Pagar la luz', 'Llamar a mi mamá'});
    expect(
      repository.reminders.values.map((r) => r.dueAt).toSet(),
      {DateTime(2026, 10, 2, 8)},
    );
    expect(speaker.spoken[1], startsWith('Son 2 recordatorios'));
    expect(speaker.spoken.last, startsWith('Listo. Guardé 2 recordatorios'));
  });

  test('aviso relativo a otro recordatorio de la agenda', () async {
    final recognizer = FakeSpeechRecognizer(
      script: const [
        SpeechHeard('avísame dos días antes del cumpleaños de Sofi'),
        SpeechHeard('sí'),
      ],
    );
    final c = await buildContainer(recognizer);
    await repository.save(
      buildReminder(
        id: 'cumple',
        title: 'Cumpleaños de Sofi',
        dueAt: DateTime(2026, 10, 10, 18),
      ),
    );

    await run(c);

    final created = repository.reminders.values.firstWhere(
      (r) => r.id != 'cumple',
    );
    expect(created.title, 'Se acerca: Cumpleaños de Sofi');
    expect(created.dueAt, DateTime(2026, 10, 8, 18));
  });

  test('recordatorio por ubicación con un lugar guardado', () async {
    final recognizer = FakeSpeechRecognizer(
      script: const [
        SpeechHeard('recuérdame comprar leche cuando llegue a casa'),
        SpeechHeard('sí'),
      ],
    );
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final places = PlacesRepository(db);
    await places.savePlace(
      Place(
        id: 'casa',
        name: 'Casa',
        latitude: 1,
        longitude: 1,
        createdAt: now,
      ),
    );
    final c = await buildContainer(
      recognizer,
      extra: [
        placesRepositoryProvider.overrideWithValue(places),
        locationBridgeProvider.overrideWithValue(FakeLocationBridge()),
      ],
    );

    await run(c);

    final saved = (await places.activeReminders()).single;
    expect(saved.title, 'Comprar leche');
    expect(saved.onArrive, isTrue);
    expect(
      speaker.spoken.last,
      startsWith('Listo, te aviso cuando llegues a Casa'),
    );
    expect(repository.reminders, isEmpty);
  });

  test('si el lugar no existe lo explica', () async {
    final recognizer = FakeSpeechRecognizer(
      script: const [SpeechHeard('comprar pan cuando pase por la panadería')],
    );
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = await buildContainer(
      recognizer,
      extra: [
        placesRepositoryProvider.overrideWithValue(PlacesRepository(db)),
        locationBridgeProvider.overrideWithValue(FakeLocationBridge()),
      ],
    );

    await run(c);

    expect(stateOf(c).message, contains('No tengo guardado'));
  });

  group('compartir', () {
    const ana = AppUser(
      uid: 'ana',
      email: 'ana@gmail.com',
      displayName: 'Ana Pérez',
    );
    late FakeSharingRepository sharing;

    Future<ProviderContainer> sharingContainer(List<String> script) async {
      sharing = FakeSharingRepository();
      final auth = FakeAuthRepository(nextUser: ana);
      await auth.signInWithGoogle();
      return buildContainer(
        FakeSpeechRecognizer(script: [for (final s in script) SpeechHeard(s)]),
        prefs: {
          'settings.contacts': '[{"name":"Sofi","email":"sofi@gmail.com"}]',
        },
        extra: [
          authRepositoryProvider.overrideWithValue(auth),
          sharingRepositoryProvider.overrideWithValue(sharing),
        ],
      );
    }

    test('recuérdale a un contacto envía el recordatorio', () async {
      final c = await sharingContainer([
        'recuérdale a Sofi recoger el paquete mañana a las 5 de la tarde',
        'sí',
      ]);

      await run(c);

      final sent = sharing.shared.values.single;
      expect(sent.toEmail, 'sofi@gmail.com');
      expect(sent.fromName, 'Ana');
      expect(sent.title, 'Recoger el paquete');
      expect(sent.dueAt, DateTime(2026, 10, 2, 17));
      expect(speaker.spoken[1], startsWith('Le envío a Sofi'));
      expect(stateOf(c).message, startsWith('Listo, se lo envié a Sofi'));
      expect(repository.reminders, isEmpty);
    });

    test('agrega elementos a una lista compartida', () async {
      final c = await sharingContainer([
        'agrega leche y pan a la lista del mercado',
      ]);
      await sharing.createList(
        SharedList(
          id: 'm',
          name: 'Mercado',
          ownerUid: 'ana',
          memberEmails: const ['ana@gmail.com'],
          createdAt: now,
        ),
      );

      await run(c);

      expect(
        sharing.items['m']!.values.map((i) => i.text).toSet(),
        {'Leche', 'Pan'},
      );
      expect(stateOf(c).message, contains('a la lista Mercado'));
    });

    Future<void> createMercado() => sharing.createList(
      SharedList(
        id: 'm',
        name: 'Mercado',
        ownerUid: 'ana',
        memberEmails: const ['ana@gmail.com', 'sofi@gmail.com'],
        createdAt: now,
      ),
    );

    test('asigna a un contacto con «para Sofi»', () async {
      final c = await sharingContainer([
        'agrega pagar el internet a la lista del mercado para Sofi',
      ]);
      await createMercado();

      await run(c);

      final item = sharing.items['m']!.values.single;
      expect(item.text, 'Pagar el internet');
      expect(item.assignedTo, 'sofi@gmail.com');
      expect(item.assignedName, 'Sofi');
      expect(stateOf(c).message, endsWith('para Sofi.'));
    });

    test('«¿qué me toca?» lee solo lo asignado a mí', () async {
      final c = await sharingContainer([
        '¿qué me toca en la lista del mercado?',
      ]);
      await createMercado();
      await sharing.addItems('m', [
        SharedListItem(
          id: '1',
          text: 'Comprar pan',
          addedBy: 'Sofi',
          addedAt: now,
          assignedTo: 'ana@gmail.com',
          assignedName: 'Ana',
        ),
        SharedListItem(
          id: '2',
          text: 'Lavar el carro',
          addedBy: 'Ana',
          addedAt: now,
          assignedTo: 'sofi@gmail.com',
          assignedName: 'Sofi',
        ),
      ]);

      await run(c);

      expect(
        stateOf(c).message,
        'En la lista Mercado te toca: comprar pan.',
      );
    });

    test('sin el contacto lo explica', () async {
      final c = await sharingContainer(['recuérdale a Juan llamar al banco']);

      await run(c);

      expect(stateOf(c).message, contains('No tengo a'));
      expect(sharing.shared, isEmpty);
    });
  });

  test('si avisa en el pasado pregunta para cuándo', () async {
    final recognizer = FakeSpeechRecognizer(
      script: const [
        SpeechHeard('hoy a las 9 de la mañana correr'),
        SpeechHeard('mañana'),
        SpeechHeard('sí'),
      ],
    );
    final c = await buildContainer(recognizer);

    await run(c);

    expect(speaker.spoken, contains(SpanishSpeech.pastTime));
    expect(repository.reminders.values.single.dueAt, DateTime(2026, 10, 2, 9));
  });

  test('el botón Guardar confirma mientras escucha', () async {
    final recognizer = FakeSpeechRecognizer(
      script: const [SpeechHeard('mañana a las 8 correr')],
    );
    final c = await buildContainer(recognizer);

    final running = run(c);
    await pumpEventQueue();
    expect(stateOf(c).stage, VoiceStage.confirming);

    c.read(voiceAssistantProvider.notifier).confirmSave();
    await running;

    expect(repository.reminders, hasLength(1));
  });

  test('sin respuesta en la confirmación espera los botones', () async {
    final recognizer = FakeSpeechRecognizer(
      script: const [SpeechHeard('mañana a las 8 correr'), SpeechSilence()],
    );
    final c = await buildContainer(recognizer);

    final running = run(c);
    await pumpEventQueue();
    expect(stateOf(c).stage, VoiceStage.confirming);
    expect(stateOf(c).message, SpanishSpeech.tapToConfirm);

    c.read(voiceAssistantProvider.notifier).confirmSave();
    await running;
    expect(repository.reminders, hasLength(1));
  });

  test('sin confirmación por voz guarda directamente', () async {
    final recognizer = FakeSpeechRecognizer(
      script: const [SpeechHeard('mañana a las 8 correr')],
    );
    final c = await buildContainer(
      recognizer,
      prefs: {'settings.voiceConfirmation': false},
    );

    await run(c);

    expect(repository.reminders, hasLength(1));
    expect(speaker.spoken.any((s) => s.contains('¿Lo guardo?')), isFalse);
  });

  test('responde "¿qué tengo hoy?"', () async {
    final recognizer = FakeSpeechRecognizer(
      script: const [SpeechHeard('¿qué tengo hoy?')],
    );
    final c = await buildContainer(recognizer);
    await repository.save(
      buildReminder(title: 'Reunión', dueAt: DateTime(2026, 10, 1, 14)),
    );
    await repository.save(
      buildReminder(id: 'x', title: 'Otra', dueAt: DateTime(2026, 10, 5)),
    );

    await run(c);

    expect(stateOf(c).stage, VoiceStage.done);
    expect(stateOf(c).agenda, hasLength(1));
    expect(
      speaker.spoken.last,
      'Para hoy tienes 1 pendiente: reunión a las 2 de la tarde.',
    );
  });

  test('frase sin sentido termina con ayuda', () async {
    final recognizer = FakeSpeechRecognizer(
      script: const [SpeechHeard('viernes')],
    );
    final c = await buildContainer(recognizer);

    await run(c);

    expect(stateOf(c).stage, VoiceStage.failed);
    expect(stateOf(c).message, SpanishSpeech.didNotUnderstand);
  });

  test('sin permiso de micrófono lo explica', () async {
    final recognizer = FakeSpeechRecognizer(
      availability: SpeechAvailability.permissionDenied,
    );
    final c = await buildContainer(recognizer);

    await run(c);

    expect(stateOf(c).message, SpanishSpeech.permissionDenied);
    expect(recognizer.listenCount, 0);
  });

  group('datos para entrenar la IA', () {
    test('sin consentimiento no guarda nada', () async {
      final recognizer = FakeSpeechRecognizer(
        script: const [SpeechHeard('mañana a las 8 correr'), SpeechHeard('sí')],
      );
      final c = await buildContainer(recognizer);

      await run(c);

      expect(training.samples, isEmpty);
    });

    test('con consentimiento guarda frases y corrección', () async {
      final recognizer = FakeSpeechRecognizer(
        script: const [
          SpeechHeard('mañana a las 8 correr'),
          SpeechHeard('no, a las 9'),
          SpeechHeard('sí'),
        ],
      );
      final c = await buildContainer(
        recognizer,
        prefs: {'settings.dataCollectionConsent': true},
      );

      await run(c);

      final sample = training.samples.single;
      expect(sample.utterances, [
        'mañana a las 8 correr',
        'no, a las 9',
        'sí',
      ]);
      expect(sample.corrected, isTrue);
      expect(sample.initialParse['time'], '8:0');
      expect(sample.finalResult['dueAt'], '2026-10-02T09:00:00.000');
    });
  });

  test('cancelar desde la UI detiene todo', () async {
    final recognizer = FakeSpeechRecognizer();
    final c = await buildContainer(recognizer);

    final running = run(c);
    await pumpEventQueue();
    expect(stateOf(c).isListening, isTrue);

    await c.read(voiceAssistantProvider.notifier).cancel();
    await running;

    expect(stateOf(c).stage, VoiceStage.idle);
    expect(repository.reminders, isEmpty);
  });

  test('"Editar" entrega lo entendido como borrador', () async {
    final recognizer = FakeSpeechRecognizer(
      script: const [SpeechHeard('el viernes a las 4 cita con el dentista')],
    );
    final c = await buildContainer(recognizer);

    final running = run(c);
    await pumpEventQueue();
    final draft = await c
        .read(voiceAssistantProvider.notifier)
        .takeDraftForEditor();
    await running;

    expect(draft!.title, 'Cita con el dentista');
    expect(draft.dueAt, DateTime(2026, 10, 2, 16));
    expect(draft.category, ReminderCategory.health);
    expect(draft.source, ReminderSource.voice);
    expect(repository.reminders, isEmpty);
  });

  test('«buenos días» lee el resumen del día con el calendario', () async {
    final c = await buildContainer(
      FakeSpeechRecognizer(script: const [SpeechHeard('buenos días')]),
      prefs: {'settings.includeCalendar': true},
      extra: [
        deviceDataProvider.overrideWithValue(
          FakeDeviceData(
            events: [
              CalendarEvent(
                title: 'Reunión con Ana',
                start: DateTime(2026, 10, 1, 15),
                end: DateTime(2026, 10, 1, 16),
              ),
            ],
          ),
        ),
      ],
    );
    await repository.save(
      buildReminder(title: 'Pagar la luz', dueAt: DateTime(2026, 10, 1, 18)),
    );

    await run(c);

    expect(stateOf(c).stage, VoiceStage.done);
    expect(stateOf(c).message, startsWith('Buenos días.'));
    expect(stateOf(c).message, contains('pagar la luz a las 6'));
    expect(stateOf(c).message, contains('reunión con Ana'));
    expect(stateOf(c).events, hasLength(1));
  });

  test('el resumen también se puede pedir sin escuchar', () async {
    final c = await buildContainer(FakeSpeechRecognizer());

    await c.read(voiceAssistantProvider.notifier).briefing();

    expect(speaker.spoken.single, startsWith('Buenos días.'));
  });

  test('en modo conducción confirma y responde corto', () async {
    final c = await buildContainer(
      FakeSpeechRecognizer(
        script: const [
          SpeechHeard('mañana a las 8 pagar la luz'),
          SpeechHeard('sí'),
        ],
      ),
      extra: [
        deviceDataProvider.overrideWithValue(FakeDeviceData(driving: true)),
      ],
    );

    await run(c);

    expect(stateOf(c).driving, isTrue);
    expect(
      speaker.spoken[1],
      'Pagar la luz, mañana a las 8 de la mañana. ¿Sí?',
    );
    expect(speaker.spoken.last, startsWith('Listo, mañana'));
  });

  test('«¿qué tengo hoy?» suma los eventos del calendario', () async {
    final c = await buildContainer(
      FakeSpeechRecognizer(script: const [SpeechHeard('qué tengo hoy')]),
      prefs: {'settings.includeCalendar': true},
      extra: [
        deviceDataProvider.overrideWithValue(
          FakeDeviceData(
            events: [
              CalendarEvent(
                title: 'Dentista',
                start: DateTime(2026, 10, 1, 16),
                end: DateTime(2026, 10, 1, 17),
              ),
            ],
          ),
        ),
      ],
    );

    await run(c);

    expect(stateOf(c).message, contains('En tu calendario: dentista'));
  });
}
