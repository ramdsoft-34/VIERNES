import 'package:flutter_test/flutter_test.dart';
import 'package:viernes/ai/dataset/training_exporter.dart';
import 'package:viernes/ai/dataset/training_sample.dart';
import 'package:viernes/ai/learning/accuracy_report.dart';
import 'package:viernes/ai/learning/category_model.dart';
import 'package:viernes/ai/learning/personal_habits.dart';
import 'package:viernes/ai/learning/personal_model.dart';
import 'package:viernes/ai/learning/text_features.dart';
import 'package:viernes/ai/nlu/es/spanish_rule_interpreter.dart';
import 'package:viernes/ai/nlu/hybrid_interpreter.dart';
import 'package:viernes/ai/nlu/interpretation.dart';
import 'package:viernes/core/utils/day_time.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';

Reminder _reminder(
  String title,
  ReminderCategory category, {
  DateTime? dueAt,
  Duration lead = Duration.zero,
  ReminderSource source = ReminderSource.manual,
  int id = 0,
}) {
  final created = DateTime(2026, 9);
  return Reminder(
    id: '$title-$id',
    title: title,
    category: category,
    dueAt: dueAt ?? DateTime(2026, 9, 10, 9),
    leadTime: lead,
    source: source,
    createdAt: created,
    updatedAt: created,
  );
}

/// Recordatorios de alguien que llama "Sofi" a su hija y agenda la tarde a
/// las 4:00 p. m.
List<Reminder> _history() => [
  for (final (i, title) in [
    'Recoger a Sofi',
    'Llevar a Sofi a natación',
    'Cumpleaños de Sofi',
    'Comprarle zapatos a Sofi',
  ].indexed)
    _reminder(
      title,
      ReminderCategory.personal,
      dueAt: DateTime(2026, 9, 10 + i, 16),
      id: i,
    ),
  for (final (i, title) in [
    'Daily del equipo',
    'Revisar el sprint',
    'Daily con el cliente',
    'Planear el sprint',
  ].indexed)
    _reminder(
      title,
      ReminderCategory.work,
      dueAt: DateTime(2026, 9, 10 + i, 9),
      lead: const Duration(minutes: 5),
      id: i,
    ),
];

void main() {
  final now = DateTime(2026, 10, 1, 10);

  group('TextFeatures', () {
    test('minúsculas, sin tildes, sin palabras vacías y sin plurales', () {
      expect(
        TextFeatures.tokens('Pagar las Facturas del Banco'),
        ['pagar', 'factura', 'banco'],
      );
      expect(TextFeatures.tokens('Cumpleaños de Sofí'), ['cumpleano', 'sofi']);
    });
  });

  group('CategoryModel', () {
    test('aprende el vocabulario propio del usuario', () {
      final model = CategoryModel.train(
        PersonalModel.examplesFrom(_history()),
      );
      final sofi = model.predict('Ir por Sofi al colegio')!;
      expect(sofi.category, ReminderCategory.personal);
      expect(sofi.confidence, greaterThan(0.75));
      expect(
        model.predict('Daily de mañana')!.category,
        ReminderCategory.work,
      );
    });

    test('no opina sin datos suficientes o con palabras desconocidas', () {
      final small = CategoryModel.train([
        const CategoryExample('Recoger a Sofi', ReminderCategory.personal),
      ]);
      expect(small.predict('Recoger a Sofi'), isNull);

      final model = CategoryModel.train(PersonalModel.examplesFrom(_history()));
      expect(model.predict('xyz abc'), isNull);
    });

    test('ignora la categoría "Otra"', () {
      final model = CategoryModel.train([
        for (var i = 0; i < 10; i++)
          CategoryExample('cosa $i', ReminderCategory.other),
      ]);
      expect(model.examples, 0);
    });

    test('precisión con validación cruzada', () {
      final examples = PersonalModel.examplesFrom([
        ..._history(),
        ..._history(),
        ..._history(),
      ]);
      final accuracy = CategoryModel.crossValidatedAccuracy(examples)!;
      expect(accuracy, greaterThan(0.9));
      expect(
        CategoryModel.crossValidatedAccuracy(examples.take(3).toList()),
        isNull,
      );
    });
  });

  group('PersonalHabits', () {
    test('aprende la hora habitual de cada franja', () {
      final habits = PersonalHabits.learn(_history());
      expect(habits.periodTimes[DayPeriod.afternoon], const DayTime(16, 0));
      expect(habits.periodTimes[DayPeriod.morning], const DayTime(9, 0));
      expect(habits.periodTimes[DayPeriod.night], isNull);
    });

    test('aprende la anticipación habitual solo si es clara', () {
      final habits = PersonalHabits.learn(_history());
      expect(
        habits.leadTimes[ReminderCategory.work],
        const Duration(minutes: 5),
      );
      expect(habits.leadTimes[ReminderCategory.personal], Duration.zero);

      final mixed = PersonalHabits.learn([
        _reminder('a', ReminderCategory.home, lead: const Duration(minutes: 5)),
        _reminder('b', ReminderCategory.home, lead: const Duration(hours: 1)),
        _reminder('c', ReminderCategory.home, lead: const Duration(days: 1)),
      ]);
      expect(mixed.leadTimes[ReminderCategory.home], isNull);
    });
  });

  group('HybridInterpreter', () {
    late HybridInterpreter hybrid;
    PersonalModel? model;

    setUp(() {
      model = PersonalModel.train(_history(), now: now);
      hybrid = HybridInterpreter(
        rules: const SpanishRuleInterpreter(),
        personal: () => model,
      );
    });

    test('usa el vocabulario aprendido para la categoría', () async {
      // Las reglas no saben quién es Sofi: dirían "Otra".
      const rules = SpanishRuleInterpreter();
      expect(
        rules.parse('mañana a las 5 recoger a Sofi', now).reminder.category,
        ReminderCategory.other,
      );

      final result = await hybrid.interpret(
        'mañana a las 5 recoger a Sofi',
        now,
      );
      expect(result.reminder.category, ReminderCategory.personal);
      expect(result.interpreterVersion, startsWith('hybrid-1.1+rules'));
    });

    test('"en la tarde" usa la hora habitual del usuario', () async {
      final result = await hybrid.interpret('mañana en la tarde llamar', now);
      expect(result.reminder.resolveDue(now), DateTime(2026, 10, 2, 16));
    });

    test('aplica la anticipación habitual de la categoría', () async {
      final result = await hybrid.interpret(
        'mañana a las 9 revisar el sprint',
        now,
      );
      expect(result.reminder.category, ReminderCategory.work);
      expect(result.reminder.leadTime, const Duration(minutes: 5));
    });

    test('lo pedido explícitamente manda sobre lo aprendido', () async {
      final result = await hybrid.interpret(
        'mañana a las 9 revisar el sprint, avísame una hora antes',
        now,
      );
      expect(result.reminder.leadTime, const Duration(hours: 1));
    });

    test('sin modelo se comporta igual que las reglas', () async {
      model = null;
      final result = await hybrid.interpret('mañana en la tarde llamar', now);
      expect(result.reminder.resolveDue(now), DateTime(2026, 10, 2, 15));
      expect(result.interpreterVersion, SpanishRuleInterpreter.version);
    });
  });

  group('AccuracyReport y exportación', () {
    TrainingSample sample({
      required bool corrected,
      String initialTitle = 'Correr',
      String finalTitle = 'Correr',
    }) => TrainingSample(
      utterances: const ['mañana a las 8 correr'],
      initialParse: {'title': initialTitle, 'category': 'health'},
      finalResult: {'title': finalTitle, 'category': 'health'},
      corrected: corrected,
      confidence: 1,
      interpreterVersion: 'rules-es-1.0',
      createdAt: DateTime(2026, 10),
    );

    test('mide lo entendido a la primera y las correcciones', () {
      final report = AccuracyReport.from([
        sample(corrected: false),
        sample(corrected: false),
        sample(corrected: true, finalTitle: 'Salir a correr'),
        sample(corrected: true),
      ]);
      expect(report.total, 4);
      expect(report.firstTryRate, 0.5);
      expect(report.titleCorrections, 1);
      expect(AccuracyReport.from(const []).firstTryRate, isNull);
    });

    test('JSONL: una conversación por línea', () {
      final jsonl = TrainingExporter.toJsonl([
        sample(corrected: false),
        sample(corrected: true),
      ]);
      final lines = jsonl.split('\n');
      expect(lines, hasLength(2));
      expect(lines.first, contains('"utterances":["mañana a las 8 correr"]'));
      expect(lines.last, contains('"corrected":true'));
    });
  });
}
