import 'dart:async';

import 'package:viernes/features/places/data/location_bridge.dart';

class FakeLocationBridge implements LocationBridge {
  FakeLocationBridge({this.permission = const LocationPermission()});

  LocationPermission permission;
  GeoPoint? location = (latitude: 1.21, longitude: -77.28, accuracy: 10);
  List<GeofenceSpec> geofences = [];
  final _opens = StreamController<String>.broadcast();

  @override
  Stream<String> get opens => _opens.stream;

  @override
  Future<LocationPermission> status() async => permission;

  @override
  Future<LocationPermission> requestFine() async => permission =
      LocationPermission(fine: true, background: permission.background);

  @override
  Future<LocationPermission> requestBackground() async =>
      permission = const LocationPermission(fine: true, background: true);

  @override
  Future<GeoPoint?> currentLocation() async => location;

  @override
  Future<String?> setGeofences(List<GeofenceSpec> specs) async {
    geofences = specs;
    return null;
  }

  @override
  Future<String?> consumeLaunch() async => null;
}
