/// Controller for the Directions/Navigation feature.
/// Handles route calculation, navigation, and map updates.
/// Communicates with MapController to update markers/polylines and with SpeechController for TTS.
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../core/constants.dart';
import '../../providers/app_providers.dart';
import '../../services/gemini_service.dart';
import '../../services/places_service.dart';
import '../../services/tts_service.dart';
import '../camera/camera_controller.dart';
import '../map/map_controller.dart';
import '../speech/speech_controller.dart';
import 'directions_state.dart';

final directionsControllerProvider =
    StateNotifierProvider<DirectionsController, DirectionsState>((ref) {
      return DirectionsController(ref);
    });

class DirectionsController extends StateNotifier<DirectionsState> {
  DirectionsController(this._ref)
    : _geminiService = _ref.read(geminiServiceProvider),
      _placesService = _ref.read(placesServiceProvider),
      _ttsService = _ref.read(ttsServiceProvider),
      super(DirectionsState.initial());

  final Ref _ref;
  final GeminiService _geminiService;
  final PlacesService _placesService;
  final TtsService _ttsService;
  bool _initialized = false;

  /// Initializes location services (permissions and service enablement).
  Future<void> _initialize() async {
    if (_initialized) return;
    _initialized = true;

    var serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      await Future.delayed(const Duration(seconds: 2));
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
    }
  }

  /// Entry point for text-based navigation requests.
  Future<void> navigateToLocation(String destination) async {
    await _initialize();
    if (destination.toLowerCase() == 'current location') {
      await announceCurrentLocation();
      return;
    }

    try {
      final locations = await locationFromAddress(destination);
      if (locations.isNotEmpty) {
        final location = locations.first;
        await navigateToDestination(
          LatLng(location.latitude, location.longitude),
          destination,
        );
      } else {
        await _speak('Sorry, I could not find $destination');
      }
    } catch (e) {
      await _speak('An error occurred while searching for $destination');
    }
  }

  /// Renders map route, animates camera, speaks guidance, and kicks off camera.
  Future<void> navigateToDestination(LatLng destLatLng, String label) async {
    try {
      state = state.copyWith(isNavigating: true, currentDestination: label);

      // Get current position (origin)
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final origin = LatLng(position.latitude, position.longitude);

      // Get route points
      final routePoints = await _getRoutePoints(origin, destLatLng);

      // Update map via MapController
      final mapController = _ref.read(mapControllerProvider.notifier);
      mapController.updateRoute(
        markers: {
          Marker(
            markerId: const MarkerId('searched_location'),
            position: destLatLng,
            infoWindow: InfoWindow(title: label),
          ),
        },
        polylines: routePoints.isNotEmpty
            ? {
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: routePoints,
                  color: Colors.blueAccent,
                  width: 6,
                ),
              }
            : {},
      );

      // Animate camera
      await mapController.animateToLocation(destLatLng, 15);

      // Speak instruction
      await _speak('Navigating to $label');

      // Start camera streaming for obstacle detection
      final cameraController = _ref.read(cameraControllerProvider.notifier);
      await cameraController.toggleCameraStreaming();
    } catch (e) {
      await _speak('Could not start navigation to $label.');
      state = state.copyWith(isNavigating: false);
    }
  }

  /// Announces the current address (or nearest known place) and centers map.
  Future<void> announceCurrentLocation() async {
    await _initialize();
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      String address;
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        address =
            '${place.name ?? ''}, ${place.street ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}, ${place.country ?? ''}';
        if ((place.name == null || place.name!.isEmpty) &&
            (place.street == null || place.street!.isEmpty)) {
          address =
              await _findNearestKnownPlace(
                position.latitude,
                position.longitude,
              ) ??
              'Unknown address';
        }
      } else {
        address =
            await _findNearestKnownPlace(
              position.latitude,
              position.longitude,
            ) ??
            'Unknown address';
      }

      await _speak('Your current location is $address');
      final latLng = LatLng(position.latitude, position.longitude);

      // Update map
      final mapController = _ref.read(mapControllerProvider.notifier);
      mapController.updateRoute(
        markers: {
          Marker(
            markerId: const MarkerId('current_location'),
            position: latLng,
            infoWindow: const InfoWindow(title: 'Current Location'),
          ),
        },
        polylines: {},
      );

      await mapController.animateToLocation(latLng, 15);
    } catch (e) {
      await _speak('Sorry, I could not fetch your current location.');
    }
  }

  /// Handles the full conversational navigation intent flow using Gemini.
  Future<void> handleConversationalNavigation(String command) async {
    await _initialize();
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );

      final result = await _geminiService.getMapsGroundedDirections(
        apiKey: AppConstants.geminiApiKey,
        userLat: position.latitude,
        userLng: position.longitude,
        destination: command,
      );

      final instructions =
          result['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
      final groundingMetadata = result['groundingMetadata'];

      if (instructions.isNotEmpty) {
        await _speak(instructions);
      }

      LatLng? destLatLng;
      String? etaText;

      if (groundingMetadata != null) {
        final dest = groundingMetadata['destinationLatLng'];
        if (dest != null) {
          destLatLng = LatLng(dest['latitude'], dest['longitude']);
        }
        etaText = groundingMetadata['estimatedTime'];
      }

      if (destLatLng != null) {
        final destinationLabel =
            '${command.substring(0, min(command.length, 30))}...';
        await navigateToDestination(destLatLng, destinationLabel);

        if (etaText != null && etaText.isNotEmpty) {
          await _speak('Estimated time to destination is $etaText');
        }
      }
    } catch (e) {
      await _speak('Sorry, I could not get directions.');
    }
  }

  /// Stops ongoing navigation, resets map and state.
  Future<void> stopNavigation() async {
    try {
      // Update state to reflect navigation stopped
      state = state.copyWith(isNavigating: false, currentDestination: null);

      // Clear map via MapController
      final mapController = _ref.read(mapControllerProvider.notifier);
      mapController.updateRoute(
        markers: {}, // clear all markers
        polylines: {}, // clear all polylines
      );

      // Reset camera to default location (ABU Zaria)
      await mapController.animateToLocation(
        const LatLng(11.15, 7.65),
        15, // default zoom
      );

      // Stop camera streaming if active
      final cameraController = _ref.read(cameraControllerProvider.notifier);
      if (cameraController.state.cameraStreaming) {
        await cameraController.toggleCameraStreaming();
      }

      // Optionally speak feedback
      await _speak('Navigation stopped.');
    } catch (e) {
      await _speak('Could not stop navigation.');
    }
  }

  /// Hits Directions API to obtain route polyline coordinates.
  Future<List<LatLng>> _getRoutePoints(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final originStr = '${origin.latitude},${origin.longitude}';
      final destStr = '${destination.latitude},${destination.longitude}';
      final url =
          'https://maps.googleapis.com/maps/api/directions/json?origin=$originStr&destination=$destStr&key=${AppConstants.googleMapsApiKey}&mode=walking';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        return [];
      }
      
      final Map<String, dynamic> data = json.decode(response.body);
      if ((data['routes'] as List).isEmpty) return [];

      final overview = data['routes'][0]['overview_polyline']?['points'];
      if (overview == null || (overview as String).isEmpty) return [];

      return _decodePolyline(overview);
    } catch (_) {
      return [];
    }
  }

  /// Polyline decoder lifted from Google samples.
  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  /// Helper to translate raw coordinates into a nearby POI name.
  Future<String?> _findNearestKnownPlace(double lat, double lng) async {
    try {
      final places = await _placesService.searchNearby(lat, lng, radius: 100);
      if (places.isNotEmpty) {
        return places.first['name'];
      }
    } catch (_) {}
    return null;
  }

  /// Safely performs TTS if voice guidance is enabled and text non-empty.
  Future<void> _speak(String message) async {
    final speechState = _ref.read(speechControllerProvider);
    if (!speechState.voiceGuidance || message.isEmpty) return;
    await _ttsService.stop();
    await _ttsService.speak(message);
  }
}
