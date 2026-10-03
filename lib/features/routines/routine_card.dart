import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viernes/ai/learning/routine_suggester.dart';
import 'package:viernes/ai/nlu/es/spanish_speech.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/core/error/result.dart';
import 'package:viernes/core/extensions/context_x.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_draft.dart';
import 'package:viernes/features/reminders/presentation/providers/reminder_providers.dart';
import 'package:viernes/features/reminders/presentation/reminder_formatters.dart';
import 'package:viernes/features/settings/presentation/settings_controller.dart';

/// Costumbres que el usuario ya descartó («no, gracias»).
class RoutineDismissals {
  RoutineDismissals(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'learning.routinesDismissed';

  Set<String> all() => (_prefs.getStringList(_key) ?? []).toSet();

  Future<void> dismiss(String key) =>
      _prefs.setStringList(_key, [...all(), key]);
}

final routineDismissalsProvider = Provider<RoutineDismissals>(
  (ref) => RoutineDismissals(ref.watch(sharedPreferencesProvider)),
);

/// Cambia cuando se descarta una sugerencia (para refrescar la lista).
final _dismissTick = NotifierProvider<_Tick, int>(_Tick.new);

class _Tick extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// La sugerencia más clara (o ninguna).
final Provider<RoutineSuggestion?> routineSuggestionProvider =
    Provider.autoDispose<RoutineSuggestion?>((ref) {
      ref.watch(_dismissTick);
      if (!ref.watch(
        settingsControllerProvider.select((s) => s.personalLearning),
      )) {
        return null;
      }
      final all = ref.watch(allRemindersProvider).value;
      if (all == null) return null;
      final suggestions = RoutineSuggester.suggest(
        all,
        now: ref.watch(clockProvider).now(),
        dismissed: ref.watch(routineDismissalsProvider).all(),
      );
      return suggestions.firstOrNull;
    });

/// «Viernes notó una costumbre»: propone dejar repetitiva una tarea.
class RoutineSuggestionCard extends ConsumerWidget {
  const RoutineSuggestionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestion = ref.watch(routineSuggestionProvider);
    if (suggestion == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final colors = context.colors;
    return Card(
      color: colors.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: colors.onTertiaryContainer),
                const SizedBox(width: 8),
                Text(
                  l10n.routineTitle,
                  style: context.textTheme.titleSmall?.copyWith(
                    color: colors.onTertiaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              l10n.routineBody(
                suggestion.title,
                SpanishSpeech.recurrence(suggestion.recurrence),
                l10n.time(
                  DateTime(
                    2000,
                    1,
                    1,
                    suggestion.time.hour,
                    suggestion.time.minute,
                  ),
                ),
              ),
              style: TextStyle(color: colors.onTertiaryContainer),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => unawaited(_dismiss(ref, suggestion)),
                  child: Text(l10n.routineNo),
                ),
                FilledButton.tonal(
                  onPressed: () => unawaited(_accept(context, ref, suggestion)),
                  child: Text(l10n.routineYes),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _dismiss(WidgetRef ref, RoutineSuggestion s) async {
    await ref.read(routineDismissalsProvider).dismiss(s.key);
    ref.read(_dismissTick.notifier).bump();
  }

  Future<void> _accept(
    BuildContext context,
    WidgetRef ref,
    RoutineSuggestion suggestion,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final result = await RoutineActions.accept(ref, suggestion);
    // Aceptada o no, no se vuelve a proponer.
    await ref.read(routineDismissalsProvider).dismiss(suggestion.key);
    ref.read(_dismissTick.notifier).bump();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.fold((_) => l10n.routineDone, (failure) => failure.message),
        ),
      ),
    );
  }
}

abstract final class RoutineActions {
  /// Convierte en repetitivo el pendiente con ese título, o crea uno nuevo
  /// en la próxima fecha de la rutina.
  static Future<Result<Reminder>> accept(
    WidgetRef ref,
    RoutineSuggestion suggestion,
  ) async {
    final repository = ref.read(reminderRepositoryProvider);
    final activeId = suggestion.activeReminderId;
    final active = activeId == null
        ? null
        : await repository.findById(activeId);
    if (active != null) {
      return ref.read(updateReminderProvider)(
        active.copyWith(recurrence: suggestion.recurrence),
      );
    }
    final now = ref.read(clockProvider).now();
    return ref.read(createReminderProvider)(
      ReminderDraft(
        title: suggestion.title,
        dueAt: suggestion.nextDue(now),
        recurrence: suggestion.recurrence,
        leadTime: ref.read(settingsControllerProvider).defaultLeadTime,
      ),
    );
  }
}
