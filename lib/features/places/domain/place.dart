import 'package:flutter/foundation.dart';
import 'package:viernes/ai/nlu/es/spanish_text.dart';

/// Lugar guardado por el usuario («Casa», «Trabajo», «Supermercado»).
@immutable
class Place {
  const Place({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.radiusMeters = defaultRadius,
  });

  static const defaultRadius = 150.0;
  static const radiusOptions = [100.0, 150.0, 250.0, 500.0];

  final String id;
  final String name;
  final double latitude;
  final double longitude;

  /// Qué tan cerca hay que estar para «llegar» (Android recomienda ≥ 100 m).
  final double radiusMeters;
  final DateTime createdAt;

  /// Nombre normalizado para buscarlo por voz («el súper» → «super»).
  String get key => SpanishText.fold(name).trim();

  @override
  bool operator ==(Object other) =>
      other is Place &&
      other.id == id &&
      other.name == name &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.radiusMeters == radiusMeters;

  @override
  int get hashCode => Object.hash(id, name, latitude, longitude, radiusMeters);
}

/// «Recuérdame comprar leche cuando llegue a casa».
@immutable
class LocationReminder {
  const LocationReminder({
    required this.id,
    required this.title,
    required this.placeId,
    required this.createdAt,
    this.onArrive = true,
    this.done = false,
    this.completedAt,
  });

  final String id;
  final String title;
  final String placeId;

  /// Verdadero: avisa al llegar; falso: al salir.
  final bool onArrive;
  final bool done;
  final DateTime createdAt;
  final DateTime? completedAt;

  @override
  bool operator ==(Object other) =>
      other is LocationReminder &&
      other.id == id &&
      other.title == title &&
      other.placeId == placeId &&
      other.onArrive == onArrive &&
      other.done == done;

  @override
  int get hashCode => Object.hash(id, title, placeId, onArrive, done);
}
