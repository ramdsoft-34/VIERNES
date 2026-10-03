import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:viernes/core/logging/app_logger.dart';

/// Permisos de ubicación concedidos.
@immutable
class LocationPermission {
  const LocationPermission({this.fine = false, this.background = false});

  /// Ubicación precisa (para guardar un lugar).
  final bool fine;

  /// «Permitir todo el tiempo» (para avisar con la app cerrada).
  final bool background;

  bool get ready => fine && background;
}

/// Coordenadas actuales.
typedef GeoPoint = ({double latitude, double longitude, double accuracy});

/// Geocerca que se registra en Android.
@immutable
class GeofenceSpec {
  const GeofenceSpec({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.onArrive,
    required this.title,
    required this.placeName,
  });

  final String id;
  final double latitude;
  final double longitude;
  final double radius;
  final bool onArrive;
  final String title;
  final String placeName;

  Map<String, Object> toMap() => {
    'id': id,
    'latitude': latitude,
    'longitude': longitude,
    'radius': radius,
    'onArrive': onArrive,
    'title': title,
    'placeName': placeName,
  };
}

/// Ubicación y geocercas del sistema. En pruebas se usa una falsa.
abstract interface class LocationBridge {
  Future<LocationPermission> status();

  Future<LocationPermission> requestFine();

  Future<LocationPermission> requestBackground();

  Future<GeoPoint?> currentLocation();

  /// Reemplaza todas las geocercas. Devuelve un código de error o nulo.
  Future<String?> setGeofences(List<GeofenceSpec> specs);

  /// Recordatorio por ubicación cuyo aviso abrió la app.
  Future<String?> consumeLaunch();

  /// Se emite al tocar un aviso con la app abierta.
  Stream<String> get opens;
}

class AndroidLocationBridge implements LocationBridge {
  AndroidLocationBridge() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onOpen' && call.arguments is String) {
        _opens.add(call.arguments as String);
      }
    });
  }

  static const _channel = MethodChannel('com.ramdsoft.viernes/location');
  final _opens = StreamController<String>.broadcast();

  @override
  Stream<String> get opens => _opens.stream;

  @override
  Future<LocationPermission> status() => _permission('status');

  @override
  Future<LocationPermission> requestFine() => _permission('requestFine');

  @override
  Future<LocationPermission> requestBackground() =>
      _permission('requestBackground');

  @override
  Future<GeoPoint?> currentLocation() async {
    final map = await _call<Map<Object?, Object?>>('currentLocation');
    if (map == null) return null;
    return (
      latitude: (map['latitude']! as num).toDouble(),
      longitude: (map['longitude']! as num).toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  Future<String?> setGeofences(List<GeofenceSpec> specs) =>
      _call<String>('setGeofences', [for (final s in specs) s.toMap()]);

  @override
  Future<String?> consumeLaunch() => _call<String>('consumeLaunch');

  Future<LocationPermission> _permission(String method) async {
    final map = await _call<Map<Object?, Object?>>(method);
    return LocationPermission(
      fine: map?['fine'] == true,
      background: map?['background'] == true,
    );
  }

  Future<T?> _call<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      AppLogger.error('Ubicación: $method', error: error);
      return null;
    }
  }
}
