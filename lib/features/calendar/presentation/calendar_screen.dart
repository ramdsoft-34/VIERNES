import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/app/router/routes.dart';
import 'package:viernes/core/extensions/context_x.dart';
import 'package:viernes/core/platform/device_data.dart';
import 'package:viernes/core/utils/date_x.dart';
import 'package:viernes/core/widgets/async_value_view.dart';
import 'package:viernes/core/widgets/empty_state.dart';
import 'package:viernes/features/calendar/domain/calendar_occurrences.dart';
import 'package:viernes/features/device/device_providers.dart';
import 'package:viernes/features/reminders/presentation/providers/reminder_providers.dart';
import 'package:viernes/features/reminders/presentation/reminder_formatters.dart';
import 'package:viernes/features/reminders/presentation/widgets/reminder_tile.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _focused;
  late DateTime _selected;
  CalendarFormat _format = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _focused = _selected = ref.read(clockProvider).now().startOfDay;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = ref.watch(nowProvider).value ?? DateTime.now();
    // Rango visible con margen para las semanas de meses vecinos.
    final from = DateTime(_focused.year, _focused.month - 1, 20);
    final to = DateTime(_focused.year, _focused.month + 1, 12);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navCalendar),
        actions: [
          IconButton(
            tooltip: l10n.dateToday,
            icon: const Icon(Icons.today),
            onPressed: () =>
                setState(() => _focused = _selected = now.startOfDay),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => unawaited(
          context.push(AppRoutes.newReminder(date: _selected)),
        ),
        icon: const Icon(Icons.add),
        label: Text(l10n.calendarAddForDay),
      ),
      body: AsyncValueView(
        value: ref.watch(allRemindersProvider),
        data: (reminders) {
          final byDay = CalendarOccurrences.expand(reminders, from, to);
          final dayItems = byDay[_selected.startOfDay] ?? const [];
          final phoneEvents =
              ref.watch(calendarDayEventsProvider(_selected)).value ??
              const <CalendarEvent>[];
          // Calendario y lista en un solo desplazamiento: en pantallas bajas el
          // calendario mensual ocupa casi todo el alto.
          return ListView(
            children: [
              TableCalendar<Occurrence>(
                locale: l10n.localeName,
                firstDay: DateTime(now.year - 2),
                lastDay: DateTime(now.year + 5, 12, 31),
                focusedDay: _focused,
                calendarFormat: _format,
                startingDayOfWeek: StartingDayOfWeek.monday,
                availableCalendarFormats: {
                  CalendarFormat.month: l10n.calendarMonth,
                  CalendarFormat.twoWeeks: l10n.calendarTwoWeeks,
                  CalendarFormat.week: l10n.calendarWeek,
                },
                selectedDayPredicate: (day) => day.isSameDay(_selected),
                eventLoader: (day) => byDay[day.startOfDay] ?? const [],
                onDaySelected: (selected, focused) => setState(() {
                  _selected = selected.startOfDay;
                  _focused = focused;
                }),
                onPageChanged: (focused) => setState(() => _focused = focused),
                onFormatChanged: (format) => setState(() => _format = format),
                headerStyle: const HeaderStyle(titleCentered: true),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: context.colors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: TextStyle(
                    color: context.colors.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: context.colors.primary,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color: context.colors.tertiary,
                    shape: BoxShape.circle,
                  ),
                  markersMaxCount: 3,
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.relativeDay(_selected, now),
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              // Eventos del calendario del teléfono (solo lectura).
              for (final event in phoneEvents)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Card(
                    color: context.colors.surfaceContainerHighest,
                    child: ListTile(
                      leading: const Icon(Icons.event_note_outlined),
                      title: Text(event.title),
                      subtitle: Text(
                        [
                          if (event.allDay)
                            l10n.calendarAllDay
                          else
                            l10n.time(event.start),
                          ?event.location,
                          l10n.calendarFromPhone,
                        ].join(' · '),
                      ),
                    ),
                  ),
                ),
              if (dayItems.isEmpty && phoneEvents.isEmpty)
                EmptyState(
                  icon: Icons.event_available,
                  title: l10n.calendarEmptyDay,
                )
              else
                for (final occurrence in dayItems)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: ReminderTile(
                      reminder: occurrence.reminder,
                      occurrenceAt: occurrence.isProjected
                          ? occurrence.at
                          : null,
                    ),
                  ),
              // Espacio para que el botón flotante no tape el último elemento.
              const SizedBox(height: 88),
            ],
          );
        },
      ),
    );
  }
}
