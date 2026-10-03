import 'package:viernes/core/logging/app_logger.dart';
import 'package:viernes/features/places/data/location_bridge.dart';
import 'package:viernes/features/places/data/places_repository.dart';

/// Mantiene registradas en Android las geocercas de los recordatorios por
/// ubicación pendientes.
class GeofenceSync {
  GeofenceSync(this._repository, this._bridge);

  final PlacesRepository _repository;
  final LocationBridge _bridge;

  /// Reemplaza las geocercas con lo pendiente. Devuelve un error o nulo.
  Future<String?> sync() async {
    try {
      final places = {for (final p in await _repository.places()) p.id: p};
      final specs = [
        for (final r in await _repository.activeReminders())
          if (places[r.placeId] case final place?)
            GeofenceSpec(
              id: r.id,
              latitude: place.latitude,
              longitude: place.longitude,
              radius: place.radiusMeters,
              onArrive: r.onArrive,
              title: r.title,
              placeName: place.name,
            ),
      ];
      return await _bridge.setGeofences(specs);
    } on Object catch (error, stack) {
      AppLogger.error(
        'No se pudieron registrar las geocercas',
        error: error,
        stackTrace: stack,
      );
      return 'error';
    }
  }
}
