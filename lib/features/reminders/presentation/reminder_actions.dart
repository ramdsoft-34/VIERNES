import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viernes/core/error/result.dart';
import 'package:viernes/core/extensions/context_x.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/presentation/providers/reminder_providers.dart';
import 'package:viernes/features/reminders/presentation/reminder_formatters.dart';
import 'package:viernes/features/settings/presentation/settings_controller.dart';

/// Acciones del usuario sobre un recordatorio con su retroalimentación
/// (snackbar y deshacer). Las comparten la lista, el inicio y el calendario.
abstract final class ReminderActions {
  static Future<void> complete(
    BuildContext context,
    WidgetRef ref,
    Reminder reminder,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final result = await ref.read(completeReminderProvider)(reminder.id);
    _show(
      messenger,
      result.fold(
        (_) => reminder.recurrence.repeats
            ? l10n.feedbackCompletedRecurring
            : l10n.feedbackCompleted,
        (failure) => failure.message,
      ),
      action: result.isOk
          ? SnackBarAction(
              label: l10n.actionUndo,
              onPressed: () =>
                  ref.read(completeReminderProvider).undo(reminder),
            )
          : null,
    );
  }

  static Future<void> snooze(
    BuildContext context,
    WidgetRef ref,
    Reminder reminder,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final delay = ref.read(settingsControllerProvider).snoozeDuration;
    final result = await ref.read(snoozeReminderProvider)(reminder.id, delay);
    _show(
      messenger,
      result.fold(
        (_) => l10n.feedbackSnoozed(l10n.duration(delay)),
        (failure) => failure.message,
      ),
    );
  }

  static Future<void> reopen(
    BuildContext context,
    WidgetRef ref,
    Reminder reminder,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final result = await ref.read(reopenReminderProvider)(reminder.id);
    _show(
      messenger,
      result.fold((_) => l10n.feedbackReopened, (failure) => failure.message),
    );
  }

  /// Elimina sin preguntar y ofrece deshacer (para gestos de deslizar).
  static Future<void> delete(
    BuildContext context,
    WidgetRef ref,
    Reminder reminder,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final result = await ref.read(deleteReminderProvider)(reminder.id);
    switch (result) {
      case Ok(:final value):
        _show(
          messenger,
          l10n.feedbackDeleted,
          action: SnackBarAction(
            label: l10n.actionUndo,
            onPressed: () => ref.read(restoreReminderProvider)(value),
          ),
        );
      case Err(:final failure):
        _show(messenger, failure.message);
    }
  }

  /// Pide confirmación antes de eliminar. Devuelve `true` si se eliminó.
  static Future<bool> confirmAndDelete(
    BuildContext context,
    WidgetRef ref,
    Reminder reminder,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteConfirmTitle),
        content: Text(l10n.deleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return false;
    await delete(context, ref, reminder);
    return true;
  }

  static void _show(
    ScaffoldMessengerState messenger,
    String message, {
    SnackBarAction? action,
  }) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }
}
