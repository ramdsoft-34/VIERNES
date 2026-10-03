import 'package:intl/intl.dart';
import 'package:viernes/core/utils/date_x.dart';
import 'package:viernes/features/reminders/domain/entities/recurrence.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/l10n/gen/app_localizations.dart';

/// Textos legibles para los valores del dominio.
extension ReminderLabels on AppLocalizations {
  String priority(ReminderPriority value) => switch (value) {
    ReminderPriority.low => priorityLow,
    ReminderPriority.normal => priorityNormal,
    ReminderPriority.high => priorityHigh,
    ReminderPriority.urgent => priorityUrgent,
  };

  String category(ReminderCategory value) => switch (value) {
    ReminderCategory.personal => categoryPersonal,
    ReminderCategory.work => categoryWork,
    ReminderCategory.study => categoryStudy,
    ReminderCategory.health => categoryHealth,
    ReminderCategory.home => categoryHome,
    ReminderCategory.finance => categoryFinance,
    ReminderCategory.other => categoryOther,
  };

  String recurrenceFrequency(RecurrenceFrequency value) => switch (value) {
    RecurrenceFrequency.none => recurrenceNone,
    RecurrenceFrequency.daily => recurrenceDaily,
    RecurrenceFrequency.weekdays => recurrenceWeekdays,
    RecurrenceFrequency.weekly => recurrenceWeekly,
    RecurrenceFrequency.monthly => recurrenceMonthly,
    RecurrenceFrequency.yearly => recurrenceYearly,
  };

  String recurrence(Recurrence value) {
    if (value.frequency == RecurrenceFrequency.weekly &&
        value.weekdays.isNotEmpty) {
      final days = (value.weekdays.toList()..sort())
          .map(weekdayShort)
          .join(', ');
      return recurrenceWeeklyOn(days);
    }
    return recurrenceFrequency(value.frequency);
  }

  String leadTime(Duration value) {
    if (value == Duration.zero) return leadTimeNone;
    if (value.inDays >= 1 && value.inMinutes % (24 * 60) == 0) {
      return leadTimeDays(value.inDays);
    }
    if (value.inHours >= 1 && value.inMinutes % 60 == 0) {
      return leadTimeHours(value.inHours);
    }
    return leadTimeMinutes(value.inMinutes);
  }

  String duration(Duration value) {
    if (value.inHours >= 1 && value.inMinutes % 60 == 0) {
      return durationHours(value.inHours);
    }
    return durationMinutes(value.inMinutes);
  }

  String eventType(ReminderEventType type, {bool? onTime}) => switch (type) {
    ReminderEventType.completed =>
      onTime == false ? eventCompletedLate : eventCompleted,
    ReminderEventType.snoozed => eventSnoozed,
    ReminderEventType.created => eventCreated,
    ReminderEventType.updated => eventUpdated,
    ReminderEventType.deleted => eventDeleted,
    ReminderEventType.restored => eventRestored,
    ReminderEventType.reopened => eventReopened,
    ReminderEventType.notified => eventNotified,
    ReminderEventType.escalated => eventEscalated,
  };

  /// "L", "M", "X"… según `DateTime.weekday` (1 = lunes).
  String weekdayShort(int weekday) {
    final date = DateTime(2024, 1, weekday); // 1 ene 2024 fue lunes.
    final name = DateFormat.E(localeName).format(date);
    return name.replaceAll('.', '');
  }

  /// "Hoy", "Mañana", "Ayer" o "lun, 20 oct".
  String relativeDay(DateTime date, DateTime now) {
    final days = date.startOfDay.difference(now.startOfDay).inDays;
    return switch (days) {
      0 => dateToday,
      1 => dateTomorrow,
      -1 => dateYesterday,
      _ when date.year == now.year => DateFormat(
        'EEE d MMM',
        localeName,
      ).format(date),
      _ => DateFormat('d MMM y', localeName).format(date),
    };
  }

  /// "8:00 a. m."
  String time(DateTime date) => DateFormat('h:mm a', localeName).format(date);

  /// "Mañana · 8:00 a. m."
  String dayAndTime(DateTime date, DateTime now) =>
      '${relativeDay(date, now)} · ${time(date)}';
}
