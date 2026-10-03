import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:viernes/ai/wake_word/wake_sample_store.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/app/router/routes.dart';
import 'package:viernes/app/theme/app_theme.dart';
import 'package:viernes/core/extensions/context_x.dart';
import 'package:viernes/core/platform/device_data.dart';
import 'package:viernes/core/platform/system_bridge.dart';
import 'package:viernes/core/widgets/liquid.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/presentation/reminder_formatters.dart';
import 'package:viernes/features/voice_assistant/domain/voice_state.dart';
import 'package:viernes/features/voice_assistant/presentation/voice_assistant_controller.dart';
import 'package:viernes/features/voice_assistant/presentation/wake_word_controller.dart';

/// Abre la conversación con Viernes: una capa de vidrio a pantalla casi
/// completa sobre lo que había.
///
/// [fromWake] indica que se abrió al decir "Viernes" (quizá con el teléfono
/// bloqueado). Con [briefing], en vez de escuchar lee el resumen del día.
Future<void> showVoiceAssistant(
  BuildContext context, {
  bool fromWake = false,
  bool briefing = false,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  barrierColor: LiquidPalette.of(context).shadow,
  builder: (_) => VoiceAssistantSheet(fromWake: fromWake, briefing: briefing),
);

class VoiceAssistantSheet extends ConsumerStatefulWidget {
  const VoiceAssistantSheet({
    this.fromWake = false,
    this.briefing = false,
    this.bridge = const SystemBridge(),
    super.key,
  });

  final bool fromWake;

  /// Leer el resumen del día en lugar de escuchar.
  final bool briefing;
  final SystemBridge bridge;

  /// Evita abrir dos conversaciones a la vez (p. ej. dos "Viernes" seguidos).
  static bool isOpen = false;

  @override
  ConsumerState<VoiceAssistantSheet> createState() =>
      _VoiceAssistantSheetState();
}

class _VoiceAssistantSheetState extends ConsumerState<VoiceAssistantSheet> {
  /// Se guarda al iniciar: `ref` no se puede usar en dispose().
  late final WakeWordController _wake;
  late final VoiceAssistantController _voice;
  late final WakeSampleStore _samples;

  @override
  void initState() {
    super.initState();
    VoiceAssistantSheet.isOpen = true;
    _wake = ref.read(wakeWordControllerProvider.notifier);
    _voice = ref.read(voiceAssistantProvider.notifier);
    _samples = ref.read(wakeSampleStoreProvider);
    // La escucha de "Viernes" suelta el micrófono durante la conversación.
    unawaited(_wake.pause());
    // Arranca apenas se abre la hoja.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final voice = ref.read(voiceAssistantProvider.notifier);
      unawaited(widget.briefing ? voice.briefing() : voice.start());
    });
  }

  @override
  void dispose() {
    VoiceAssistantSheet.isOpen = false;
    unawaited(_wake.resume());
    if (widget.fromWake) {
      unawaited(widget.bridge.setShowOverLockScreen(enabled: false));
      // Etiqueta el audio de la activación (si se guardó) como real o error.
      unawaited(_samples.labelLatest(real: _voice.wakeWasReal));
    }
    super.dispose();
  }

  Future<void> _openEditor() async {
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    final draft = await ref
        .read(voiceAssistantProvider.notifier)
        .takeDraftForEditor();
    navigator.pop();
    unawaited(router.push(AppRoutes.newReminder(), extra: draft));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(voiceAssistantProvider);
    final controller = ref.read(voiceAssistantProvider.notifier);
    final l10n = context.l10n;
    final p = LiquidPalette.of(context);
    final text = context.textTheme;
    final height = MediaQuery.sizeOf(context).height;

    final status = switch (state.stage) {
      _ when state.isListening => l10n.voiceListening,
      VoiceStage.thinking => l10n.voiceThinking,
      VoiceStage.confirming => l10n.voiceConfirming,
      VoiceStage.done => l10n.voiceDone,
      VoiceStage.failed => l10n.voiceProblem,
      _ => l10n.voiceStarting,
    };

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: height * 0.9),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
          child: AmbientBackground(
            mood: AmbientMood.voice,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Barra superior: cerrar y estado.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 20, 0),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: l10n.voiceClose,
                          onPressed: () {
                            unawaited(controller.cancel());
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                        const Spacer(),
                        AnimatedSwitcher(
                          duration: LiquidMotion.of(
                            context,
                            LiquidMotion.fast,
                          ),
                          child: Text(
                            status,
                            key: ValueKey(status),
                            style: AppTheme.monoStyle(text.labelMedium)
                                .copyWith(
                                  color: state.isListening
                                      ? p.accentText
                                      : p.textSecondary,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                      children: [
                        _Heard(state: state),
                        if (state.preview case final preview?
                            when state.stage != VoiceStage.done) ...[
                          const SizedBox(height: 18),
                          _Tokens(preview: preview, onTap: _openEditor),
                        ],
                        const SizedBox(height: 20),
                        _Reply(state: state),
                        if (state.agenda case final agenda?
                            when agenda.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _AgendaList(items: agenda),
                        ],
                        if (state.events case final events?
                            when events.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _EventsList(events: events),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  VoiceOrb(
                    size: state.driving ? 148 : 120,
                    listening: state.isListening,
                    thinking: state.stage == VoiceStage.thinking,
                    color: state.stage == VoiceStage.failed ? p.ember : null,
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: _Actions(
                      state: state,
                      onCancel: () {
                        unawaited(controller.cancel());
                        Navigator.of(context).pop();
                      },
                      onSave: controller.confirmSave,
                      onListen: controller.listenAgain,
                      onEdit: () => unawaited(_openEditor()),
                      onRetry: () => unawaited(controller.start()),
                      onClose: () => Navigator.of(context).pop(),
                    ),
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

/// Lo que dijiste, en grande, con un cursor mientras escuchas.
class _Heard extends StatelessWidget {
  const _Heard({required this.state});

  final VoiceState state;

  @override
  Widget build(BuildContext context) {
    final p = LiquidPalette.of(context);
    final style = (state.driving
        ? context.textTheme.headlineLarge
        : context.textTheme.headlineMedium)!;
    final heard = state.transcript;
    if (heard.isEmpty) {
      return Text(
        state.isListening ? context.l10n.voiceSayIt : '',
        style: style.copyWith(color: p.textMuted),
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: heard),
          if (state.isListening)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                width: 2.5,
                height: style.fontSize! * 0.9,
                margin: const EdgeInsets.only(left: 4),
                color: p.accent,
              ),
            ),
        ],
      ),
      style: style,
    );
  }
}

/// Lo que entendió Viernes, como cápsulas de vidrio con su etiqueta. Tocar
/// una abre el editor para corregirla.
class _Tokens extends ConsumerWidget {
  const _Tokens({required this.preview, required this.onTap});

  final VoicePreview preview;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final now = ref.watch(clockProvider).now();
    final due = preview.due;
    final tokens = <(String, String)>[
      (l10n.voiceTokenWhat, preview.title.isEmpty ? '…' : preview.title),
      (
        l10n.voiceTokenWhen,
        due == null ? l10n.voiceWhenMissing : l10n.dayAndTime(due, now),
      ),
      if (due != null) (l10n.voiceTokenNotice, l10n.leadTime(preview.leadTime)),
      if (preview.recurrence.repeats)
        (l10n.voiceTokenRepeat, l10n.recurrence(preview.recurrence)),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, value) in tokens)
          _Token(label: label, value: value, onTap: () => unawaited(onTap())),
      ],
    );
  }
}

class _Token extends StatelessWidget {
  const _Token({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = LiquidPalette.of(context);
    return PressScale(
      onTap: onTap,
      semanticLabel: '$label: $value',
      child: LiquidGlass(
        radius: LiquidRadius.sm + 2,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTheme.monoStyle(
                context.textTheme.labelSmall,
              ).copyWith(color: p.accentText),
            ),
            const SizedBox(height: 2),
            Text(value, style: context.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

/// La respuesta de Viernes en una tarjeta de vidrio.
class _Reply extends StatelessWidget {
  const _Reply({required this.state});

  final VoiceState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final message = state.message.isEmpty ? l10n.voiceStarting : state.message;
    return AnimatedSwitcher(
      duration: LiquidMotion.of(context, LiquidMotion.medium),
      switchInCurve: LiquidMotion.settle,
      child: LiquidGlass(
        key: ValueKey(message),
        radius: LiquidRadius.lg,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: SizedBox(
          width: double.infinity,
          child: Text(
            message,
            style: state.driving
                ? context.textTheme.headlineSmall
                : context.textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}

class _AgendaList extends ConsumerWidget {
  const _AgendaList({required this.items});

  final List<Reminder> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).now();
    return GlassGroup(
      children: [
        for (final reminder in items.take(8))
          ListTile(
            dense: true,
            leading: Icon(reminder.category.icon),
            title: Text(reminder.title),
            trailing: Text(
              context.l10n.dayAndTime(reminder.dueAt, now),
              style: AppTheme.monoStyle(context.textTheme.labelSmall),
            ),
            textColor: reminder.status == ReminderStatus.snoozed
                ? context.colors.tertiary
                : null,
          ),
      ],
    );
  }
}

/// Eventos del calendario del teléfono (solo lectura).
class _EventsList extends ConsumerWidget {
  const _EventsList({required this.events});

  final List<CalendarEvent> events;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).now();
    final l10n = context.l10n;
    return GlassGroup(
      children: [
        for (final event in events.take(6))
          ListTile(
            dense: true,
            leading: const Icon(Icons.event_note_outlined),
            title: Text(event.title),
            subtitle: Text(l10n.calendarFromPhone),
            trailing: Text(
              event.allDay
                  ? l10n.calendarAllDay
                  : l10n.dayAndTime(event.start, now),
              style: AppTheme.monoStyle(context.textTheme.labelSmall),
            ),
          ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.state,
    required this.onCancel,
    required this.onSave,
    required this.onListen,
    required this.onEdit,
    required this.onRetry,
    required this.onClose,
  });

  final VoiceState state;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final VoidCallback onListen;
  final VoidCallback onEdit;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget expand(Widget w) => Expanded(child: w);
    final buttons = switch (state.stage) {
      VoiceStage.confirming => [
        expand(OutlinedButton(onPressed: onEdit, child: Text(l10n.actionEdit))),
        if (!state.isListening)
          IconButton.outlined(
            tooltip: l10n.voiceSpeak,
            onPressed: onListen,
            icon: const Icon(Icons.mic_none_rounded),
          ),
        expand(FilledButton(onPressed: onSave, child: Text(l10n.actionSave))),
      ],
      VoiceStage.done => [
        expand(FilledButton(onPressed: onClose, child: Text(l10n.voiceDone))),
      ],
      VoiceStage.failed => [
        expand(
          OutlinedButton(onPressed: onClose, child: Text(l10n.voiceClose)),
        ),
        if (state.preview != null)
          expand(
            OutlinedButton(onPressed: onEdit, child: Text(l10n.actionEdit)),
          ),
        expand(
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.mic_rounded),
            label: Text(l10n.voiceTryAgain),
          ),
        ),
      ],
      VoiceStage.idle || VoiceStage.listening || VoiceStage.thinking => [
        expand(
          OutlinedButton(onPressed: onCancel, child: Text(l10n.actionCancel)),
        ),
        if (state.preview != null)
          expand(
            OutlinedButton(onPressed: onEdit, child: Text(l10n.actionEdit)),
          ),
      ],
    };
    final row = Row(
      children: [
        for (final (index, button) in buttons.indexed) ...[
          if (index > 0) const SizedBox(width: 10),
          button,
        ],
      ],
    );
    if (!state.driving) return row;
    // Modo conducción: botones más altos, fáciles de tocar sin mirar.
    final big = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(64, 68)),
      textStyle: WidgetStatePropertyAll(context.textTheme.titleLarge),
    );
    return Theme(
      data: Theme.of(context).copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style: big.merge(Theme.of(context).filledButtonTheme.style),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: big.merge(Theme.of(context).outlinedButtonTheme.style),
        ),
      ),
      child: row,
    );
  }
}
