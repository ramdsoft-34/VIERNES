import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:viernes/app/router/routes.dart';
import 'package:viernes/app/theme/app_theme.dart';
import 'package:viernes/core/extensions/context_x.dart';
import 'package:viernes/core/widgets/async_value_view.dart';
import 'package:viernes/core/widgets/empty_state.dart';
import 'package:viernes/core/widgets/liquid.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/presentation/providers/reminder_providers.dart';
import 'package:viernes/features/reminders/presentation/reminder_formatters.dart';
import 'package:viernes/features/reminders/presentation/widgets/reminder_tile.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 3,
      child: LiquidScaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: LiquidHeader(
                  title: l10n.remindersHeader,
                  actions: [
                    GlassIconButton(
                      icon: Icons.group_outlined,
                      tooltip: l10n.sharingTitle,
                      onPressed: () =>
                          unawaited(context.push(AppRoutes.sharing)),
                    ),
                    GlassIconButton(
                      icon: Icons.location_on_outlined,
                      tooltip: l10n.locationRemindersTitle,
                      onPressed: () =>
                          unawaited(context.push(AppRoutes.locationReminders)),
                    ),
                    GlassIconButton(
                      icon: Icons.add_rounded,
                      tooltip: l10n.newReminder,
                      onPressed: () =>
                          unawaited(context.push(AppRoutes.newReminder())),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LiquidGlass(
                  radius: LiquidRadius.pill,
                  padding: const EdgeInsets.all(4),
                  child: SizedBox(
                    height: 40,
                    child: TabBar(
                      tabs: [
                        Tab(text: l10n.remindersTabPending),
                        Tab(text: l10n.remindersTabSnoozed),
                        Tab(text: l10n.remindersTabCompleted),
                      ],
                    ),
                  ),
                ),
              ),
              const _CategoryFilter(),
              Expanded(
                child: TabBarView(
                  children: [
                    _StatusList(
                      status: ReminderStatus.pending,
                      emptyIcon: Icons.checklist,
                      emptyTitle: l10n.remindersEmptyPendingTitle,
                      emptyBody: l10n.remindersEmptyPendingBody,
                    ),
                    _StatusList(
                      status: ReminderStatus.snoozed,
                      emptyIcon: Icons.snooze,
                      emptyTitle: l10n.remindersEmptySnoozedTitle,
                      emptyBody: l10n.remindersEmptySnoozedBody,
                    ),
                    _StatusList(
                      status: ReminderStatus.completed,
                      emptyIcon: Icons.task_alt,
                      emptyTitle: l10n.remindersEmptyCompletedTitle,
                      emptyBody: l10n.remindersEmptyCompletedBody,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Categoría elegida en el filtro (`null` = todas).
final NotifierProvider<CategoryFilter, ReminderCategory?>
categoryFilterProvider = NotifierProvider<CategoryFilter, ReminderCategory?>(
  CategoryFilter.new,
);

class CategoryFilter extends Notifier<ReminderCategory?> {
  @override
  ReminderCategory? build() => null;

  // Un método se lee mejor en los callbacks de los chips.
  // ignore: use_setters_to_change_properties
  void select(ReminderCategory? category) => state = category;
}

class _CategoryFilter extends ConsumerWidget {
  const _CategoryFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selected = ref.watch(categoryFilterProvider);
    final filter = ref.read(categoryFilterProvider.notifier);
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(l10n.remindersFilterAll),
              selected: selected == null,
              onSelected: (_) => filter.select(null),
            ),
          ),
          for (final category in ReminderCategory.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                avatar: Icon(category.icon, size: 18),
                label: Text(l10n.category(category)),
                selected: selected == category,
                onSelected: (isSelected) =>
                    filter.select(isSelected ? category : null),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusList extends ConsumerWidget {
  const _StatusList({
    required this.status,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyBody,
  });

  final ReminderStatus status;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyBody;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(categoryFilterProvider);
    return AsyncValueView(
      value: ref.watch(remindersByStatusProvider(status)),
      data: (all) {
        final items = category == null
            ? all
            : all.where((r) => r.category == category).toList();
        if (items.isEmpty) {
          return EmptyState(
            icon: emptyIcon,
            title: emptyTitle,
            message: emptyBody,
          );
        }
        final sorted = status == ReminderStatus.completed
            ? _byCompletionDesc(items)
            : items;
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(
            16,
            4,
            16,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          itemCount: sorted.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) =>
              ReminderTile(reminder: sorted[index]),
        );
      },
    );
  }

  List<Reminder> _byCompletionDesc(List<Reminder> items) => [...items]
    ..sort(
      (a, b) => (b.completedAt ?? b.updatedAt).compareTo(
        a.completedAt ?? a.updatedAt,
      ),
    );
}
