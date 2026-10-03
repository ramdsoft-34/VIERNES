import 'package:viernes/core/error/failure.dart';

/// Reglas de negocio compartidas al crear y editar.
abstract final class ReminderValidator {
  static const maxTitleLength = 200;
  static const maxLeadTime = Duration(days: 7);

  /// Margen para no rechazar un recordatorio creado "para ahora mismo".
  static const pastTolerance = Duration(minutes: 1);

  static ValidationFailure? validate({
    required String title,
    required DateTime dueAt,
    required Duration leadTime,
    required DateTime now,
    bool checkPast = true,
  }) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return const ValidationFailure(
        'Dime qué tengo que recordarte',
        field: 'title',
      );
    }
    if (trimmed.length > maxTitleLength) {
      return const ValidationFailure(
        'El texto es demasiado largo (máx. $maxTitleLength caracteres)',
        field: 'title',
      );
    }
    if (leadTime.isNegative || leadTime > maxLeadTime) {
      return const ValidationFailure(
        'La anticipación debe estar entre 0 minutos y 7 días',
        field: 'leadTime',
      );
    }
    if (checkPast && dueAt.isBefore(now.subtract(pastTolerance))) {
      return const ValidationFailure(
        'Esa fecha ya pasó. Elige una fecha futura',
        field: 'dueAt',
      );
    }
    return null;
  }
}
