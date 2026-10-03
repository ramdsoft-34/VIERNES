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
import 'package:viernes/core/widgets/liquid.dart';
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

    // La alerta siempre es oscura: se lee bien con el teléfono bloqueado.
    return Theme(
      data: AppTheme.dark(),
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: Colors.transparent,
          body: AmbientBackground(
            mood: AmbientMood.alert,
            child: SafeArea(
              child: switch (reminderAsync) {
                AsyncData(value: final reminder?) => _content(
                  context,
                  reminder,
                  now,
                ),
                AsyncData() => _missing(context),
                AsyncError() => _missing(context),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ),
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

  Widget _content(BuildContext context, Reminder reminder, DateTime now) {
    final l10n = context.l10n;
    final p = LiquidPalette.of(context);
    final text = context.textTheme;
    final done = reminder.status == ReminderStatus.completed;
    if (!done) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _announce(reminder);
      });
    }
    final overdue = reminder.isOverdue(now);
    final preferred = ref.read(preferredSnoozeProvider)();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.dayAndTime(reminder.dueAt, now),
                  style: AppTheme.monoStyle(text.labelMedium).copyWith(
                    color: overdue ? p.ember : p.textSecondary,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.voiceClose,
                onPressed: _close,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Text(
                  reminder.title,
                  style: reminder.title.length > 28
                      ? text.displaySmall
                      : text.displayMedium,
                ),
                if (reminder.notes case final notes?) ...[
                  const SizedBox(height: 16),
                  Text(
                    notes,
                    style: text.bodyLarge?.copyWith(
                      color: p.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                AttachmentsSection(
                  reminderId: reminder.id,
                  readOnly: true,
                  dark: true,
                ),
              ],
            ),
          ),
          if (_resultMessage != null || _listening || _heard.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _resultMessage ??
                    (_heard.isEmpty ? l10n.alertListeningHint : '“$_heard”'),
                textAlign: TextAlign.center,
                style: text.titleMedium,
              ),
            ),
          if (done)
            FilledButton(onPressed: _close, child: Text(l10n.voiceClose))
          else ...[
            // Posponer: gotas en arco, al alcance del pulgar.
            SizedBox(
              height: 112,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: const Alignment(-0.92, 0.7),
                    child: _SnoozeDrop(
                      value: l10n.duration(preferred),
                      tooltip: l10n.alertSnoozeFor(l10n.duration(preferred)),
                      onTap: _busy
                          ? null
                          : () => unawaited(_snooze(reminder, preferred)),
                    ),
                  ),
                  Align(
                    alignment: const Alignment(-0.3, -0.8),
                    child: _SnoozeDrop(
                      value: l10n.duration(const Duration(hours: 1)),
                      tooltip: l10n.alertSnoozeFor(
                        l10n.duration(const Duration(hours: 1)),
                      ),
                      onTap: _busy
                          ? null
                          : () => unawaited(
                              _snooze(
                                reminder,
                                const Duration(hours: 1),
                                chosen: true,
                              ),
                            ),
                    ),
                  ),
                  Align(
                    alignment: const Alignment(0.35, -0.8),
                    child: _SnoozeDrop(
                      value: l10n.alertTomorrowShort,
                      tooltip: l10n.alertSnoozeTomorrow,
                      onTap: _busy
                          ? null
                          : () => unawaited(
                              _snooze(reminder, const Duration(days: 1)),
                            ),
                    ),
                  ),
                  Align(
                    alignment: const Alignment(0.95, 0.7),
                    child: _SnoozeDrop(
                      icon: Icons.more_horiz_rounded,
                      tooltip: l10n.alertSnoozeOther,
                      onTap: _busy
                          ? null
                          : () => unawaited(_chooseSnooze(reminder)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SwipeToConfirm(
                    label: l10n.alertSwipeDone,
                    confirmedLabel: l10n.actionComplete,
                    enabled: !_busy,
                    onConfirmed: () => _complete(reminder),
                  ),
                ),
                const SizedBox(width: 10),
                GlassIconButton(
                  size: 76,
                  icon: _listening ? Icons.graphic_eq : Icons.mic_none_rounded,
                  tooltip: l10n.alertReplyByVoice,
                  onPressed: _busy || _listening
                      ? null
                      : () => unawaited(_replyByVoice(reminder)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Gota de vidrio para posponer.
class _SnoozeDrop extends StatelessWidget {
  const _SnoozeDrop({
    required this.tooltip,
    required this.onTap,
    this.value,
    this.icon,
  });

  final String? value;
  final IconData? icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final parts = (value ?? '').split(' ');
    return Tooltip(
      message: tooltip,
      child: PressScale(
        onTap: onTap,
        semanticLabel: tooltip,
        scale: 0.9,
        child: SizedBox.square(
          dimension: 74,
          child: LiquidGlass(
            shape: BoxShape.circle,
            child: Center(
              child: icon != null
                  ? Icon(icon)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          parts.first,
                          style: int.tryParse(parts.first) == null
                              ? context.textTheme.labelLarge
                              : AppTheme.monoStyle(
                                  context.textTheme.titleLarge,
                                ),
                        ),
                        if (parts.length > 1)
                          Text(
                            parts.sublist(1).join(' '),
                            style: context.textTheme.labelSmall,
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
