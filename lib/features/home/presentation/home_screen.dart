import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/app/router/routes.dart';
import 'package:viernes/app/theme/app_theme.dart';
import 'package:viernes/core/extensions/context_x.dart';
import 'package:viernes/core/utils/date_x.dart';
import 'package:viernes/core/widgets/async_value_view.dart';
import 'package:viernes/core/widgets/empty_state.dart';
import 'package:viernes/core/widgets/liquid.dart';
import 'package:viernes/core/widgets/section_header.dart';
import 'package:viernes/features/alerts/presentation/permissions_widgets.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/presentation/providers/reminder_providers.dart';
import 'package:viernes/features/reminders/presentation/widgets/reminder_tile.dart';
import 'package:viernes/features/routines/routine_card.dart';
import 'package:viernes/features/settings/presentation/settings_controller.dart';
import 'package:viernes/features/voice_assistant/presentation/voice_assistant_sheet.dart';
import 'package:viernes/features/voice_assistant/presentation/wake_word_controller.dart';

/// «Ahora»: una cuenta regresiva gigante hasta lo próximo y el día como un
/// río de vidrio, ordenado por la hora en que pasa cada cosa.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _upcomingLimit = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider).value ?? DateTime.now();
    final reminders = ref.watch(activeRemindersProvider);

    return LiquidScaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncValueView(
          value: reminders,
          data: (items) {
            final overdue = items
                .where(
                  (r) => r.status == ReminderStatus.pending && r.isOverdue(now),
                )
                .toList();
            final upcoming = items
                .where(
                  (r) =>
                      !(r.status == ReminderStatus.pending && r.isOverdue(now)),
                )
                .take(_upcomingLimit)
                .toList();
            return _HomeContent(
              now: now,
              overdue: overdue,
              upcoming: upcoming,
              todayCount: items.where((r) => r.dueAt.isSameDay(now)).length,
            );
          },
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.now,
    required this.overdue,
    required this.upcoming,
    required this.todayCount,
  });

  final DateTime now;
  final List<Reminder> overdue;
  final List<Reminder> upcoming;
  final int todayCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = LiquidPalette.of(context);
    // Brasa en oscuro; en claro, un rojo con contraste suficiente.
    final warm = Theme.of(context).brightness == Brightness.dark
        ? p.ember
        : p.danger;
    final greeting = switch (now.hour) {
      < 12 => l10n.greetingMorning,
      < 19 => l10n.greetingAfternoon,
      _ => l10n.greetingEvening,
    };
    final date = DateFormat("EEEE d 'de' MMMM", l10n.localeName).format(now);
    final next = upcoming.isEmpty ? null : upcoming.first;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting, style: context.textTheme.titleMedium),
                  Text(
                    '${date[0].toUpperCase()}${date.substring(1)}',
                    style: context.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            GlassIconButton(
              icon: Icons.tune_rounded,
              tooltip: l10n.navSettings,
              onPressed: () => context.go(AppRoutes.settings),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _Countdown(next: next, now: now),
        const SizedBox(height: 10),
        Text(
          l10n.homeTodaySummary(todayCount),
          style: context.textTheme.bodyLarge,
        ),
        if (overdue.isNotEmpty)
          Text(
            l10n.homeOverdueSummary(overdue.length),
            style: context.textTheme.bodyMedium?.copyWith(color: warm),
          ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _Pill(
              icon: Icons.graphic_eq_rounded,
              label: l10n.homeYourDay,
              onTap: () =>
                  unawaited(showVoiceAssistant(context, briefing: true)),
            ),
            Tooltip(
              message: l10n.newReminder,
              child: _Pill(
                icon: Icons.add_rounded,
                label: l10n.homeNew,
                onTap: () => unawaited(context.push(AppRoutes.newReminder())),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const AlertPermissionsBanner(),
        const _VoiceSetupCard(),
        const RoutineSuggestionCard(),
        if (overdue.isNotEmpty) ...[
          SectionHeader(
            l10n.homeSectionOverdue,
            color: warm,
            trailing: const _MoveToTomorrowButton(),
          ),
          for (final reminder in overdue)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ReminderTile(reminder: reminder),
            ),
        ],
        SectionHeader(
          l10n.homeSectionUpcoming,
          trailing: TextButton(
            onPressed: () => context.go(AppRoutes.reminders),
            child: Text(l10n.homeSeeAll),
          ),
        ),
        if (upcoming.isEmpty && overdue.isEmpty)
          EmptyState(
            icon: Icons.wb_sunny_outlined,
            title: l10n.homeEmptyTitle,
            message: l10n.homeEmptyBody,
          )
        else
          _River(items: upcoming, now: now),
      ],
    );
  }
}

/// «Faltan 2:14 h» para lo próximo, en números grandes y de ancho fijo.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.next, required this.now});

  final Reminder? next;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = LiquidPalette.of(context);
    final display = context.textTheme.displayLarge!;
    final reminder = next;
    if (reminder == null) {
      return Text(l10n.homeFree, style: display);
    }
    final diff = reminder.shownAt.difference(now);
    final (value, unit) = switch (diff) {
      _ when diff.inMinutes < 1 => (l10n.homeNow, ''),
      _ when diff.inMinutes < 60 => ('${diff.inMinutes}', 'min'),
      _ when diff.inHours < 24 => (
        '${diff.inHours}:${(diff.inMinutes % 60).toString().padLeft(2, '0')}',
        'h',
      ),
      _ => ('${diff.inDays}', diff.inDays == 1 ? l10n.homeDay : l10n.homeDays),
    };
    return Semantics(
      label: '${l10n.homeUntilNext}: $value $unit, ${reminder.title}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.homeUntilNext, style: context.textTheme.bodyMedium),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: AppTheme.monoStyle(display)),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    unit,
                    style: context.textTheme.headlineSmall?.copyWith(
                      color: p.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            reminder.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.headlineSmall,
          ),
        ],
      ),
    );
  }
}

/// Lo que viene, como un río: la hora a la izquierda, un eje fino y cada
/// recordatorio como una gota de vidrio. Arriba, la línea de «ahora».
class _River extends StatelessWidget {
  const _River({required this.items, required this.now});

  final List<Reminder> items;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final p = LiquidPalette.of(context);
    final mono = AppTheme.monoStyle(context.textTheme.labelSmall);
    String label(DateTime at) {
      final time = DateFormat.Hm().format(at);
      if (at.isSameDay(now)) return time;
      return '${DateFormat('E d', 'es').format(at)}\n$time';
    }

    return Stack(
      children: [
        Positioned(
          left: 60,
          top: 4,
          bottom: 0,
          child: Container(
            width: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [p.accent, p.hairline, Colors.transparent],
                stops: const [0, 0.15, 1],
              ),
            ),
          ),
        ),
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      DateFormat.Hm().format(now),
                      style: mono.copyWith(color: p.accentText),
                    ),
                  ),
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: p.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [p.accent, Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (final reminder in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 52,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Text(
                          label(reminder.shownAt),
                          style: mono,
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(child: ReminderTile(reminder: reminder)),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PressScale(
    onTap: onTap,
    semanticLabel: label,
    child: LiquidGlass(
      radius: LiquidRadius.pill,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 19),
          const SizedBox(width: 8),
          Text(label, style: context.textTheme.labelLarge),
        ],
      ),
    ),
  );
}

/// La activación con «Viernes» está pedida pero falta registrar la voz
/// (p. ej. al actualizar desde una versión sin registro de voz).
class _VoiceSetupCard extends ConsumerWidget {
  const _VoiceSetupCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wanted = ref.watch(
      settingsControllerProvider.select((s) => s.wakeWordEnabled),
    );
    final status = ref.watch(voiceProfileStatusProvider).value;
    if (!wanted || status == null || status.enrolled) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: PressScale(
        onTap: () => unawaited(context.push(AppRoutes.voiceEnrollment)),
        semanticLabel: l10n.homeVoiceSetup,
        child: LiquidGlass(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.record_voice_over_rounded,
                color: LiquidPalette.of(context).accentText,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.homeVoiceSetup,
                      style: context.textTheme.titleMedium,
                    ),
                    Text(
                      l10n.homeVoiceSetupBody,
                      style: context.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

/// «Pasar a mañana»: mueve los vencidos que no se repiten al día siguiente.
class _MoveToTomorrowButton extends ConsumerWidget {
  const _MoveToTomorrowButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return TextButton.icon(
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final result = await ref.read(moveOverdueToTomorrowProvider)();
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                result.fold(
                  l10n.feedbackMovedToTomorrow,
                  (failure) => failure.message,
                ),
              ),
            ),
          );
      },
      icon: const Icon(Icons.east, size: 18),
      label: Text(l10n.homeMoveToTomorrow),
    );
  }
}
