import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viernes/ai/ai_providers.dart';
import 'package:viernes/ai/nlu/es/spanish_speech.dart';
import 'package:viernes/ai/speech/speech_recognizer.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/core/utils/clock.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/presentation/providers/reminder_providers.dart';
import 'package:viernes/features/voice_assistant/domain/voice_state.dart';
import 'package:viernes/features/voice_assistant/presentation/voice_assistant_controller.dart';

import '../../helpers/builders.dart';
import '../../helpers/fake_reminder_repository.dart';
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
}
