import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/app/router/routes.dart';
import 'package:viernes/core/extensions/context_x.dart';
import 'package:viernes/core/widgets/empty_state.dart';
import 'package:viernes/core/widgets/liquid.dart';
import 'package:viernes/features/places/domain/place.dart';
import 'package:viernes/features/places/presentation/places_providers.dart';
import 'package:viernes/features/places/presentation/places_screen.dart';

/// Recordatorios que avisan al llegar a un lugar o al salir de él.
class LocationRemindersScreen extends ConsumerWidget {
  const LocationRemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final reminders =
        ref.watch(locationRemindersProvider).value ??
        const <LocationReminder>[];
    final places = {
      for (final p in ref.watch(placesProvider).value ?? const <Place>[])
        p.id: p,
    };
    final repository = ref.read(placesRepositoryProvider);
    return LiquidScaffold(
      appBar: AppBar(
        title: Text(l10n.locationRemindersTitle),
        actions: [
          IconButton(
            tooltip: l10n.placesTitle,
            icon: const Icon(Icons.map_outlined),
            onPressed: () => unawaited(context.push(AppRoutes.places)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => unawaited(_add(context, ref)),
        icon: const Icon(Icons.add),
        label: Text(l10n.locationRemindersAdd),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          const LocationPermissionCard(),
          if (reminders.isEmpty)
            EmptyState(
              icon: Icons.location_on_outlined,
              title: l10n.locationRemindersEmpty,
              message: l10n.locationRemindersEmptySubtitle,
            )
          else
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final r in reminders)
                    CheckboxListTile(
                      value: r.done,
                      onChanged: (value) => unawaited(
                        repository.setDone(
                          r.id,
                          done: value ?? false,
                          at: ref.read(clockProvider).now(),
                        ),
                      ),
                      title: Text(
                        r.title,
                        style: r.done
                            ? const TextStyle(
                                decoration: TextDecoration.lineThrough,
                              )
                            : null,
                      ),
                      subtitle: Text(
                        r.onArrive
                            ? l10n.locationOnArrive(
                                places[r.placeId]?.name ?? '?',
                              )
                            : l10n.locationOnLeave(
                                places[r.placeId]?.name ?? '?',
                              ),
                      ),
                      secondary: IconButton(
                        tooltip: l10n.actionDelete,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () =>
                            unawaited(repository.deleteReminder(r.id)),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final places = ref.read(placesProvider).value ?? const <Place>[];
    if (places.isEmpty) {
      await showAddPlaceDialog(context, ref);
      return;
    }
    final result = await showDialog<LocationReminder>(
      context: context,
      builder: (context) => _AddLocationReminderDialog(
        places: places,
        newId: ref.read(idGeneratorProvider).next,
        now: ref.read(clockProvider).now,
      ),
    );
    if (result != null) {
      await ref.read(placesRepositoryProvider).saveReminder(result);
    }
  }
}

class _AddLocationReminderDialog extends StatefulWidget {
  const _AddLocationReminderDialog({
    required this.places,
    required this.newId,
    required this.now,
  });

  final List<Place> places;
  final String Function() newId;
  final DateTime Function() now;

  @override
  State<_AddLocationReminderDialog> createState() =>
      _AddLocationReminderDialogState();
}

class _AddLocationReminderDialogState
    extends State<_AddLocationReminderDialog> {
  final _title = TextEditingController();
  late String _placeId = widget.places.first.id;
  bool _onArrive = true;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.locationRemindersAdd),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l10n.fieldTitle),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _placeId,
            decoration: InputDecoration(labelText: l10n.placesTitle),
            items: [
              for (final p in widget.places)
                DropdownMenuItem(value: p.id, child: Text(p.name)),
            ],
            onChanged: (value) => setState(() => _placeId = value ?? _placeId),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: true, label: Text(l10n.locationArrive)),
              ButtonSegment(value: false, label: Text(l10n.locationLeave)),
            ],
            selected: {_onArrive},
            onSelectionChanged: (s) => setState(() => _onArrive = s.first),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () {
            final title = _title.text.trim();
            if (title.isEmpty) return;
            Navigator.of(context).pop(
              LocationReminder(
                id: widget.newId(),
                title: title,
                placeId: _placeId,
                onArrive: _onArrive,
                createdAt: widget.now(),
              ),
            );
          },
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
