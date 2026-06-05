import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'backend_service.dart';

class GeofenceService {
  static final GeofenceService _instance = GeofenceService._internal();
  factory GeofenceService() => _instance;
  GeofenceService._internal();

  final BackendService _backend = BackendService();
  Timer? _trackingTimer;
  bool _isGeofenced = false;
  String? _currentUserEmail;

  // Center of campus (Default REVA University coordinates)
  static const double campusLatitude = 13.1158;
  static const double campusLongitude = 77.6360;
  static const double campusRadiusMeters = 500.0; // 500 meters boundary

  bool get isGeofenced => _isGeofenced;

  /// Starts the periodic location monitoring service
  Future<void> startTracking(String email) async {
    _currentUserEmail = email;
    stopTracking(); // Ensure any existing trackers are closed first

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (kDebugMode) print('Location services are disabled.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (kDebugMode) print('Location permissions are denied.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (kDebugMode) print('Location permissions are permanently denied.');
      return;
    }

    // Perform initial check immediately
    await _checkLocation();

    // Start timer for periodic updates (every 30 seconds)
    _trackingTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      await _checkLocation();
    });

    if (kDebugMode) {
      print('Geofencing tracking started for $email');
    }
  }

  /// Cancels the tracking service and resets backend status
  Future<void> stopTracking() async {
    _trackingTimer?.cancel();
    _trackingTimer = null;

    if (_isGeofenced && _currentUserEmail != null) {
      _isGeofenced = false;
      try {
        await _backend.setBlacklisted(_currentUserEmail!, false);
        await _backend.setGeofenced(_currentUserEmail!, false);
      } catch (_) {}
    }
    _currentUserEmail = null;
    if (kDebugMode) print('Geofencing tracking stopped.');
  }

  /// Checks user location, updates local state and calls backend api
  Future<void> _checkLocation() async {
    if (_currentUserEmail == null) return;

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        campusLatitude,
        campusLongitude,
      );

      bool insideNow = distance <= campusRadiusMeters;

      if (insideNow != _isGeofenced) {
        _isGeofenced = insideNow;
        // Keep active and report geofenced status (inside campus/outside campus)
        await _backend.setBlacklisted(_currentUserEmail!, false);
        await _backend.setGeofenced(_currentUserEmail!, insideNow);

        if (kDebugMode) {
          print('Geofence boundary crossed! Inside Campus: $insideNow (Distance: ${distance.toStringAsFixed(1)}m)');
        }
      }
    } catch (e) {
      if (kDebugMode) print('Geofencing check failed: $e');
    }
  }
}
