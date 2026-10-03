import 'package:viernes/ai/nlu/interpretation.dart';
import 'package:viernes/core/utils/date_x.dart';
import 'package:viernes/features/reminders/domain/entities/recurrence.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_draft.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/voice_assistant/domain/voice_state.dart';

/// Convierte lo interpretado en un recordatorio concreto, aplicando las
/// preferencias del usuario.
abstract final class VoiceDraftBuilder {
  /// Margen mínimo cuando la hora es un límite ("antes de las 8").
  static const deadlineMinimumLead = Duration(minutes: 30);

  /// Anticipación final: la pedida, o la de los ajustes; con un mínimo para
  /// los límites y sin avisar en el pasado.
  static Duration leadTime(
    ParsedReminder parsed, {
    required DateTime due,
    required DateTime now,
    required Duration defaultLead,
  }) {
    var lead =
        parsed.leadTime ??
        (parsed.exactDue != null ? Duration.zero : defaultLead);
    if (parsed.isDeadline &&
        parsed.leadTime == null &&
        lead < deadlineMinimumLead) {
      lead = deadlineMinimumLead;
    }
    final available = due.difference(now);
    if (due.subtract(lead).isBefore(now)) {
      lead = available.isNegative
          ? Duration.zero
          : Duration(minutes: available.inMinutes);
    }
    return lead;
  }

  /// Completa la repetición con el día concreto cuando hace falta.
  static Recurrence recurrence(Recurrence r, DateTime due) =>
      switch (r.frequency) {
        RecurrenceFrequency.monthly when r.monthDay == null =>
          Recurrence.monthly(
            due.day,
            interval: r.interval,
          ).withUntil(r.until),
        RecurrenceFrequency.yearly when r.monthDay == null => Recurrence.yearly(
          due.day,
        ).withUntil(r.until),
        _ => r,
      };

  static VoicePreview preview(
    ParsedReminder parsed, {
    required DateTime now,
    required Duration defaultLead,
  }) {
    final due = parsed.resolveDue(now);
    return VoicePreview(
      title: parsed.title,
      due: due,
      leadTime: due == null
          ? (parsed.leadTime ?? defaultLead)
          : leadTime(parsed, due: due, now: now, defaultLead: defaultLead),
      recurrence: due == null
          ? parsed.recurrence
          : recurrence(parsed.recurrence, due),
      priority: parsed.priority ?? ReminderPriority.normal,
      category: parsed.category,
    );
  }

  /// Borrador listo para guardar. Si aún falta la hora, usa la de la franja
  /// o las 9:00 para que el editor tenga un punto de partida.
  static ReminderDraft draft(
    ParsedReminder parsed, {
    required DateTime now,
    required Duration defaultLead,
    required List<String> utterances,
    double? confidence,
  }) {
    final due =
        parsed.resolveDue(now) ??
        (parsed.date ?? now.startOfDay.addDays(1)).withTime(9, 0);
    return ReminderDraft(
      title: parsed.title,
      dueAt: due,
      leadTime: leadTime(parsed, due: due, now: now, defaultLead: defaultLead),
      recurrence: recurrence(parsed.recurrence, due),
      priority: parsed.priority ?? ReminderPriority.normal,
      category: parsed.category,
      source: ReminderSource.voice,
      rawUtterance: utterances.join(' | '),
      nluConfidence: confidence,
    );
  }
}
