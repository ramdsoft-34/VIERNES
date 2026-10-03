import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/app/router/routes.dart';
import 'package:viernes/core/extensions/context_x.dart';
import 'package:viernes/core/utils/date_x.dart';
import 'package:viernes/core/widgets/async_value_view.dart';
import 'package:viernes/core/widgets/empty_state.dart';
import 'package:viernes/core/widgets/section_header.dart';
import 'package:viernes/features/alerts/presentation/permissions_widgets.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/presentation/providers/reminder_providers.dart';
import 'package:viernes/features/reminders/presentation/widgets/reminder_tile.dart';
import 'package:viernes/features/voice_assistant/presentation/voice_button.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _upcomingLimit = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider).value ?? DateTime.now();
    final reminders = ref.watch(activeRemindersProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: context.l10n.newReminder,
        onPressed: () => unawaited(context.push(AppRoutes.newReminder())),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: AsyncValueView(
          value: reminders,
          data: (items) => _HomeContent(
            now: now,
            overdue: items
                .where(
                  (r) => r.status == ReminderStatus.pending && r.isOverdue(now),
                )
                .toList(),
            upcoming: items
                .where(
                  (r) =>
                      !(r.status == ReminderStatus.pending && r.isOverdue(now)),
                )
                .take(_upcomingLimit)
                .toList(),
            todayCount: items.where((r) => r.dueAt.isSameDay(now)).length,
          ),
        ),
      ),
    );
  }
}

/// "Pasar a mañana": mueve los vencidos que no se repiten al día siguiente.
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
    final greeting = switch (now.hour) {
      < 12 => l10n.greetingMorning,
      < 19 => l10n.greetingAfternoon,
      _ => l10n.greetingEvening,
    };
    final date = DateFormat("EEEE d 'de' MMMM", l10n.localeName).format(now);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Text(
          greeting,
          style: context.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          '${date[0].toUpperCase()}${date.substring(1)}',
          style: context.textTheme.bodyLarge?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        const AlertPermissionsBanner(),
        _SummaryCard(todayCount: todayCount, overdueCount: overdue.length),
        const SizedBox(height: 12),
        const VoiceButton(),
        if (overdue.isNotEmpty) ...[
          SectionHeader(
            l10n.homeSectionOverdue,
            color: context.colors.error,
            trailing: const _MoveToTomorrowButton(),
          ),
          for (final reminder in overdue)
            _spaced(ReminderTile(reminder: reminder)),
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
          for (final reminder in upcoming)
            _spaced(ReminderTile(reminder: reminder)),
      ],
    );
  }

  Widget _spaced(Widget child) =>
      Padding(padding: const EdgeInsets.only(bottom: 8), child: child);
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.todayCount, required this.overdueCount});

  final int todayCount;
  final int overdueCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    return Card(
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.today_outlined, color: colors.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.homeTodaySummary(todayCount),
                    style: context.textTheme.titleMedium?.copyWith(
                      color: colors.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (overdueCount > 0)
                    Text(
                      l10n.homeOverdueSummary(overdueCount),
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: colors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
