import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viernes/ai/dataset/training_data_repository.dart';
import 'package:viernes/ai/learning/accuracy_report.dart';
import 'package:viernes/ai/learning/neural_comparison.dart';
import 'package:viernes/ai/learning/personal_model.dart';
import 'package:viernes/ai/nlu/es/category_classifier.dart';
import 'package:viernes/ai/nlu/es/spanish_reply_parser.dart';
import 'package:viernes/ai/nlu/es/spanish_rule_interpreter.dart';
import 'package:viernes/ai/nlu/hybrid_interpreter.dart';
import 'package:viernes/ai/nlu/interpretation.dart';
import 'package:viernes/ai/nlu/ml/neural_tagger.dart';
import 'package:viernes/ai/nlu/reminder_interpreter.dart';
import 'package:viernes/ai/speech/android_speech_recognizer.dart';
import 'package:viernes/ai/speech/recorded_voice.dart';
import 'package:viernes/ai/speech/speech_recognizer.dart';
import 'package:viernes/ai/speech/tts_speaker.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/core/logging/app_logger.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/presentation/providers/reminder_providers.dart';
import 'package:viernes/features/settings/presentation/settings_controller.dart';

// Piezas de IA intercambiables. Para probar otro motor (p. ej. un modelo
// neuronal propio) basta con sobrescribir el provider correspondiente.

final speechRecognizerProvider = Provider<SpeechRecognizer>(
  (ref) => AndroidSpeechRecognizer(),
);

/// Frases grabadas con la voz propia (vacía si la compilación no las trae).
final recordedVoiceProvider = FutureProvider<RecordedVoice>(
  (ref) => RecordedVoice.load(),
);

/// Voz de Viernes: la grabada cuando existe la frase; si no, la del sistema.
final speakerProvider = Provider<Speaker>(
  (ref) => RecordedVoiceSpeaker(
    fallback: TtsSpeaker(),
    voice: ref.read(recordedVoiceProvider.future),
    enabled: () => ref.read(settingsControllerProvider).recordedVoice,
  ),
);

/// Red neuronal propia (entrenada en Colab, ver `training/nlu`). Nula si
/// esta versión no la trae o no se pudo cargar.
final neuralTaggerProvider = FutureProvider<NeuralTagger?>((ref) async {
  try {
    final source = await rootBundle.loadString(neuralModelAsset);
    return NeuralTagger.fromJsonString(source);
  } on Object catch (error) {
    AppLogger.info('Sin intérprete neuronal: $error');
    return null;
  }
});

const neuralModelAsset = 'assets/ai/nlu_model.json';

/// Reglas en español + red neuronal propia + lo aprendido del usuario.
final reminderInterpreterProvider = Provider<ReminderInterpreter>(
  (ref) => HybridInterpreter(
    rules: const SpanishRuleInterpreter(),
    personal: () => ref.read(personalModelProvider),
    neural: () => ref.read(neuralTaggerProvider).value,
    preferNeuralTitles: () => ref.read(settingsControllerProvider).neuralTitles,
  ),
);

final replyParserProvider = Provider<SpanishReplyParser>(
  (ref) => const SpanishReplyParser(),
);

final trainingDataRepositoryProvider = Provider<TrainingDataRepository>(
  (ref) => DriftTrainingDataRepository(ref.watch(appDatabaseProvider)),
);

final trainingSampleCountProvider = StreamProvider<int>(
  (ref) => ref.watch(trainingDataRepositoryProvider).watchCount(),
);

// --- Aprendizaje personal ---------------------------------------------------

/// Todos los recordatorios, como datos de entrenamiento.
final _learningDataProvider = StreamProvider<List<Reminder>>(
  (ref) => ref
      .watch(reminderRepositoryProvider)
      .watchByStatus(ReminderStatus.values.toSet()),
);

/// Modelo personal, reentrenado en el teléfono cada vez que cambian los
/// recordatorios. `null` si el aprendizaje está apagado o aún carga.
final personalModelProvider = Provider<PersonalModel?>((ref) {
  final enabled = ref.watch(
    settingsControllerProvider.select((s) => s.personalLearning),
  );
  if (!enabled) return null;
  final reminders = ref.watch(_learningDataProvider).value;
  if (reminders == null) return null;
  return PersonalModel.train(reminders, now: ref.read(clockProvider).now());
});

/// Categoría sugerida para un título: reglas + modelo personal.
final categoryPredictorProvider = Provider<ReminderCategory Function(String)>(
  (ref) {
    final model = ref.watch(personalModelProvider);
    return (title) {
      final byRules = ParsedReminder(
        title: title,
        category: CategoryClassifier.classify(title),
      );
      return model == null
          ? byRules.category
          : HybridInterpreter.personalize(byRules, model).category;
    };
  },
);

/// Qué tan bien entiende Viernes según las conversaciones guardadas.
final FutureProvider<AccuracyReport> accuracyReportProvider =
    FutureProvider.autoDispose<AccuracyReport>((ref) async {
      ref.watch(trainingSampleCountProvider);
      final samples = await ref.read(trainingDataRepositoryProvider).all();
      return AccuracyReport.from(samples);
    });

/// Reglas frente a red neuronal con las frases reales del usuario. Nulo si
/// la red no está disponible.
final FutureProvider<NeuralComparison?> neuralComparisonProvider =
    FutureProvider.autoDispose<NeuralComparison?>((ref) async {
      ref.watch(trainingSampleCountProvider);
      final tagger = await ref.watch(neuralTaggerProvider.future);
      if (tagger == null) return null;
      final samples = await ref.read(trainingDataRepositoryProvider).all();
      return NeuralComparison.compute(samples, tagger);
    });
