import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/core/extensions/context_x.dart';
import 'package:viernes/core/utils/date_x.dart';
import 'package:viernes/core/widgets/async_value_view.dart';
import 'package:viernes/core/widgets/empty_state.dart';
import 'package:viernes/core/widgets/section_header.dart';
import 'package:viernes/features/history/domain/history_stats.dart';
import 'package:viernes/features/history/presentation/history_providers.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_event.dart';
import 'package:viernes/features/reminders/presentation/reminder_formatters.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  static const _recentLimit = 100;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final now = ref.watch(nowProvider).value ?? DateTime.now();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navHistory)),
      body: AsyncValueView(
        value: ref.watch(historyEventsProvider),
        data: (events) {
          if (events.isEmpty) {
            return EmptyState(
              icon: Icons.insights,
              title: l10n.historyEmptyTitle,
              message: l10n.historyEmptyBody,
            );
          }
          final stats = HistoryStats.from(events, now);
          final recent = events.take(_recentLimit).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              SectionHeader(l10n.historyProgress),
              _StatsGrid(stats: stats),
              SectionHeader(l10n.historyLast7Days),
              _WeekChart(values: stats.dailyCompletions, today: now),
              if (stats.mostSnoozed.isNotEmpty) ...[
                SectionHeader(l10n.historyMostSnoozed),
                Card(
                  child: Column(
                    children: [
                      for (final (title, count) in stats.mostSnoozed)
                        ListTile(
                          leading: Icon(
                            Icons.snooze,
                            color: context.colors.onSurfaceVariant,
                          ),
                          title: Text(title),
                          trailing: Text(l10n.historySnoozedTimes(count)),
                        ),
                    ],
                  ),
                ),
              ],
              SectionHeader(l10n.historyRecent),
              Card(
                child: Column(
                  children: [
                    for (final (index, event) in recent.indexed) ...[
                      if (index > 0) const Divider(height: 1, indent: 56),
                      _EventTile(event: event, now: now),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Barras de completados por día (una sola serie: un color, sin leyenda).
class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.values, required this.today});

  /// Del más antiguo (hace 6 días) a hoy.
  final List<int> values;
  final DateTime today;

  static const _chartHeight = 96.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final maxValue = values.fold<int>(0, (a, b) => a > b ? a : b);
    final days = [
      for (var i = 0; i < values.length; i++)
        today.startOfDay.addDays(i - (values.length - 1)),
    ];
    final description = [
      for (var i = 0; i < values.length; i++)
        '${l10n.weekdayShort(days[i].weekday)}: ${values[i]}',
    ].join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Semantics(
          label: '${l10n.historyLast7Days}. $description',
          excludeSemantics: true,
          child: Column(
            children: [
              SizedBox(
                height: _chartHeight + 20,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < values.length; i++)
                      Expanded(
                        child: Tooltip(
                          message:
                              '${l10n.relativeDay(days[i], today)}: '
                              '${values[i]}',
                          triggerMode: TooltipTriggerMode.tap,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Etiqueta solo en el día de hoy y en el máximo.
                              if (values[i] > 0 &&
                                  (i == values.length - 1 ||
                                      values[i] == maxValue))
                                Text(
                                  '${values[i]}',
                                  style: context.textTheme.labelSmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Container(
                                width: 18,
                                height: maxValue == 0
                                    ? 2
                                    : (values[i] / maxValue * _chartHeight)
                                          .clamp(2, _chartHeight),
                                decoration: BoxDecoration(
                                  color: values[i] == 0
                                      ? colors.outlineVariant
                                      : colors.primary,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.outlineVariant),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (var i = 0; i < values.length; i++)
                    Expanded(
                      child: Text(
                        l10n.weekdayShort(days[i].weekday),
                        textAlign: TextAlign.center,
                        style: context.textTheme.labelSmall?.copyWith(
                          color: i == values.length - 1
                              ? colors.onSurface
                              : colors.onSurfaceVariant,
                          fontWeight: i == values.length - 1
                              ? FontWeight.w700
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final HistoryStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onTime = stats.onTimeRate;
    final cards = [
      _StatCard(
        icon: Icons.task_alt,
        label: l10n.statCompletedWeek,
        value: '${stats.completedThisWeek}',
      ),
      _StatCard(
        icon: Icons.local_fire_department_outlined,
        label: l10n.statStreak,
        value: l10n.statDays(stats.currentStreak),
      ),
      _StatCard(
        icon: Icons.emoji_events_outlined,
        label: l10n.statBestStreak,
        value: l10n.statDays(stats.bestStreak),
      ),
      _StatCard(
        icon: Icons.timer_outlined,
        label: l10n.statOnTime,
        value: onTime == null ? '—' : '${(onTime * 100).round()} %',
      ),
      _StatCard(
        icon: Icons.snooze,
        label: l10n.statSnoozed,
        value: '${stats.snoozedLast30Days}',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final columns = constraints.maxWidth > 560 ? 3 : 2;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: context.colors.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.now});

  final ReminderEvent event;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final (icon, color) = switch (event.type) {
      ReminderEventType.completed when event.onTime ?? true => (
        Icons.check_circle,
        Colors.green.shade600,
      ),
      ReminderEventType.completed => (
        Icons.check_circle_outline,
        colors.tertiary,
      ),
      ReminderEventType.snoozed => (Icons.snooze, colors.secondary),
      ReminderEventType.deleted => (Icons.delete_outline, colors.outline),
      _ => (Icons.history, colors.outline),
    };
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        event.reminderTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${l10n.eventType(event.type, onTime: event.onTime)} · '
        '${l10n.dayAndTime(event.occurredAt, now)}',
      ),
    );
  }
}
