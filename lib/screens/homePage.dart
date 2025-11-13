import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import '../widgets/custom_map.dart';
// import 'package:sensors_plus/sensors_plus.dart';
import '../services/speech_to_text_service.dart';
import '../services/gemini_service.dart';
import '../services/tts_service.dart';
import '../services/camera_gemini_service.dart';
import '../providers/app_providers.dart';
import '../services/places_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:math';
import '../core/constants.dart';
import '../services/BluetoothService.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => HomePageState();
}

class HomePageState extends ConsumerState<HomePage> {
  // --- Services ---
  late final SpeechToTextService _speechService;
  late final GeminiService _geminiService;
  late final TtsService _ttsService;
  late final CameraGeminiService _cameraGeminiService;
  late final PlacesService _placesService;
  late final BluetoothService _bluetoothService;

  // --- Search Controller ---
  List<String> _searchResultPlaceIds = []; // store place_ids alongside labels
  final TextEditingController _searchController = TextEditingController();
  // Note: _searchResults are Location objects (used for geocoding fallback only)
  List<Location> _searchResults = [];
  List<String> _searchResultLabels = [];
  bool _showSearchResults = false;

  // ------ Bluetooth ------
  final List<String> _receivedMessages = [];

  // --- API Keys (move to secure storage for production) ---
  final String geminiApiKey = AppConstants.geminiApiKey;
  final String googleMapsApiKey = AppConstants.googleMapsApiKey;

  GoogleMapController? mapController;
  final LatLng _center = const LatLng(11.15, 7.65); // ABU Zaria
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool _isListening = false;
  // ignore: unused_field
  String _cameraAiResponse = "";
  bool _cameraStreaming = false;
  Timer? _cameraStreamTimer;
  String? _pendingSearch; // Store last searched destination

  // --- Settings ---
  bool _voiceGuidance = true;

  @override
  void initState() {
    super.initState();
    // Services initialization via Riverpod
    _speechService = ref.read(speechServiceProvider);
    _geminiService = ref.read(geminiServiceProvider);
    _ttsService = ref.read(ttsServiceProvider);
    _cameraGeminiService = ref.read(cameraGeminiServiceProvider);
    _placesService = ref.read(placesServiceProvider);
    // Override the BluetoothService provider with your callback
    _bluetoothService = BluetoothService(
      _handleBluetoothStatusChange,
      _handleBluetoothMessageReceived,
    );
    _requestMicPermission();
    _speechService.init();
    _initCameraAndGemini();
    // _initMotionDetection();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _voiceGuidance = true;
    });
  }

  void _handleBluetoothStatusChange(bool connected, String message) {
    setState(() {
      // You might need to update local state if your UI depends on it
      // e.g., this.isConnected = connected;
      // e.g., this.statusMessage = message;
      if (connected) {
        _ttsService.speak("Hardware device connected successfully");
        _sendBluetoothMessage("LRLRLRLRLRLRLRLRRLRLRLRLRLR");
      }
    });
  }

  void _sendBluetoothMessage(String message) {
    _bluetoothService.sendMessage(message);
  }

  void _handleBluetoothMessageReceived(String message) {
    setState(() {
      _receivedMessages.add(message);
    });
  }

  // void _initMotionDetection() {
  //   try {
  //     userAccelerometerEventStream().listen(
  //       (event) {
  //         double magnitude = sqrt(
  //           event.x * event.x + event.y * event.y + event.z * event.z,
  //         );
  //         if (magnitude > 2.0 && !_cameraStreaming) {
  //           print('Motion detected: $magnitude');
  //           // This starts the camera automatically on motion
  //           _startCameraStreaming();
  //         }
  //       },
  //       onError: (error) {
  //         print('UserAccelerometer error: $error');
  //       },
  //       cancelOnError: true,
  //     );
  //   } catch (e) {
  //     print('Motion detection setup error: $e');
  //   }
  // }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  // 1. CONSOLIDATED FUNCTION: Handles map updates, camera, and voice guidance
  // Renamed from _navigateToPlace to be a definitive action.
  Future<void> _drawRouteAndNavigate(LatLng destLatLng, String label) async {
    try {
      // 1. Get current position (origin)
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final origin = LatLng(position.latitude, position.longitude);

      // 2. Get route points
      final routePoints = await _getRoutePoints(origin, destLatLng);

      // 3. Update map UI
      setState(() {
        _markers.clear();
        _markers.add(
          Marker(
            markerId: MarkerId('searched_location'),
            position: destLatLng,
            infoWindow: InfoWindow(title: label),
          ),
        );
        _polylines.clear();
        if (routePoints.isNotEmpty) {
          _polylines.add(
            Polyline(
              polylineId: PolylineId('route'),
              points: routePoints,
              color: Colors.blueAccent,
              width: 6,
            ),
          );
        }
        _pendingSearch = label; // Keep track of the current destination
      });

      // 4. Animate camera
      await mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(destLatLng, 15),
      );

      // 5. Speak instruction
      if (_voiceGuidance) await _ttsService.speak('Navigating to $label');

      // 6. Start visual guidance
      await _startCameraStreaming();
    } catch (e) {
      print('Error drawing route and navigating: $e');
      if (_voiceGuidance) {
        await _ttsService.speak('Could not start navigation to $label.');
      }
    }
  }

  // Search locations by query (real-time search)
  // This logic is mostly correct and uses the Places Autocomplete API.
  Future<void> _searchLocationsByQuery(String query) async {
    try {
      double? biasLat, biasLng;
      if (mapController != null) {
        final pos = await mapController!.getLatLng(
          ScreenCoordinate(x: 0, y: 0),
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
        // Fallback to geocoding if no places predictions
        final results = await locationFromAddress(query);
        final labels = results
            .take(5)
            .map(
              (loc) =>
                  '${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)} (Coords)',
            )
            .toList();
        setState(() {
          _searchResults = results.take(5).toList();
          _searchResultLabels = labels;
          // IMPORTANT: Use empty strings for place_ids in fallback
          _searchResultPlaceIds = List.filled(labels.length, '');
          _showSearchResults = results.isNotEmpty;
        });
        return;
      }

      setState(() {
        _searchResultLabels = predictions
            .map((p) => p['description']!)
            .toList();
        _searchResultPlaceIds = predictions.map((p) => p['place_id']!).toList();
        _showSearchResults = _searchResultLabels.isNotEmpty;
        // Clear old geocoding results
        _searchResults = [];
      });
    } catch (e) {
      print('Search error: $e');
      setState(() {
        _searchResults = [];
        _searchResultLabels = [];
        _showSearchResults = false;
        _searchResultPlaceIds = [];
      });
    }
  }

  // Select search result by text (called on manual search submit or voice detection)
  void _selectSearchResult(String query) {
    _pendingSearch = query;
    setState(() {
      _showSearchResults = false;
      _searchResults = [];
    });
  }

  Future<void> _initCameraAndGemini() async {
    await _cameraGeminiService.initCamera();

    _cameraGeminiService.onAiResponse = (response) async {
      setState(() => _cameraAiResponse = response);
      _cameraGeminiService.ttsBusy = true;

      // --- Vibration logic based on AI response ---
      // final bluetoothService = ref.read(bluetoothServiceProvider);
      final lowerResp = response.toLowerCase();

      if (_bluetoothService.isConnected) {
        if (lowerResp.contains('left') || lowerResp.contains('move left')) {
          _bluetoothService.sendMessage('L');
        }
        if (lowerResp.contains('right') || lowerResp.contains('move right')) {
          _bluetoothService.sendMessage('R');
        }
        // Add more patterns if needed
      }

      if (_voiceGuidance) {
        await _ttsService.stop();
        await _ttsService.speak(response);
      }
      _cameraGeminiService.ttsBusy = false;
    };

    setState(() {});
  }

  Future<void> _startCameraStreaming() async {
    if (!_cameraGeminiService.isInitialized || _cameraStreaming) return;
    setState(() => _cameraStreaming = true);
    await _ttsService.speak('Camera obstacle detection started');

    // No session init needed; session is handled in initCamera()
    _cameraStreamTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) async {
      if (!_cameraStreaming || !mounted) {
        timer.cancel();
        return;
      }
      if (!_cameraGeminiService.ttsBusy) {
        await _cameraGeminiService.captureAndAnalyze();
      }
    });
  }

  Future<void> _stopCameraStreaming() async {
    setState(() => _cameraStreaming = false);
    _cameraStreamTimer?.cancel();
    await _cameraGeminiService.session?.close();
    if (_voiceGuidance) {
      await _ttsService.speak('Obstacle detection stopped');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF232323),
      body: GestureDetector(
        behavior:
            HitTestBehavior.opaque, // Ensures the gesture is detected anywhere
        onLongPress: _manualStartListening,
        onLongPressUp: _stopListening,
        child: SafeArea(
          child: Stack(
            children: [
              // Map with rounded corners
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CustomMap(
                    center: _center,
                    onMapCreated: _onMapCreated,
                    markers: _markers,
                    polylines: _polylines,
                  ),
                ),
              ),
              // Search bar overlay
              Positioned(
                top: 24,
                left: 24,
                right: 24,
                child: Column(
                  children: [
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF232323),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Search destination',
                                hintStyle: const TextStyle(
                                  color: Colors.white54,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                              ),
                              onChanged: (value) async {
                                if (value.isEmpty) {
                                  setState(() {
                                    _showSearchResults = false;
                                    _searchResults = [];
                                    _searchResultLabels = [];
                                    _searchResultPlaceIds = [];
                                    _pendingSearch =
                                        null; // Clear pending search
                                  });
                                } else {
                                  await _searchLocationsByQuery(value);
                                }
                              },
                              onSubmitted: (value) {
                                if (value.isNotEmpty) {
                                  _selectSearchResult(value);
                                  // Automatically initiate navigation on submit
                                  _handleLocationRequest(value);
                                }
                              },
                            ),
                          ),
                          if (_pendingSearch != null && !_showSearchResults)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF2196F3),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text('Navigate'),
                              onPressed: () async {
                                // Ensure pending search is resolved and navigated
                                await _handleLocationRequest(_pendingSearch!);
                                _pendingSearch = null;
                                _searchController.clear();
                                setState(() => _showSearchResults = false);
                              },
                            ),
                          IconButton(
                            icon: Icon(
                              _isListening ? Icons.mic : Icons.mic_none,
                              color: Colors.white,
                            ),
                            onPressed: _isListening
                                ? _stopListening
                                : _manualStartListening,
                          ),
                        ],
                      ),
                    ),
                    // Search results dropdown
                    if (_showSearchResults && _searchResultLabels.isNotEmpty)
                      Container(
                        margin: EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF232323),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24),
                        ),
                        constraints: BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          itemCount: _searchResultLabels.length,
                          itemBuilder: (context, index) {
                            // The result object is only for geocoding fallback
                            final result = _searchResults.isNotEmpty
                                ? _searchResults[index]
                                : null;

                            return ListTile(
                              title: Text(
                                _searchResultLabels[index],
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                // Show coordinates if it's a geocoding fallback, otherwise show empty
                                result != null
                                    ? '${result.latitude.toStringAsFixed(4)}, ${result.longitude.toStringAsFixed(4)}'
                                    : 'Address details...',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              onTap: () async {
                                final label = _searchResultLabels[index];
                                final placeId = _searchResultPlaceIds.isNotEmpty
                                    ? _searchResultPlaceIds[index]
                                    : '';

                                _searchController.text = label;
                                setState(() => _showSearchResults = false);

                                if (placeId.isNotEmpty) {
                                  // 4. Robust Path: Use Place ID for accurate LatLng
                                  final details = await _placesService
                                      .getPlaceDetails(placeId);
                                  if (details != null) {
                                    final destLatLng = LatLng(
                                      details['lat'],
                                      details['lng'],
                                    );
                                    // Use the official address if available
                                    final finalLabel =
                                        details['formatted_address']
                                            as String? ??
                                        label;

                                    // Use the consolidated function
                                    await _drawRouteAndNavigate(
                                      destLatLng,
                                      finalLabel,
                                    );
                                  } else {
                                    // Fallback to text search if place details failed
                                    await _handleLocationRequest(label);
                                  }
                                } else if (result != null) {
                                  // 5. Geocoding Fallback Path: Use direct LatLng
                                  final destLatLng = LatLng(
                                    result.latitude,
                                    result.longitude,
                                  );
                                  // The label will be the coordinates (e.g., "11.1500, 7.6500 (Coords)")
                                  await _drawRouteAndNavigate(
                                    destLatLng,
                                    label,
                                  );
                                } else {
                                  // Final fallback: use the text string
                                  await _handleLocationRequest(label);
                                }

                                _pendingSearch = null;
                                _searchController.clear();
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              // Floating controls (zoom and orientation)
              Positioned(
                right: 24,
                bottom: 120,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    _mapControlButton(Icons.explore, () {
                      mapController?.animateCamera(
                        CameraUpdate.newCameraPosition(
                          CameraPosition(
                            target: _center,
                            zoom: 12,
                            tilt: 0,
                            bearing: 0,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              // Listening indicator
              if (_isListening)
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Listening...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              // Camera preview and controls (Unchanged)
              Positioned(
                bottom: 24,
                left: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child:
                          _cameraGeminiService.controller != null &&
                              _cameraGeminiService
                                  .controller!
                                  .value
                                  .isInitialized
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: CameraPreview(
                                _cameraGeminiService.controller!,
                              ),
                            )
                          : const Center(child: CircularProgressIndicator()),
                    ),
                    const SizedBox(height: 8),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      mini: true,
                      onPressed: () async {
                        if (_cameraStreaming) {
                          await _stopCameraStreaming();
                        } else {
                          await _startCameraStreaming();
                        }
                      },
                      tooltip: _cameraStreaming
                          ? 'Stop Detection'
                          : 'Start Detection',
                      backgroundColor: _cameraStreaming
                          ? Colors.red
                          : Colors.blue,
                      child: Icon(
                        _cameraStreaming
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                  ],
                ),
              ),
              // Bluetooth connect/disconnect button
              // Positioned(
              //   top: 150,
              //   right: 24,
              //   child: Consumer(
              //     builder: (context, ref, child) {
              //       // final bluetoothService = ref.watch(bluetoothServiceProvider);
              //       return ElevatedButton(
              //         onPressed: () async {
              //           if (_bluetoothService.isConnected) {
              //             _bluetoothService.disconnect();
              //           } else {
              //             await _bluetoothService.connectToDevice();
              //           }
              //         },
              //         child: Text(
              //           _bluetoothService.isConnected
              //               ? 'Disconnect Bluetooth'
              //               : 'Connect Bluetooth',
              //         ),
              //       );
              //     },
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mapControlButton(IconData icon, VoidCallback onPressed) {
    // ... (unchanged)
    return Material(
      color: const Color(0xFF232323),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }

  // --- Unified location handling (Text-to-Navigation Entry Point) ---
  Future<void> _handleLocationRequest(String destination) async {
    // Handles 'current location' and string lookups.
    if (destination.toLowerCase() == 'current location') {
      try {
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
          ),
        );
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        String address;
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          address =
              '${place.name ?? ''}, ${place.street ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}, ${place.country ?? ''}';
        } else {
          address = 'Unknown address';
        }
        if (_voiceGuidance) {
          await _ttsService.speak('Your current location is $address');
        }
        final LatLng latLng = LatLng(position.latitude, position.longitude);
        setState(() {
          _markers.clear();
          _markers.add(
            Marker(
              markerId: MarkerId('current_location'),
              position: latLng,
              infoWindow: InfoWindow(title: 'Current Location'),
            ),
          );
          _polylines.clear(); // Clear route when moving to current location
        });
        mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
      } catch (e) {
        if (_voiceGuidance) {
          await _ttsService.speak(
            'Sorry, I could not fetch your current location.',
          );
        }
      }
    } else {
      // Use geocoding as the robust text fallback
      try {
        List<Location> locations = await locationFromAddress(destination);
        if (locations.isNotEmpty) {
          final location = locations.first;
          final LatLng destLatLng = LatLng(
            location.latitude,
            location.longitude,
          );
          // Call the unified map function
          await _drawRouteAndNavigate(destLatLng, destination);
        } else {
          if (_voiceGuidance) {
            await _ttsService.speak('Sorry, I could not find $destination');
          }
        }
      } catch (e) {
        print('Geocoding error for $destination: $e');
        if (_voiceGuidance) {
          await _ttsService.speak(
            'An error occurred while searching for $destination',
          );
        }
      }
    }
  }

  // NOTE: The original _searchLocation function is removed here.

  // Fetch route via Google Directions API and decode the overview_polyline (Unchanged)
  Future<List<LatLng>> _getRoutePoints(
    LatLng origin,
    LatLng destination,
  ) async {
    // ... (unchanged)
    try {
      final String originStr = '${origin.latitude},${origin.longitude}';
      final String destStr = '${destination.latitude},${destination.longitude}';
      final String key = googleMapsApiKey;
      final String url =
          'https://maps.googleapis.com/maps/api/directions/json?origin=$originStr&destination=$destStr&key=$key&mode=walking';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        print('Directions API error: ${response.statusCode}');
        return [];
      }

      final Map<String, dynamic> data = json.decode(response.body);
      if ((data['routes'] as List).isEmpty) return [];

      final overview = data['routes'][0]['overview_polyline']?['points'];
      if (overview == null || (overview as String).isEmpty) return [];

      return _decodePolyline(overview);
    } catch (e) {
      print('Directions API exception: $e');
      return [];
    }
  }

  // Decode an encoded polyline string into a list of LatLng (Unchanged)
  List<LatLng> _decodePolyline(String encoded) {
    // ... (unchanged)
    List<LatLng> points = [];
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
      int dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  void _showDetectedCommandDialog(String command) {
    // ... (unchanged)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        content: Text(
          'Detected command:\n$command',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  void _manualStartListening() async {
    // ... (unchanged)
    setState(() {
      _isListening = true;
    });
    if (_voiceGuidance) await _ttsService.speak('Listening...');
    await _speechService.listen(
      onResult: (recognizedText) async {
        setState(() {
          _isListening = false;
        });
        _showDetectedCommandDialog(recognizedText);

        // Use Gemini Maps Grounding API for navigation
        await _handleConversationalNavigation(recognizedText);
      },
      onError: (error) async {
        setState(() {
          _isListening = false;
        });
        if (_voiceGuidance) {
          await _ttsService.speak('Speech recognition error: $error');
        }
      },
    );
  }

  // Voice Command Handler
  Future<void> _handleConversationalNavigation(String command) async {
    final lowerCmd = command.toLowerCase();
    // 1. Check for "where am I" or "current location" intent
    if (lowerCmd.contains("where am i") ||
        lowerCmd.contains("what is my current location") ||
        lowerCmd.contains("where is my location") ||
        lowerCmd.contains("my location")) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
          ),
        );
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        String address;
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          address =
              '${place.name ?? ''}, ${place.street ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}, ${place.country ?? ''}';
          // If address is too vague, try to get a known place nearby
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
        if (_voiceGuidance) {
          await _ttsService.speak('Your current location is $address');
        }
        final LatLng latLng = LatLng(position.latitude, position.longitude);
        setState(() {
          _markers.clear();
          _markers.add(
            Marker(
              markerId: MarkerId('current_location'),
              position: latLng,
              infoWindow: InfoWindow(title: 'Current Location'),
            ),
          );
          _polylines.clear();
        });
        mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
      } catch (e) {
        if (_voiceGuidance) {
          await _ttsService.speak(
            'Sorry, I could not fetch your current location.',
          );
        }
      }
      return;
    }

    try {
      // 1. Get current location
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );
      final userLat = position.latitude;
      final userLng = position.longitude;

      // 2. Call Gemini Maps Grounding API
      final result = await _geminiService.getMapsGroundedDirections(
        apiKey: geminiApiKey,
        userLat: userLat,
        userLng: userLng,
        destination: command,
      );

      final instructions =
          result['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
      final groundingMetadata = result['groundingMetadata'];

      setState(() {
        _cameraAiResponse = instructions;
      });

      if (_voiceGuidance && instructions.isNotEmpty) {
        await _ttsService.speak(instructions);
      }

      // 3. Extract destination coordinates
      LatLng? destLatLng;
      String? etaText;
      if (groundingMetadata != null) {
        if (groundingMetadata['destinationLatLng'] != null) {
          final lat = groundingMetadata['destinationLatLng']['latitude'];
          final lng = groundingMetadata['destinationLatLng']['longitude'];
          destLatLng = LatLng(lat, lng);
        }
        if (groundingMetadata['estimatedTime'] != null) {
          etaText = groundingMetadata['estimatedTime'];
        }
      }

      // 4. Use unified function for map update and routing
      if (destLatLng != null) {
        final destinationLabel =
            '${command.substring(0, min(command.length, 30))}...';

        await _drawRouteAndNavigate(destLatLng, destinationLabel);

        if (_voiceGuidance && etaText != null && etaText.isNotEmpty) {
          await _ttsService.speak('Estimated time to destination is $etaText');
        }
      }
    } catch (e) {
      print('Error in conversational navigation: $e');
      if (_voiceGuidance) {
        await _ttsService.speak('Sorry, I could not get directions.');
      }
    }
  }

  // Helper: Find nearest known place using PlacesService
  Future<String?> _findNearestKnownPlace(double lat, double lng) async {
    try {
      final places = await _placesService.searchNearby(
        lat,
        lng,
        radius: 100,
      ); // radius in meters
      if (places.isNotEmpty) {
        return places.first['name'];
      }
    } catch (e) {
      print('Error finding nearest known place: $e');
    }
    return null;
  }

  void _stopListening() async {
    // ... (unchanged)
    await _speechService.stop();
    setState(() {
      _isListening = false;
    });
    if (_voiceGuidance) await _ttsService.speak('Stopped listening.');
  }

  Future<void> _requestMicPermission() async {
    // ... (unchanged)
    var status = await Permission.microphone.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      if (_voiceGuidance) {
        await _ttsService.speak(
          'Microphone permission denied. Please enable it in settings.',
        );
      }
      if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
    }
  }

  @override
  void dispose() {
    // ... (unchanged)
    _searchController.dispose();
    _cameraGeminiService.dispose();
    _cameraStreamTimer?.cancel();
    _speechService.stop();
    _ttsService.stop();
    mapController?.dispose();
    _bluetoothService.dispose();
    super.dispose();
  }
}
