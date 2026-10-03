import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viernes/ai/ai_providers.dart';
import 'package:viernes/ai/speech/speech_recognizer.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/features/settings/data/settings_repository.dart';
import 'package:viernes/features/settings/domain/app_settings.dart';
import 'package:viernes/features/settings/presentation/settings_controller.dart';
import 'package:viernes/features/voice_assistant/presentation/wake_word_controller.dart';

import '../../helpers/fake_speech.dart';
import '../../helpers/fake_wake_word.dart';

void main() {
  late FakeWakeWordService service;
  late FakeWakeModelManager models;

  Future<ProviderContainer> build({
    bool installed = false,
    bool failDownload = false,
    bool ownModel = false,
    SpeechAvailability mic = SpeechAvailability.available,
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final sharedPrefs = await SharedPreferences.getInstance();
    service = FakeWakeWordService()..ownModel = ownModel;
    models = FakeWakeModelManager(
      installed: installed,
      failDownload: failDownload,
    );
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
        wakeWordServiceProvider.overrideWithValue(service),
        voskModelManagerProvider.overrideWithValue(models),
        speechRecognizerProvider.overrideWithValue(
          FakeSpeechRecognizer(availability: mic),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(wakeWordControllerProvider, (_, _) {});
    await pumpEventQueue();
    return container;
  }

  WakeWordController controllerOf(ProviderContainer c) =>
      c.read(wakeWordControllerProvider.notifier);

  test(
    'activar descarga el modelo la primera vez y empieza a escuchar',
    () async {
      final c = await build();

      await controllerOf(c).enable();

      expect(models.progress, [0.25, 0.5, 1.0]);
      expect(service.calls, ['start']);
      expect(c.read(wakeWordControllerProvider).phase, WakeWordPhase.listening);
      expect(c.read(settingsControllerProvider).wakeWordEnabled, isTrue);
      // Sensibilidad media → umbral 0,80.
      expect(service.lastThreshold, closeTo(0.8, 0.001));
    },
  );

  test('con el modelo ya instalado no descarga de nuevo', () async {
    final c = await build(installed: true);
    await controllerOf(c).enable();
    expect(models.progress, isEmpty);
    expect(service.running, isTrue);
  });

  test('sin micrófono no se activa', () async {
    final c = await build(mic: SpeechAvailability.permissionDenied);

    await controllerOf(c).enable();

    final state = c.read(wakeWordControllerProvider);
    expect(state.phase, WakeWordPhase.error);
    expect(state.error, contains('micrófono'));
    expect(service.calls, isEmpty);
    expect(c.read(settingsControllerProvider).wakeWordEnabled, isFalse);
  });

  test('si falla la descarga lo explica y no queda activado', () async {
    final c = await build(failDownload: true);

    await controllerOf(c).enable();

    expect(c.read(wakeWordControllerProvider).error, contains('descargar'));
    expect(c.read(settingsControllerProvider).wakeWordEnabled, isFalse);
  });

  test('desactivar detiene el servicio', () async {
    final c = await build(installed: true);
    await controllerOf(c).enable();

    await controllerOf(c).disable();

    expect(service.running, isFalse);
    expect(c.read(settingsControllerProvider).wakeWordEnabled, isFalse);
  });

  test('cambiar la sensibilidad reinicia con el nuevo umbral', () async {
    final c = await build(installed: true);
    await controllerOf(c).enable();

    await controllerOf(c).setSensitivity(1);

    expect(service.lastThreshold, closeTo(0.65, 0.001));
  });

  test('pausar y reanudar solo si está activada', () async {
    final c = await build(installed: true);
    await controllerOf(c).pause();
    expect(service.calls, isEmpty);

    await controllerOf(c).enable();
    await controllerOf(c).pause();
    await controllerOf(c).resume();
    expect(service.calls, ['start', 'pause', 'resume']);
  });

  test('al abrir la app retoma la escucha si estaba activada', () async {
    final c = await build(
      installed: true,
      prefs: {'settings.wakeWordEnabled': true},
    );

    await controllerOf(c).ensureRunning();

    expect(service.calls, ['start']);
  });

  test('con el detector propio no descarga nada', () async {
    final c = await build(ownModel: true);

    await controllerOf(c).enable();

    expect(models.progress, isEmpty);
    expect(service.lastModelPath, 'asset:wakeword');
    expect(service.lastThreshold, const AppSettings().ownWakeThreshold);
    expect(c.read(wakeWordControllerProvider).ownModel, isTrue);
  });

  test('elegir Vosk descarga su modelo y reinicia con él', () async {
    final c = await build(ownModel: true);
    await controllerOf(c).enable();

    await controllerOf(c).setEngine(WakeEngine.vosk);

    expect(models.progress, [0.25, 0.5, 1.0]);
    expect(service.lastModelPath, isNot('asset:wakeword'));
    expect(
      c.read(settingsControllerProvider).wakeEngine,
      WakeEngine.vosk,
    );
  });

  test('si la app no trae el detector propio usa Vosk', () async {
    final c = await build();

    await controllerOf(c).enable();

    expect(models.progress, [0.25, 0.5, 1.0]);
    expect(c.read(wakeWordControllerProvider).ownModel, isFalse);
  });

  test('los ajustes guardan activación y sensibilidad', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SettingsRepository(
      await SharedPreferences.getInstance(),
    );
    await repository.save(
      const AppSettings(wakeWordEnabled: true, wakeSensitivity: 0.75),
    );
    final loaded = repository.load();
    expect(loaded.wakeWordEnabled, isTrue);
    expect(loaded.wakeSensitivity, 0.75);
    expect(loaded.wakeThreshold, closeTo(0.725, 0.001));
  });
}
