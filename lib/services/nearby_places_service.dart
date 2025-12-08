/// Service to fetch and format nearby places around the user's location.
/// Uses the existing PlacesService to query Google Places API.
/// Returns a clean, formatted list of nearby places with name, type, and distance.
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'places_service.dart';

class NearbyPlace {
  final String name;
  final String type;
  final double distanceMeters;

  NearbyPlace({
    required this.name,
    required this.type,
    required this.distanceMeters,
  });

  @override
  String toString() =>
      '$name (${type}) - ${distanceMeters.toStringAsFixed(0)}m away';
}

class NearbyPlacesService {
  final PlacesService _placesService;

  NearbyPlacesService(this._placesService);

  /// Fetches nearby places around the user's current location.
  ///
  /// Parameters:
  /// - `radius`: Search radius in meters (default: 500)
  /// - `type`: Type of places to search for (default: 'establishment' - all types)
  ///
  /// Returns a list of NearbyPlace objects with clean formatting.
  /// Returns empty list if location services are disabled or permission is denied.
  Future<List<NearbyPlace>> getNearbyPlaces({
    int radius = 500,
    String type = '',
  }) async {
    try {
      print('🏥 NearbyPlaces: Fetching user location...');

      // Get current position
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 0,
        ),
      );

      print(
        '✅ NearbyPlaces: Got location - Lat: ${position.latitude}, Lng: ${position.longitude}',
      );

      // Query nearby places
      print('🏥 NearbyPlaces: Querying nearby places (radius: ${radius}m)...');
      final List<Map<String, dynamic>> rawPlaces = await _placesService
          .searchNearby(
            position.latitude,
            position.longitude,
            radius: radius,
            type: type.isEmpty ? 'establishment' : type,
          );

      if (rawPlaces.isEmpty) {
        print('⚠️ NearbyPlaces: No places found in the area');
        return [];
      }

      print('✅ NearbyPlaces: Found ${rawPlaces.length} places');

      // Format the raw places into clean NearbyPlace objects
      final List<NearbyPlace> nearbyPlaces = rawPlaces.map((place) {
        final String name = place['name'] ?? 'Unknown';
        final String type = place['type'] ?? 'establishment';

        // Calculate distance using Haversine formula if lat/lng available
        double distanceMeters = 0;
        if (place['lat'] != null && place['lng'] != null) {
          distanceMeters = _calculateDistance(
            position.latitude,
            position.longitude,
            place['lat'] as double,
            place['lng'] as double,
          );
        }

        return NearbyPlace(
          name: name,
          type: type,
          distanceMeters: distanceMeters,
        );
      }).toList();

      // Sort by distance
      nearbyPlaces.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

      print('📍 NearbyPlaces: Formatted ${nearbyPlaces.length} places');
      return nearbyPlaces;
    } catch (e) {
      print('❌ NearbyPlaces: Error fetching nearby places: $e');
      return [];
    }
  }

  /// Calculates distance between two coordinates using Haversine formula.
  /// Returns distance in meters.
  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadiusMeters = 6371000; // Earth's radius in meters

    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final double c = 2 * asin(sqrt(a));

    return earthRadiusMeters * c;
  }

  /// Converts degrees to radians.
  double _toRadians(double degrees) {
    return degrees * (pi / 180);
  }
}