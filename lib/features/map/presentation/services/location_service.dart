import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

/// Permission status enum
enum LocationPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  unknown,
}

class LocationService {
  // Default fallback location (Cairo, Egypt)
  static const LatLng _defaultLocation = LatLng(30.0444, 31.2357);
  
  // Configurable timeout for location fetching
  static const Duration _locationTimeout = Duration(seconds: 5);
  
  // Prevent multiple simultaneous requests
  static Future<LatLng?>? _locationFuture;

  /// Request location permission with proper handling
  static Future<LocationPermissionStatus> requestLocationPermission() async {
    try {
      final status = await Permission.location.request();
      return _mapPermissionStatus(status);
    } catch (e) {
      return LocationPermissionStatus.unknown;
    }
  }

  /// Check current location permission status
  static Future<LocationPermissionStatus> getLocationPermissionStatus() async {
    try {
      final status = await Permission.location.status;
      return _mapPermissionStatus(status);
    } catch (e) {
      return LocationPermissionStatus.unknown;
    }
  }

  /// Open app settings to enable location permission
  static Future<bool> openLocationSettings() async {
    try {
      return await openAppSettings();
    } catch (e) {
      return false;
    }
  }

  /// Get current location with timeout and fallback
  /// Returns [LatLng] with either real location or default fallback
  static Future<LatLng?> getCurrentLocation() async {
    try {
      // Prevent multiple simultaneous requests
      if (_locationFuture != null) {
        return await _locationFuture;
      }

      _locationFuture = _fetchLocationWithTimeout();
      final result = await _locationFuture;
      _locationFuture = null;
      return result;
    } catch (e) {
      _locationFuture = null;
      return null;
    }
  }

  /// Fetch location with timeout protection
  static Future<LatLng?> _fetchLocationWithTimeout() async {
    try {
      final permissionStatus = await getLocationPermissionStatus();
      
      // If permission not granted, return null (caller can use default)
      if (permissionStatus != LocationPermissionStatus.granted) {
        return null;
      }

      // Fetch with timeout to prevent hanging
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: _locationTimeout,
      ).timeout(
        _locationTimeout,
        onTimeout: () {
          throw TimeoutException('Location fetch timeout after $_locationTimeout');
        },
      );

      return LatLng(position.latitude, position.longitude);
    } on TimeoutException {
      // Timeout: return null to use default location
      return null;
    } on LocationServiceDisabledException {
      // Location service disabled
      return null;
    } catch (e) {
      // Any other error
      return null;
    }
  }

  /// Get default fallback location (Cairo)
  static LatLng getDefaultLocation() => _defaultLocation;

  /// Map PermissionStatus to LocationPermissionStatus
  static LocationPermissionStatus _mapPermissionStatus(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return LocationPermissionStatus.granted;
      case PermissionStatus.denied:
        return LocationPermissionStatus.denied;
      case PermissionStatus.permanentlyDenied:
        return LocationPermissionStatus.permanentlyDenied;
      case PermissionStatus.restricted:
        return LocationPermissionStatus.restricted;
      default:
        return LocationPermissionStatus.unknown;
    }
  }
}