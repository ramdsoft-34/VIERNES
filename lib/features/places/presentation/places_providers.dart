import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/app/router/app_router.dart';
import 'package:viernes/app/router/routes.dart';
import 'package:viernes/features/places/application/geofence_sync.dart';
import 'package:viernes/features/places/data/location_bridge.dart';
import 'package:viernes/features/places/data/places_repository.dart';
import 'package:viernes/features/places/domain/place.dart';

final placesRepositoryProvider = Provider<PlacesRepository>(
  (ref) => PlacesRepository(ref.watch(appDatabaseProvider)),
);

/// Ubicación y geocercas del sistema. En pruebas se sobrescribe.
final locationBridgeProvider = Provider<LocationBridge>(
  (ref) => AndroidLocationBridge(),
);

final geofenceSyncProvider = Provider<GeofenceSync>(
  (ref) => GeofenceSync(
    ref.watch(placesRepositoryProvider),
    ref.watch(locationBridgeProvider),
  ),
);

final placesProvider = StreamProvider<List<Place>>(
  (ref) => ref.watch(placesRepositoryProvider).watchPlaces(),
);

final locationRemindersProvider = StreamProvider<List<LocationReminder>>(
  (ref) => ref.watch(placesRepositoryProvider).watchReminders(),
);

final FutureProvider<LocationPermission> locationPermissionProvider =
    FutureProvider.autoDispose<LocationPermission>(
      (ref) => ref.watch(locationBridgeProvider).status(),
    );

final placesCoordinatorProvider = Provider<PlacesCoordinator>((ref) {
  final coordinator = PlacesCoordinator(ref);
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// Mantiene las geocercas al día con los recordatorios por ubicación y abre
/// la lista al tocar un aviso.
class PlacesCoordinator {
  PlacesCoordinator(this._ref);

  final Ref _ref;
  final _subscriptions = <StreamSubscription<Object?>>[];
  Timer? _debounce;

  Future<void> start() async {
    final repository = _ref.read(placesRepositoryProvider);
    final bridge = _ref.read(locationBridgeProvider);
    _subscriptions
      ..add(repository.watchReminders().listen((_) => _schedule()))
      ..add(repository.watchPlaces().listen((_) => _schedule()))
      ..add(bridge.opens.listen((_) => _openList()));
    if (await bridge.consumeLaunch() != null) _openList();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 500),
      () => unawaited(_ref.read(geofenceSyncProvider).sync()),
    );
  }

  void _openList() =>
      unawaited(_ref.read(appRouterProvider).push(AppRoutes.locationReminders));

  void dispose() {
    _debounce?.cancel();
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
  }
}
