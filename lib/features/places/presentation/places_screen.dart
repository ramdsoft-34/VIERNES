import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/core/extensions/context_x.dart';
import 'package:viernes/core/widgets/empty_state.dart';
import 'package:viernes/features/places/domain/place.dart';
import 'package:viernes/features/places/presentation/places_providers.dart';

/// Lugares guardados para los recordatorios por ubicación.
class PlacesScreen extends ConsumerWidget {
  const PlacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final places = ref.watch(placesProvider).value ?? const <Place>[];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.placesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => unawaited(showAddPlaceDialog(context, ref)),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: Text(l10n.placesAdd),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          const LocationPermissionCard(),
          if (places.isEmpty)
            EmptyState(
              icon: Icons.place_outlined,
              title: l10n.placesEmpty,
              message: l10n.placesEmptySubtitle,
            )
          else
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final place in places)
                    ListTile(
                      leading: const Icon(Icons.place),
                      title: Text(place.name),
                      subtitle: Text(
                        l10n.placesRadius(place.radiusMeters.round()),
                      ),
                      trailing: IconButton(
                        tooltip: l10n.actionDelete,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => unawaited(
                          ref
                              .read(placesRepositoryProvider)
                              .deletePlace(place.id),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Pide los permisos de ubicación por pasos y explica para qué son.
class LocationPermissionCard extends ConsumerWidget {
  const LocationPermissionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final permission = ref.watch(locationPermissionProvider).value;
    if (permission == null || permission.ready) return const SizedBox.shrink();
    final bridge = ref.read(locationBridgeProvider);
    return Card(
      color: context.colors.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.locationPermissionTitle,
              style: context.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              permission.fine
                  ? l10n.locationPermissionBackground
                  : l10n.locationPermissionFine,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: () async {
                  if (permission.fine) {
                    await bridge.requestBackground();
                  } else {
                    await bridge.requestFine();
                  }
                  ref.invalidate(locationPermissionProvider);
                },
                child: Text(l10n.permissionsGrant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Guarda la ubicación actual con un nombre. Devuelve el lugar o nulo.
Future<Place?> showAddPlaceDialog(
  BuildContext context,
  WidgetRef ref, {
  String? suggestedName,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final bridge = ref.read(locationBridgeProvider);
  var permission = await bridge.status();
  if (!permission.fine) permission = await bridge.requestFine();
  ref.invalidate(locationPermissionProvider);
  if (!permission.fine) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.locationPermissionFine)),
    );
    return null;
  }
  if (!context.mounted) return null;
  final result = await showDialog<(String, double)>(
    context: context,
    builder: (context) => _AddPlaceDialog(suggestedName: suggestedName),
  );
  if (result == null) return null;
  messenger.showSnackBar(SnackBar(content: Text(l10n.placesLocating)));
  final point = await bridge.currentLocation();
  if (point == null) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.placesNoLocation)));
    return null;
  }
  final place = Place(
    id: ref.read(idGeneratorProvider).next(),
    name: result.$1,
    latitude: point.latitude,
    longitude: point.longitude,
    radiusMeters: result.$2,
    createdAt: ref.read(clockProvider).now(),
  );
  await ref.read(placesRepositoryProvider).savePlace(place);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(l10n.placesSaved(place.name))));
  return place;
}

class _AddPlaceDialog extends StatefulWidget {
  const _AddPlaceDialog({this.suggestedName});

  final String? suggestedName;

  @override
  State<_AddPlaceDialog> createState() => _AddPlaceDialogState();
}

class _AddPlaceDialogState extends State<_AddPlaceDialog> {
  late final _name = TextEditingController(text: widget.suggestedName);
  double _radius = Place.defaultRadius;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final suggestions = [
      l10n.placeHome,
      l10n.placeWork,
      l10n.placeSupermarket,
      l10n.placeGym,
    ];
    return AlertDialog(
      title: Text(l10n.placesAddTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.placesAddHint),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l10n.placesName),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (final s in suggestions)
                ActionChip(label: Text(s), onPressed: () => _name.text = s),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<double>(
            initialValue: _radius,
            decoration: InputDecoration(labelText: l10n.placesRadiusLabel),
            items: [
              for (final r in Place.radiusOptions)
                DropdownMenuItem(
                  value: r,
                  child: Text(l10n.placesRadius(r.round())),
                ),
            ],
            onChanged: (value) =>
                setState(() => _radius = value ?? Place.defaultRadius),
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
            final name = _name.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop((name, _radius));
          },
          child: Text(l10n.placesUseHere),
        ),
      ],
    );
  }
}
