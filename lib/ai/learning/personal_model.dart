import 'package:flutter/foundation.dart';
import 'package:viernes/ai/learning/category_model.dart';
import 'package:viernes/ai/learning/personal_habits.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';

/// Lo que Viernes aprendió del usuario, entrenado en el teléfono.
@immutable
class PersonalModel {
  const PersonalModel({
    required this.category,
    required this.habits,
    required this.trainedOn,
    required this.trainedAt,
    this.categoryAccuracy,
  });

  /// Entrena con los recordatorios guardados (los datos nunca salen del
  /// teléfono).
  factory PersonalModel.train(
    Iterable<Reminder> reminders, {
    required DateTime now,
  }) {
    final examples = examplesFrom(reminders);
    return PersonalModel(
      category: CategoryModel.train(examples),
      habits: PersonalHabits.learn(reminders),
      trainedOn: reminders.length,
      trainedAt: now,
      categoryAccuracy: CategoryModel.crossValidatedAccuracy(examples),
    );
  }

  /// Las categorías elegidas a mano pesan el doble: son correcciones
  /// explícitas del usuario.
  static List<CategoryExample> examplesFrom(Iterable<Reminder> reminders) => [
    for (final reminder in reminders)
      CategoryExample(
        reminder.title,
        reminder.category,
        weight: reminder.source == ReminderSource.manual ? 2 : 1,
      ),
  ];

  final CategoryModel category;
  final PersonalHabits habits;

  /// Recordatorios usados para entrenar.
  final int trainedOn;
  final DateTime trainedAt;

  /// Precisión estimada del clasificador (validación cruzada), si hay datos.
  final double? categoryAccuracy;
}
