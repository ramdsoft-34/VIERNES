import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/app/router/routes.dart';
import 'package:viernes/app/theme/app_theme.dart';
import 'package:viernes/core/extensions/context_x.dart';
import 'package:viernes/core/widgets/liquid.dart';
import 'package:viernes/features/attachments/presentation/attachment_providers.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/presentation/reminder_actions.dart';
import 'package:viernes/features/reminders/presentation/reminder_formatters.dart';

/// Tarjeta de un recordatorio. Deslizar a la derecha lo completa; a la
/// izquierda lo elimina (con deshacer).
class ReminderTile extends ConsumerWidget {
  const ReminderTile({required this.reminder, this.occurrenceAt, super.key});

  final Reminder reminder;

  /// Fecha a mostrar cuando es una ocurrencia futura de un recordatorio
  /// repetitivo (calendario).
  final DateTime? occurrenceAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider).value ?? DateTime.now();
    final l10n = context.l10n;
    final colors = context.colors;
    final done = reminder.status == ReminderStatus.completed;
    final overdue = occurrenceAt == null && reminder.isOverdue(now);
    final date = occurrenceAt ?? reminder.dueAt;
    final hasAttachments =
        ref
            .watch(remindersWithAttachmentsProvider)
            .value
            ?.contains(reminder.id) ??
        false;

    // Gota de vidrio «quieto»: sin desenfoque real para que las listas
    // largas sigan fluidas; el fondo de luz se ve a través.
    final card = PressScale(
      scale: 0.97,
      onTap: () => context.push(AppRoutes.editReminder(reminder.id)),
      child: LiquidGlass(
        blur: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 2, 10),
          child: Row(
            children: [
              _CompleteButton(reminder: reminder),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.titleMedium?.copyWith(
                        decoration: done ? TextDecoration.lineThrough : null,
                        color: done ? colors.onSurfaceVariant : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _Meta(
                          icon: Icons.schedule,
                          label: l10n.dayAndTime(date, now),
                          color: overdue ? colors.error : null,
                        ),
                        if (overdue)
                          _Badge(
                            label: l10n.statusOverdue,
                            color: colors.error,
                          ),
                        if (reminder.status == ReminderStatus.snoozed &&
                            reminder.snoozedUntil != null)
                          _Meta(
                            icon: Icons.snooze,
                            label: l10n.statusSnoozedUntil(
                              l10n.time(reminder.snoozedUntil!),
                            ),
                            color: colors.tertiary,
                          ),
                        if (reminder.recurrence.repeats)
                          _Meta(
                            icon: Icons.repeat,
                            label: l10n.recurrence(reminder.recurrence),
                          ),
                        if (reminder.category != ReminderCategory.other)
                          _Meta(
                            icon: reminder.category.icon,
                            label: l10n.category(reminder.category),
                          ),
                        if (reminder.priority.isAtLeastHigh)
                          _Badge(
                            label: l10n.priority(reminder.priority),
                            color: reminder.priority.color(colors),
                          ),
                        if (hasAttachments)
                          Icon(
                            Icons.attach_file,
                            size: 16,
                            semanticLabel: l10n.attachTitle,
                            color: colors.onSurfaceVariant,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              _MoreMenu(reminder: reminder),
            ],
          ),
        ),
      ),
    );

    if (!reminder.isActive) return card;

    return Dismissible(
      key: ValueKey('dismiss-${reminder.id}-${occurrenceAt ?? ''}'),
      background: _SwipeBackground(
        alignment: Alignment.centerLeft,
        color: LiquidPalette.of(context).volt,
        icon: Icons.check,
        label: l10n.actionComplete,
      ),
      secondaryBackground: _SwipeBackground(
        alignment: Alignment.centerRight,
        color: colors.error,
        icon: Icons.delete_outline,
        label: l10n.actionDelete,
      ),
      // La lista se actualiza sola desde la base de datos; devolver `false`
      // evita que el widget quede "descartado" mientras llega el cambio.
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await ReminderActions.complete(context, ref, reminder);
        } else {
          await ReminderActions.delete(context, ref, reminder);
        }
        return false;
      },
      child: card,
    );
  }
}

class _CompleteButton extends ConsumerWidget {
  const _CompleteButton({required this.reminder});

  final Reminder reminder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = reminder.status == ReminderStatus.completed;
    final p = LiquidPalette.of(context);
    final ring = reminder.priority.isAtLeastHigh
        ? reminder.priority.color(context.colors)
        : p.textMuted;
    final label = done
        ? context.l10n.actionReopen
        : context.l10n.actionComplete;
    return Tooltip(
      message: label,
      child: PressScale(
        scale: 0.85,
        haptic: !done,
        semanticLabel: label,
        onTap: () => unawaited(
          done
              ? ReminderActions.reopen(context, ref, reminder)
              : ReminderActions.complete(context, ref, reminder),
        ),
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: AnimatedContainer(
              duration: LiquidMotion.of(context, LiquidMotion.medium),
              curve: LiquidMotion.spring,
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? p.volt : Colors.transparent,
                border: Border.all(
                  color: done ? p.volt : ring,
                  width: 1.6,
                ),
              ),
              child: done
                  ? Icon(Icons.check_rounded, size: 16, color: p.onVolt)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

enum _MenuAction { complete, snooze, reopen, edit, delete }

class _MoreMenu extends ConsumerWidget {
  const _MoreMenu({required this.reminder});

  final Reminder reminder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return PopupMenuButton<_MenuAction>(
      tooltip: l10n.actionMore,
      onSelected: (action) => unawaited(switch (action) {
        _MenuAction.complete => ReminderActions.complete(
          context,
          ref,
          reminder,
        ),
        _MenuAction.snooze => ReminderActions.snooze(context, ref, reminder),
        _MenuAction.reopen => ReminderActions.reopen(context, ref, reminder),
        _MenuAction.edit => context.push(
          AppRoutes.editReminder(reminder.id),
        ),
        _MenuAction.delete => ReminderActions.confirmAndDelete(
          context,
          ref,
          reminder,
        ),
      }),
      itemBuilder: (context) => [
        if (reminder.isActive) ...[
          _item(_MenuAction.complete, Icons.check, l10n.actionComplete),
          _item(_MenuAction.snooze, Icons.snooze, l10n.actionSnooze),
        ] else
          _item(_MenuAction.reopen, Icons.undo, l10n.actionReopen),
        _item(_MenuAction.edit, Icons.edit_outlined, l10n.actionEdit),
        _item(_MenuAction.delete, Icons.delete_outline, l10n.actionDelete),
      ],
    );
  }

  PopupMenuItem<_MenuAction> _item(
    _MenuAction value,
    IconData icon,
    String label,
  ) => PopupMenuItem(
    value: value,
    child: ListTile(
      leading: Icon(icon),
      title: Text(label),
      contentPadding: EdgeInsets.zero,
    ),
  );
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effective = color ?? context.colors.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: effective),
        const SizedBox(width: 3),
        Text(
          label,
          style: context.textTheme.bodySmall?.copyWith(color: effective),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LiquidTag(label, color: color);
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final foreground = color.computeLuminance() > 0.5
        ? const Color(0xFF1B2205)
        : Colors.white;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(LiquidRadius.md),
      ),
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foreground),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
