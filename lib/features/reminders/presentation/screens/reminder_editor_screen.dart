import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viernes/ai/ai_providers.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/app/theme/app_theme.dart';
import 'package:viernes/core/error/failure.dart';
import 'package:viernes/core/error/result.dart';
import 'package:viernes/core/extensions/context_x.dart';
import 'package:viernes/core/utils/date_x.dart';
import 'package:viernes/core/widgets/empty_state.dart';
import 'package:viernes/features/reminders/domain/entities/recurrence.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_draft.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/domain/usecases/reminder_validator.dart';
import 'package:viernes/features/reminders/presentation/providers/reminder_providers.dart';
import 'package:viernes/features/reminders/presentation/reminder_actions.dart';
import 'package:viernes/features/reminders/presentation/reminder_formatters.dart';
import 'package:viernes/features/settings/domain/app_settings.dart';
import 'package:viernes/features/settings/presentation/settings_controller.dart';

/// Crear (sin [reminderId]) o editar un recordatorio.
class ReminderEditorScreen extends ConsumerStatefulWidget {
  const ReminderEditorScreen({
    this.reminderId,
    this.initialDate,
    this.initialDraft,
    super.key,
  });

  final String? reminderId;
  final DateTime? initialDate;

  /// Datos precargados (p. ej. lo que entendió Viernes por voz).
  final ReminderDraft? initialDraft;

  bool get isNew => reminderId == null;

  @override
  ConsumerState<ReminderEditorScreen> createState() =>
      _ReminderEditorScreenState();
}

class _ReminderEditorScreenState extends ConsumerState<ReminderEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _notes = TextEditingController();

  bool _initialized = false;
  bool _saving = false;
  Reminder? _original;

  late DateTime _date;
  late TimeOfDay _time;
  late Duration _leadTime;
  RecurrenceFrequency _frequency = RecurrenceFrequency.none;
  Set<int> _weekdays = {};
  ReminderPriority _priority = ReminderPriority.normal;
  ReminderCategory _category = ReminderCategory.other;

  /// Repetición de partida, para conservar el intervalo ("cada 3 días")
  /// que el formulario no muestra.
  Recurrence? _initialRecurrence;

  /// Si el usuario eligió la categoría, Viernes deja de sugerirla.
  bool _categoryTouched = false;

  /// Sugiere la categoría mientras se escribe (reglas + lo aprendido).
  void _suggestCategory(String title) {
    if (!widget.isNew || _categoryTouched || widget.initialDraft != null) {
      return;
    }
    final suggested = ref.read(categoryPredictorProvider)(title);
    if (suggested != _category) setState(() => _category = suggested);
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _initNew() {
    final now = ref.read(clockProvider).now();
    // Por defecto: la próxima hora en punto.
    final nextHour = DateTime(now.year, now.month, now.day, now.hour + 1);
    final day = widget.initialDate;
    _date = day != null && !day.isSameDay(now) ? day : nextHour.startOfDay;
    _time = TimeOfDay(hour: nextHour.hour, minute: 0);
    _leadTime = ref.read(settingsControllerProvider).defaultLeadTime;
    final draft = widget.initialDraft;
    if (draft != null) {
      _title.text = draft.title;
      _notes.text = draft.notes ?? '';
      _date = draft.dueAt.startOfDay;
      _time = TimeOfDay.fromDateTime(draft.dueAt);
      _leadTime = draft.leadTime;
      _setRecurrence(draft.recurrence);
      _priority = draft.priority;
      _category = draft.category;
    }
    _initialized = true;
  }

  void _setRecurrence(Recurrence recurrence) {
    _initialRecurrence = recurrence;
    _frequency = recurrence.frequency;
    _weekdays = {...recurrence.weekdays};
  }

  void _initFrom(Reminder reminder) {
    _original = reminder;
    _title.text = reminder.title;
    _notes.text = reminder.notes ?? '';
    _date = reminder.dueAt.startOfDay;
    _time = TimeOfDay.fromDateTime(reminder.dueAt);
    _leadTime = reminder.leadTime;
    _setRecurrence(reminder.recurrence);
    _priority = reminder.priority;
    _category = reminder.category;
    _initialized = true;
  }

  DateTime get _dueAt => _date.withTime(_time.hour, _time.minute);

  Recurrence get _recurrence {
    final interval = _initialRecurrence?.frequency == _frequency
        ? _initialRecurrence!.interval
        : 1;
    return switch (_frequency) {
      RecurrenceFrequency.none => Recurrence.none,
      RecurrenceFrequency.daily => Recurrence(
        frequency: RecurrenceFrequency.daily,
        interval: interval,
      ),
      RecurrenceFrequency.weekdays => Recurrence.weekdaysOnly,
      RecurrenceFrequency.weekly => Recurrence.weekly(
        _weekdays.isEmpty ? {_dueAt.weekday} : _weekdays,
        interval: interval,
      ),
      RecurrenceFrequency.monthly => Recurrence.monthly(
        _dueAt.day,
        interval: interval,
      ),
      RecurrenceFrequency.yearly => Recurrence.yearly(_dueAt.day),
    };
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final original = _original;

    final Result<Reminder> result;
    if (original == null) {
      result = await ref.read(createReminderProvider)(
        ReminderDraft(
          title: _title.text,
          notes: _notes.text,
          dueAt: _dueAt,
          leadTime: _leadTime,
          recurrence: _recurrence,
          priority: _priority,
          category: _category,
          // Conserva el origen y la frase si vino de una conversación.
          source: widget.initialDraft?.source ?? ReminderSource.manual,
          rawUtterance: widget.initialDraft?.rawUtterance,
          nluConfidence: widget.initialDraft?.nluConfidence,
        ),
      );
    } else {
      result = await ref.read(updateReminderProvider)(
        original.copyWith(
          title: _title.text,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          dueAt: _dueAt,
          leadTime: _leadTime,
          recurrence: _recurrence,
          priority: _priority,
          category: _category,
        ),
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case Ok():
        navigator.pop();
        messenger.showSnackBar(SnackBar(content: Text(l10n.feedbackSaved)));
      case Err(:final failure):
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              failure is ValidationFailure
                  ? failure.message
                  : l10n.errorGeneric,
            ),
          ),
        );
    }
  }

  Future<void> _pickDate() async {
    final now = ref.read(clockProvider).now();
    final first = _date.isBefore(now.startOfDay) ? _date : now.startOfDay;
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: first,
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (!_initialized) {
      if (widget.isNew) {
        _initNew();
      } else {
        final async = ref.watch(reminderByIdProvider(widget.reminderId!));
        final reminder = async.value;
        if (reminder != null) {
          _initFrom(reminder);
        } else {
          return Scaffold(
            appBar: AppBar(),
            body: async.isLoading
                ? const Center(child: CircularProgressIndicator())
                : EmptyState(
                    icon: Icons.search_off,
                    title: l10n.reminderNotFound,
                  ),
          );
        }
      }
    }

    final original = _original;
    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: Text(widget.isNew ? l10n.newReminder : l10n.editReminder),
        actions: [
          if (original != null)
            IconButton(
              tooltip: l10n.actionDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final deleted = await ReminderActions.confirmAndDelete(
                  context,
                  ref,
                  original,
                );
                if (deleted && context.mounted) Navigator.of(context).pop();
              },
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _saving ? null : () => unawaited(_save()),
              child: Text(l10n.actionSave),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            TextFormField(
              controller: _title,
              onChanged: _suggestCategory,
              autofocus: widget.isNew,
              textCapitalization: TextCapitalization.sentences,
              maxLength: ReminderValidator.maxTitleLength,
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
              decoration: InputDecoration(
                labelText: l10n.fieldTitle,
                hintText: l10n.fieldTitleHint,
              ),
              validator: (value) => (value?.trim().isEmpty ?? true)
                  ? l10n.fieldTitleRequired
                  : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PickerTile(
                    icon: Icons.event,
                    label: l10n.fieldDate,
                    value: l10n.relativeDay(
                      _date,
                      ref.read(clockProvider).now(),
                    ),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PickerTile(
                    icon: Icons.schedule,
                    label: l10n.fieldTime,
                    value: l10n.time(_dueAt),
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Duration>(
              initialValue: _leadTime,
              decoration: InputDecoration(
                labelText: l10n.fieldLeadTime,
                prefixIcon: const Icon(Icons.notifications_active_outlined),
              ),
              items: [
                for (final option in {
                  ...AppSettings.leadTimeOptions,
                  _leadTime,
                }.toList()..sort())
                  DropdownMenuItem(
                    value: option,
                    child: Text(l10n.leadTime(option)),
                  ),
              ],
              onChanged: (value) => setState(() => _leadTime = value!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<RecurrenceFrequency>(
              initialValue: _frequency,
              decoration: InputDecoration(
                labelText: l10n.fieldRecurrence,
                prefixIcon: const Icon(Icons.repeat),
              ),
              items: [
                for (final frequency in RecurrenceFrequency.values)
                  DropdownMenuItem(
                    value: frequency,
                    child: Text(l10n.recurrenceFrequency(frequency)),
                  ),
              ],
              onChanged: (value) => setState(() {
                _frequency = value!;
                if (_frequency == RecurrenceFrequency.weekly &&
                    _weekdays.isEmpty) {
                  _weekdays = {_dueAt.weekday};
                }
              }),
            ),
            if (_frequency == RecurrenceFrequency.weekly) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                    FilterChip(
                      label: Text(l10n.weekdayShort(day)),
                      selected: _weekdays.contains(day),
                      onSelected: (selected) => setState(() {
                        _weekdays = {..._weekdays};
                        selected ? _weekdays.add(day) : _weekdays.remove(day);
                      }),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            _Label(l10n.fieldPriority),
            SegmentedButton<ReminderPriority>(
              showSelectedIcon: false,
              segments: [
                for (final priority in ReminderPriority.values)
                  ButtonSegment(
                    value: priority,
                    label: Text(
                      l10n.priority(priority),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              selected: {_priority},
              onSelectionChanged: (selection) =>
                  setState(() => _priority = selection.first),
            ),
            const SizedBox(height: 20),
            _Label(l10n.fieldCategory),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final category in ReminderCategory.values)
                  ChoiceChip(
                    avatar: Icon(category.icon, size: 18),
                    label: Text(l10n.category(category)),
                    selected: _category == category,
                    onSelected: (_) => setState(() {
                      _category = category;
                      _categoryTouched = true;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _notes,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.fieldNotes),
            ),
            if (original != null) ...[
              const SizedBox(height: 24),
              if (original.isActive)
                OutlinedButton.icon(
                  onPressed: () async {
                    await ReminderActions.complete(context, ref, original);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.check),
                  label: Text(l10n.actionComplete),
                )
              else
                OutlinedButton.icon(
                  onPressed: () async {
                    await ReminderActions.reopen(context, ref, original);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.undo),
                  label: Text(l10n.actionReopen),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: context.colors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: context.textTheme.labelSmall),
                    Text(
                      value,
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
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

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(
      text,
      style: context.textTheme.labelLarge?.copyWith(
        color: context.colors.onSurfaceVariant,
      ),
    ),
  );
}
