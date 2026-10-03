import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:viernes/ai/ai_providers.dart';
import 'package:viernes/ai/nlu/es/spanish_alert_reply_parser.dart';
import 'package:viernes/ai/speech/speech_recognizer.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/app/router/routes.dart';
import 'package:viernes/app/theme/app_theme.dart';
import 'package:viernes/core/error/result.dart';
import 'package:viernes/core/extensions/context_x.dart';
import 'package:viernes/core/platform/system_bridge.dart';
import 'package:viernes/features/alerts/presentation/alert_providers.dart';
import 'package:viernes/features/attachments/presentation/attachments_section.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/presentation/providers/reminder_providers.dart';
import 'package:viernes/features/reminders/presentation/reminder_formatters.dart';
import 'package:viernes/features/settings/domain/app_settings.dart';
import 'package:viernes/features/settings/presentation/settings_controller.dart';
import 'package:viernes/features/voice_assistant/presentation/wake_word_controller.dart';

/// Alerta a pantalla completa: Viernes no asume que la tarea se hizo; espera
/// "Ya lo hice" o "Recordar después" (con botones o por voz).
class AlertScreen extends ConsumerStatefulWidget {
  const AlertScreen({
    required this.reminderId,
    this.bridge = const SystemBridge(),
    super.key,
  });

  final String reminderId;
  final SystemBridge bridge;

  @override
  ConsumerState<AlertScreen> createState() => _AlertScreenState();
}

class _AlertScreenState extends ConsumerState<AlertScreen> {
  bool _busy = false;
  bool _listening = false;
  String _heard = '';
  String? _resultMessage;
  bool _spoke = false;

  /// Se guarda al iniciar: `ref` no se puede usar en dispose().
  late final SpeechRecognizer _recognizer;

  @override
  void initState() {
    super.initState();
    _recognizer = ref.read(speechRecognizerProvider);
    unawaited(widget.bridge.setShowOverLockScreen(enabled: true));
  }

  @override
  void dispose() {
    unawaited(widget.bridge.setShowOverLockScreen(enabled: false));
    unawaited(_recognizer.cancel());
    super.dispose();
  }

  /// Viernes lee el recordatorio en voz alta una vez.
  void _announce(Reminder reminder) {
    if (_spoke || !ref.read(settingsControllerProvider).soundEnabled) return;
    _spoke = true;
    unawaited(
      ref.read(speakerProvider).speak(context.l10n.alertSpoken(reminder.title)),
    );
  }

  Future<void> _complete(Reminder reminder) async {
    await _run(() => ref.read(completeReminderProvider)(reminder.id), (_) {
      return reminder.recurrence.repeats
          ? context.l10n.feedbackCompletedRecurring
          : context.l10n.feedbackCompleted;
    });
  }

  /// [chosen]: el usuario eligió el tiempo (se aprende de eso).
  Future<void> _snooze(
    Reminder reminder,
    Duration delay, {
    bool chosen = false,
  }) async {
    if (chosen) await ref.read(snoozeHabitsProvider).record(delay);
    await _run(
      () => ref.read(snoozeReminderProvider)(reminder.id, delay),
      (_) => context.l10n.feedbackSnoozed(context.l10n.duration(delay)),
    );
  }

  Future<void> _run(
    Future<Result<Reminder>> Function() action,
    String Function(Reminder updated) success,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    await _recognizer.cancel();
    unawaited(ref.read(speakerProvider).stop());
    final result = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _listening = false;
      _resultMessage = result.fold(success, (failure) => failure.message);
    });
    if (result.isOk) {
      unawaited(ref.read(speakerProvider).speak(_resultMessage!));
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (mounted) _close();
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _chooseSnooze(Reminder reminder) async {
    final l10n = context.l10n;
    final habits = ref.read(snoozeHabitsProvider);
    final learned = ref.read(settingsControllerProvider).personalLearning
        ? habits.learned()
        : null;
    final options = habits.ordered(AppSettings.snoozeOptions);
    final delay = await showModalBottomSheet<Duration>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.alertSnoozeQuestion,
                textAlign: TextAlign.center,
                style: context.textTheme.titleMedium,
              ),
            ),
            for (final option in options)
              ListTile(
                leading: const Icon(Icons.snooze),
                title: Text(l10n.alertSnoozeIn(l10n.duration(option))),
                subtitle: option == learned
                    ? Text(l10n.alertSnoozeUsual)
                    : null,
                onTap: () => Navigator.of(context).pop(option),
              ),
            ListTile(
              leading: const Icon(Icons.wb_sunny_outlined),
              title: Text(l10n.alertSnoozeTomorrow),
              onTap: () => Navigator.of(context).pop(const Duration(days: 1)),
            ),
          ],
        ),
      ),
    );
    if (delay != null) await _snooze(reminder, delay, chosen: true);
  }

  Future<void> _replyByVoice(Reminder reminder) async {
    final recognizer = _recognizer;
    if (await recognizer.initialize() != SpeechAvailability.available) {
      if (mounted) setState(() => _resultMessage = context.l10n.alertNoMic);
      return;
    }
    await ref.read(speakerProvider).stop();
    // La escucha de "Viernes" suelta el micrófono mientras respondes.
    final wake = ref.read(wakeWordControllerProvider.notifier);
    await wake.pause();
    if (!mounted) return;
    setState(() {
      _listening = true;
      _heard = '';
      _resultMessage = null;
    });
    final result = await recognizer.listen(
      onPartial: (text) {
        if (mounted) setState(() => _heard = text);
      },
    );
    unawaited(wake.resume());
    if (!mounted) return;
    setState(() => _listening = false);
    if (result is! SpeechHeard) return;

    final now = ref.read(clockProvider).now();
    final reply = const SpanishAlertReplyParser().parse(result.text, now);
    switch (reply.kind) {
      case AlertReplyKind.done:
        await _complete(reminder);
      case AlertReplyKind.snooze:
        final until = reply.until;
        await _snooze(
          reminder,
          until == null
              ? ref.read(preferredSnoozeProvider)()
              : until.difference(now),
          chosen: until != null,
        );
      case AlertReplyKind.dismiss:
        // "Ya no lo necesito": se elimina (queda en el historial).
        await _run(
          () => ref.read(deleteReminderProvider)(reminder.id),
          (_) => context.l10n.alertDismissed,
        );
      case AlertReplyKind.unknown:
        setState(() => _resultMessage = context.l10n.alertDidNotUnderstand);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reminderAsync = ref.watch(reminderByIdProvider(widget.reminderId));
    final now = ref.watch(nowProvider).value ?? DateTime.now();
    final scheme = ColorScheme.fromSeed(
      seedColor: AppTheme.seed,
      brightness: Brightness.dark,
    );

    return Theme(
      data: Theme.of(context).copyWith(colorScheme: scheme),
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          child: switch (reminderAsync) {
            AsyncData(value: final reminder?) => _content(
              context,
              reminder,
              now,
              scheme,
            ),
            AsyncData() => _missing(context),
            AsyncError() => _missing(context),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }

  Widget _missing(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.l10n.reminderNotFound),
        const SizedBox(height: 16),
        FilledButton(onPressed: _close, child: Text(context.l10n.voiceClose)),
      ],
    ),
  );

  Widget _content(
    BuildContext context,
    Reminder reminder,
    DateTime now,
    ColorScheme scheme,
  ) {
    final l10n = context.l10n;
    final done = reminder.status == ReminderStatus.completed;
    if (!done) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _announce(reminder);
      });
    }
    final overdue = reminder.isOverdue(now);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                l10n.appName.toUpperCase(),
                style: context.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: l10n.voiceClose,
                onPressed: _close,
                icon: const Icon(Icons.close),
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
          const Spacer(),
          _Bell(color: reminder.priority.color(scheme), animate: !done),
          const SizedBox(height: 32),
          Text(
            reminder.title,
            textAlign: TextAlign.center,
            style: context.textTheme.headlineMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.dayAndTime(reminder.dueAt, now),
            textAlign: TextAlign.center,
            style: context.textTheme.titleMedium?.copyWith(
              color: overdue ? scheme.error : scheme.onSurfaceVariant,
            ),
          ),
          if (reminder.notes case final notes?) ...[
            const SizedBox(height: 12),
            Text(
              notes,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          Center(
            child: AttachmentsSection(
              reminderId: reminder.id,
              readOnly: true,
              dark: true,
            ),
          ),
          const Spacer(),
          if (_resultMessage != null || _listening || _heard.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _resultMessage ??
                    (_heard.isEmpty ? l10n.alertListeningHint : '“$_heard”'),
                textAlign: TextAlign.center,
                style: context.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
          if (done)
            FilledButton(onPressed: _close, child: Text(l10n.voiceClose))
          else ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(64),
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                textStyle: context.textTheme.titleLarge,
              ),
              onPressed: _busy ? null : () => unawaited(_complete(reminder)),
              icon: const Icon(Icons.check, size: 28),
              label: Text(l10n.actionComplete),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      foregroundColor: scheme.onSurface,
                      textStyle: context.textTheme.titleMedium,
                    ),
                    onPressed: _busy
                        ? null
                        : () => unawaited(
                            _snooze(
                              reminder,
                              ref.read(preferredSnoozeProvider)(),
                            ),
                          ),
                    icon: const Icon(Icons.snooze),
                    label: Text(
                      l10n.alertSnoozeFor(
                        l10n.duration(ref.read(preferredSnoozeProvider)()),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: l10n.alertSnoozeOther,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(56, 56),
                    foregroundColor: scheme.onSurface,
                  ),
                  onPressed: _busy
                      ? null
                      : () => unawaited(_chooseSnooze(reminder)),
                  icon: const Icon(Icons.more_time),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _busy || _listening
                  ? null
                  : () => unawaited(_replyByVoice(reminder)),
              icon: Icon(_listening ? Icons.graphic_eq : Icons.mic),
              label: Text(l10n.alertReplyByVoice),
            ),
          ],
        ],
      ),
    );
  }
}

class _Bell extends StatefulWidget {
  const _Bell({required this.color, required this.animate});

  final Color color;
  final bool animate;

  @override
  State<_Bell> createState() => _BellState();
}

class _BellState extends State<_Bell> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) unawaited(_controller.repeat(reverse: true));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.rotate(
          angle: widget.animate ? (_controller.value - 0.5) * 0.35 : 0,
          child: child,
        ),
        child: Container(
          width: 128,
          height: 128,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.18),
          ),
          child: Icon(
            Icons.notifications_active,
            size: 72,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}
