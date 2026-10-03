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
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/presentation/reminder_formatters.dart';
import 'package:viernes/features/voice_assistant/domain/voice_state.dart';
import 'package:viernes/features/voice_assistant/presentation/voice_assistant_controller.dart';
import 'package:viernes/features/voice_assistant/presentation/wake_word_controller.dart';

/// Abre la conversación con Viernes en una hoja inferior.
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
  showDragHandle: true,
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

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MicOrb(listening: state.isListening, stage: state.stage),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              state.message.isEmpty ? l10n.voiceStarting : state.message,
              key: ValueKey(state.message),
              textAlign: TextAlign.center,
              style:
                  (state.driving
                          ? context.textTheme.headlineSmall
                          : context.textTheme.titleLarge)
                      ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (state.transcript.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '“${state.transcript}”',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyLarge?.copyWith(
                fontStyle: FontStyle.italic,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
          if (state.preview case final preview?
              when state.stage != VoiceStage.done) ...[
            const SizedBox(height: 20),
            _PreviewCard(preview: preview),
          ],
          if (state.agenda case final agenda? when agenda.isNotEmpty) ...[
            const SizedBox(height: 16),
            _AgendaList(items: agenda),
          ],
          if (state.events case final events? when events.isNotEmpty) ...[
            const SizedBox(height: 8),
            _EventsList(events: events),
          ],
          const SizedBox(height: 24),
          _Actions(
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
        ],
      ),
    );
  }
}

class _MicOrb extends StatefulWidget {
  const _MicOrb({required this.listening, required this.stage});

  final bool listening;
  final VoiceStage stage;

  @override
  State<_MicOrb> createState() => _MicOrbState();
}

class _MicOrbState extends State<_MicOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didUpdateWidget(covariant _MicOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  void _sync() {
    if (widget.listening) {
      if (!_pulse.isAnimating) unawaited(_pulse.repeat(reverse: true));
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (icon, color) = switch (widget.stage) {
      VoiceStage.done => (Icons.check, Colors.green.shade600),
      VoiceStage.failed => (Icons.mic_off, colors.error),
      VoiceStage.thinking => (Icons.auto_awesome, colors.tertiary),
      _ => (Icons.mic, colors.primary),
    };
    return Semantics(
      label: widget.listening ? context.l10n.voiceListening : null,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) => Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.15),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35 * _pulse.value),
                blurRadius: 12 + 28 * _pulse.value,
                spreadRadius: 4 + 10 * _pulse.value,
              ),
            ],
          ),
          child: child,
        ),
        child: Center(
          child: widget.stage == VoiceStage.thinking
              ? SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(color: color),
                )
              : Icon(icon, size: 44, color: color),
        ),
      ),
    );
  }
}

class _PreviewCard extends ConsumerWidget {
  const _PreviewCard({required this.preview});

  final VoicePreview preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final now = ref.watch(clockProvider).now();
    final due = preview.due;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(preview.category.icon, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    preview.title.isEmpty ? '…' : preview.title,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (preview.priority.isAtLeastHigh)
                  Chip(
                    label: Text(l10n.priority(preview.priority)),
                    labelStyle: TextStyle(
                      color: preview.priority.color(colors),
                      fontWeight: FontWeight.w700,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _Line(
              icon: Icons.event,
              text: due == null
                  ? l10n.voiceWhenMissing
                  : l10n.dayAndTime(due, now),
            ),
            if (due != null)
              _Line(
                icon: Icons.notifications_active_outlined,
                text: l10n.leadTime(preview.leadTime),
              ),
            if (preview.recurrence.repeats)
              _Line(
                icon: Icons.repeat,
                text: l10n.recurrence(preview.recurrence),
              ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        Icon(icon, size: 18, color: context.colors.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _AgendaList extends ConsumerWidget {
  const _AgendaList({required this.items});

  final List<Reminder> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).now();
    return Card(
      child: Column(
        children: [
          for (final reminder in items.take(8))
            ListTile(
              dense: true,
              leading: Icon(reminder.category.icon),
              title: Text(reminder.title),
              trailing: Text(context.l10n.dayAndTime(reminder.dueAt, now)),
              textColor: reminder.status == ReminderStatus.snoozed
                  ? context.colors.tertiary
                  : null,
            ),
        ],
      ),
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
    return Card(
      child: Column(
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
              ),
            ),
        ],
      ),
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
    final buttons = switch (state.stage) {
      VoiceStage.confirming => [
        TextButton(onPressed: onCancel, child: Text(l10n.actionCancel)),
        OutlinedButton(onPressed: onEdit, child: Text(l10n.actionEdit)),
        if (!state.isListening)
          IconButton.outlined(
            tooltip: l10n.voiceSpeak,
            onPressed: onListen,
            icon: const Icon(Icons.mic),
          ),
        FilledButton(onPressed: onSave, child: Text(l10n.actionSave)),
      ],
      VoiceStage.done => [
        FilledButton(onPressed: onClose, child: Text(l10n.voiceDone)),
      ],
      VoiceStage.failed => [
        TextButton(onPressed: onClose, child: Text(l10n.voiceClose)),
        if (state.preview != null)
          OutlinedButton(onPressed: onEdit, child: Text(l10n.actionEdit)),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.mic),
          label: Text(l10n.voiceTryAgain),
        ),
      ],
      VoiceStage.idle || VoiceStage.listening || VoiceStage.thinking => [
        TextButton(onPressed: onCancel, child: Text(l10n.actionCancel)),
        if (state.preview != null)
          OutlinedButton(onPressed: onEdit, child: Text(l10n.actionEdit)),
      ],
    };
    final wrap = Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: buttons,
    );
    if (!state.driving) return wrap;
    // Modo conducción: botones grandes, fáciles de tocar sin mirar mucho.
    final big = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(120, 64)),
      textStyle: WidgetStatePropertyAll(context.textTheme.titleLarge),
    );
    return Theme(
      data: Theme.of(context).copyWith(
        filledButtonTheme: FilledButtonThemeData(style: big),
        outlinedButtonTheme: OutlinedButtonThemeData(style: big),
        textButtonTheme: TextButtonThemeData(style: big),
      ),
      child: wrap,
    );
  }
}
