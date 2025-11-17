/// Orchestrates every side-effect on the home screen: search, navigation,
/// Gemini calls, speech, camera streaming, permissions, and Bluetooth events.
/// Exposes a pure state for the UI via a Riverpod StateNotifier.
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants.dart';
import '../../../providers/app_providers.dart';
import '../../../services/BluetoothService.dart';
import '../../../services/camera_gemini_service.dart';
import '../../../services/gemini_service.dart';
import '../../../services/places_service.dart';
import '../../../services/speech_to_text_service.dart';
import '../../../services/tts_service.dart';
import 'home_state.dart';

final homeControllerProvider = StateNotifierProvider<HomeController, HomeState>(
  (ref) {
    return HomeController(ref);
  },
);

/// StateNotifier that exposes command-style APIs for the home feature.
class HomeController extends StateNotifier<HomeState> {
  /// Creates controller and wires up required services.
  HomeController(this._ref)
    : _speechService = _ref.read(speechServiceProvider),
      _geminiService = _ref.read(geminiServiceProvider),
      _ttsService = _ref.read(ttsServiceProvider),
      _cameraGeminiService = _ref.read(cameraGeminiServiceProvider),
      _placesService = _ref.read(placesServiceProvider),
      super(HomeState.initial()) {
    _bluetoothService = BluetoothService(
      _handleBluetoothStatus,
      _handleBluetoothMessage,
    );
  }

  final Ref _ref;
  final SpeechToTextService _speechService;
  final GeminiService _geminiService;
  final TtsService _ttsService;
  final CameraGeminiService _cameraGeminiService;
  final PlacesService _placesService;
  late final BluetoothService _bluetoothService;

  GoogleMapController? _mapController;
  Timer? _cameraStreamTimer;
  bool _initialized = false;

  /// One-time bootstrapping for permissions, hardware, and settings.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _requestMicPermission();
    await _speechService.init();
    await _initCamera();
    await _initializeLocationService();

    state = state.copyWith(isInitializing: false);
  }

  /// Captures the GoogleMap controller when the widget finishes building.
  void onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  /// Drives live search suggestions (Places autocomplete + geocoding fallback).
  Future<void> searchLocations(String query) async {
    if (query.isEmpty) {
      clearSearchResults();
      return;
    }
    try {
      double? biasLat;
      double? biasLng;
      if (_mapController != null) {
        final pos = await _mapController!.getLatLng(
          const ScreenCoordinate(x: 0, y: 0),
        );
        biasLat = pos.latitude;
        biasLng = pos.longitude;
      }

      final predictions = await _placesService.autocomplete(
        query,
        lat: biasLat,
        lng: biasLng,
      );

      if (predictions.isEmpty) {
        final results = await locationFromAddress(query);
        final labels = results
            .take(5)
            .map(
              (loc) =>
                  '${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)} (Coords)',
            )
            .toList();
        state = state.copyWith(
          searchResults: results.take(5).toList(),
          searchLabels: labels,
          searchPlaceIds: List.filled(labels.length, ''),
          showSearchResults: results.isNotEmpty,
        );
        return;
      }

      state = state.copyWith(
        searchLabels: predictions.map((p) => p['description']!).toList(),
        searchPlaceIds: predictions.map((p) => p['place_id']!).toList(),
        showSearchResults: true,
        searchResults: [],
      );
    } catch (e) {
      state = state.copyWith(
        searchResults: [],
        searchLabels: [],
        searchPlaceIds: [],
        showSearchResults: false,
        errorMessage: 'Search error: $e',
      );
    }
  }

  /// Resets search UI state when text input empties.
  void clearSearchResults() {
    state = state.copyWith(
      showSearchResults: false,
      searchResults: [],
      searchLabels: [],
      searchPlaceIds: [],
      pendingSearch: null,
    );
  }

  /// Stores the last text query to allow delayed navigation.
  void setPendingSearch(String query) {
    state = state.copyWith(pendingSearch: query);
  }

  /// Removes pending search metadata once navigation completes.
  void clearPendingSearch() {
    state = state.copyWith(pendingSearch: null);
  }

  /// Processes taps on autocomplete items, resolving to precise LatLng.
  Future<void> handleSearchResultTap(int index) async {
    if (index >= state.searchLabels.length) return;

    final label = state.searchLabels[index];
    final placeId = state.searchPlaceIds.isNotEmpty
        ? state.searchPlaceIds[index]
        : '';
    final result = state.searchResults.isNotEmpty
        ? state.searchResults[index]
        : null;

    state = state.copyWith(showSearchResults: false);

    if (placeId.isNotEmpty) {
      final details = await _placesService.getPlaceDetails(placeId);
      if (details != null) {
        final destLatLng = LatLng(details['lat'], details['lng']);
        final finalLabel = details['formatted_address'] as String? ?? label;
        await _drawRouteAndNavigate(destLatLng, finalLabel);
        return;
      }
    }

    if (result != null) {
      final destLatLng = LatLng(result.latitude, result.longitude);
      await _drawRouteAndNavigate(destLatLng, label);
      return;
    }

    await handleLocationRequest(label);
  }

  /// Entry point for text-based navigation requests.
  Future<void> handleLocationRequest(String destination) async {
    if (destination.toLowerCase() == 'current location') {
      await _announceCurrentLocation();
      return;
    }

    try {
      final locations = await locationFromAddress(destination);
      if (locations.isNotEmpty) {
        final location = locations.first;
        await _drawRouteAndNavigate(
          LatLng(location.latitude, location.longitude),
          destination,
        );
      } else {
        await _speak('Sorry, I could not find $destination');
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Geocoding error: $e');
      await _speak('An error occurred while searching for $destination');
    }
  }

  /// Starts speech-to-text and feeds recognized phrases into navigation logic.
  Future<void> startListening() async {
    state = state.copyWith(isListening: true);
    await _speak('Listening...');
    await _speechService.listen(
      onResult: (recognizedText) async {
        state = state.copyWith(
          isListening: false,
          detectedCommand: recognizedText,
        );
        await handleConversationalNavigation(recognizedText);
      },
      onError: (error) async {
        state = state.copyWith(isListening: false);
        await _speak('Speech recognition error: $error');
      },
    );
  }

  /// Stops the speech session and notifies the user.
  Future<void> stopListening() async {
    await _speechService.stop();
    state = state.copyWith(isListening: false, clearDetectedCommand: true);
    await _speak('Stopped listening.');
  }

  /// Clears the detected command marker after the UI has reacted.
  void clearDetectedCommandFlag() {
    state = state.copyWith(clearDetectedCommand: true);
  }

  /// Clears any shown error message to avoid repeated snack bars.
  void clearErrorMessage() {
    state = state.copyWith(clearErrorMessage: true);
  }

  /// Toggles camera-driven obstacle detection.
  Future<void> toggleCameraStreaming() async {
    if (state.cameraStreaming) {
      await _stopCameraStreaming();
    } else {
      await _startCameraStreaming();
    }
  }

  /// Handles the full conversational navigation intent flow.
  Future<void> handleConversationalNavigation(String command) async {
    final lowerCmd = command.toLowerCase();

    if (lowerCmd.contains('where am i') ||
        lowerCmd.contains('current location') ||
        lowerCmd.contains('where is my location') ||
        lowerCmd.contains('where am')) {
      await _announceCurrentLocation();
      return;
    }

    if (lowerCmd.contains('detect')) {
      await toggleCameraStreaming();
      return;
    }

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
        state = state.copyWith(cameraAiResponse: instructions);
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
        await _drawRouteAndNavigate(destLatLng, destinationLabel);

        if (etaText != null && etaText.isNotEmpty) {
          await _speak('Estimated time to destination is $etaText');
        }
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Conversational nav error: $e');
      await _speak('Sorry, I could not get directions.');
    }
  }

  /// Renders map route, animates camera, speaks guidance, and kicks off camera.
  Future<void> _drawRouteAndNavigate(LatLng destLatLng, String label) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final origin = LatLng(position.latitude, position.longitude);
      final routePoints = await _getRoutePoints(origin, destLatLng);

      state = state.copyWith(
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
        pendingSearch: label,
      );

      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(destLatLng, 15),
      );

      await _speak('Navigating to $label');
      await _startCameraStreaming();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Navigation error: $e');
      await _speak('Could not start navigation to $label.');
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

  /// Announces the current address (or nearest known place) and centers map.
  Future<void> _announceCurrentLocation() async {
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
      state = state.copyWith(
        markers: {
          Marker(
            markerId: const MarkerId('current_location'),
            position: latLng,
            infoWindow: const InfoWindow(title: 'Current Location'),
          ),
        },
        polylines: {},
      );

      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(latLng, 15),
      );
    } catch (e) {
      await _speak('Sorry, I could not fetch your current location.');
    }
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

  /// Begins periodic capture/analysis loop for obstacle detection.
  Future<void> _startCameraStreaming() async {
    if (!_cameraGeminiService.isInitialized || state.cameraStreaming) return;
    state = state.copyWith(cameraStreaming: true);
    await _speak('Camera obstacle detection started');

    _cameraStreamTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) async {
      if (!state.cameraStreaming) {
        timer.cancel();
        return;
      }
      if (!_cameraGeminiService.ttsBusy) {
        await _cameraGeminiService.captureAndAnalyze();
      }
    });
  }

  /// Stops the capture timer and notifies the user.
  Future<void> _stopCameraStreaming() async {
    if (!state.cameraStreaming) return;
    state = state.copyWith(cameraStreaming: false);
    _cameraStreamTimer?.cancel();
    await _cameraGeminiService.session?.close();
    await _speak('Obstacle detection stopped');
  }

  /// Initializes camera service and routes AI responses to feedback channels.
  Future<void> _initCamera() async {
    await _cameraGeminiService.initCamera();
    _cameraGeminiService.onAiResponse = (response) async {
      state = state.copyWith(cameraAiResponse: response);
      _cameraGeminiService.ttsBusy = true;

      final lowerResp = response.toLowerCase();
      if (_bluetoothService.isConnected) {
        if (lowerResp.contains('left') || lowerResp.contains('move left')) {
          _bluetoothService.sendMessage('L');
        }
        if (lowerResp.contains('right') || lowerResp.contains('move right')) {
          _bluetoothService.sendMessage('R');
        }
      }

      await _ttsService.stop();
      await _ttsService.speak(response);
      _cameraGeminiService.ttsBusy = false;
    };
  }

  /// Confirms that device location services are enabled and permitted.
  Future<void> _initializeLocationService() async {
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

  /// Requests microphone access and guides the user if denied.
  Future<void> _requestMicPermission() async {
    final status = await Permission.microphone.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      await _speak(
        'Microphone permission denied. Please enable it in settings.',
      );
      if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
    }
  }

  /// Reacts to Bluetooth connectivity, giving audible confirmation + handshake.
  Future<void> _handleBluetoothStatus(bool connected, String message) async {
    if (connected) {
      await _speak('Hardware device connected successfully');
      _bluetoothService.sendMessage("LRLRLRLRLRLRLRLRRLRLRLRLRLR");
    }
  }

  /// Records inbound Bluetooth messages for display/logging.
  void _handleBluetoothMessage(String message) {
    final messages = List<String>.from(state.receivedMessages)..add(message);
    state = state.copyWith(receivedMessages: messages);
  }

  /// Safely performs TTS if voice guidance is enabled and text non-empty.
  Future<void> _speak(String message) async {
    if (!state.voiceGuidance || message.isEmpty) return;
    await _ttsService.stop();
    await _ttsService.speak(message);
  }

  /// Animates the camera back to the default center point.
  Future<void> recenterMap() async {
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: state.mapCenter, zoom: 12),
      ),
    );
  }

  /// Cleans up owned services/timers when the widget tree disposes.
  Future<void> disposeController() async {
    _cameraStreamTimer?.cancel();
    _cameraGeminiService.dispose();
    await _speechService.stop();
    await _ttsService.stop();
    _mapController?.dispose();
    _bluetoothService.dispose();
  }
}
