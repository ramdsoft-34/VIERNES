import 'package:flutter/foundation.dart';
import 'package:viernes/features/reminders/domain/entities/recurrence.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';

/// Datos para crear un recordatorio, vengan del formulario o del intérprete
/// de voz.
@immutable
class ReminderDraft {
  const ReminderDraft({
    required this.title,
    required this.dueAt,
    this.notes,
    this.leadTime = Duration.zero,
    this.recurrence = Recurrence.none,
    this.priority = ReminderPriority.normal,
    this.category = ReminderCategory.other,
    this.source = ReminderSource.manual,
    this.rawUtterance,
    this.nluConfidence,
  });

  final String title;
  final DateTime dueAt;
  final String? notes;
  final Duration leadTime;
  final Recurrence recurrence;
  final ReminderPriority priority;
  final ReminderCategory category;
  final ReminderSource source;
  final String? rawUtterance;
  final double? nluConfidence;
}
