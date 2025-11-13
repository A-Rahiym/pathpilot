import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart' as loc;

class CustomMap extends StatefulWidget {
  final Function(GoogleMapController)? onMapCreated;
  final Set<Marker> markers;
  final LatLng center;
  final Set<Polyline> polylines; // <-- Add this
  final double initialZoom; // <-- Add this

  const CustomMap({
    Key? key,
    this.onMapCreated,
    required this.markers,
    required this.center,
    this.initialZoom = 18.0, // Default zoom level
    this.polylines = const {}, // <-- Add this
  }) : super(key: key);

  @override
  State<CustomMap> createState() => _CustomMapState();
}

class _CustomMapState extends State<CustomMap> {
  final Completer<GoogleMapController> _controller = Completer();
  LatLng? _currentPosition;
  Set<Marker> _markers = {};
  loc.Location _location = loc.Location();

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  // Update markers when parent markers change
  @override
  void didUpdateWidget(CustomMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateMarkers();
  }

  void _updateMarkers() {
    if (_currentPosition != null) {
      setState(() {
        _markers = {
          // Add current position marker
          Marker(
            markerId: const MarkerId("current_position"),
            position: _currentPosition!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue,
            ),
            infoWindow: const InfoWindow(title: "Current Position"),
          ),
          // Add parent markers (destinations, etc.)
          ...widget.markers,
        };
      });
    } else {
      setState(() {
        _markers = widget.markers;
      });
    }
  }

  /// Initialize location
  Future<void> _initLocation() async {
    await _checkPermissions();
    await _getUserLocation();

    // Listen for continuous location updates
    _location.onLocationChanged.listen((loc.LocationData locData) {
      if (locData.latitude != null && locData.longitude != null) {
        final LatLng newPos = LatLng(locData.latitude!, locData.longitude!);
        if (mounted) {
          setState(() {
            _currentPosition = newPos;
          });
          _updateMarkers(); // Update markers with new position
        }
        _moveCamera(newPos);
      }
    });
  }

  /// Check permissions
  Future<void> _checkPermissions() async {
    bool serviceEnabled;
    try {
      serviceEnabled = await _location.serviceEnabled();
    } catch (e) {
      print('Location service status error: $e');
      return;
    }
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    loc.PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != loc.PermissionStatus.granted) return;
    }
  }

  /// Get one-shot user location
  Future<LatLng?> _getUserLocation() async {
    Position position = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    );

    final LatLng pos = LatLng(position.latitude, position.longitude);
    if (mounted) {
      setState(() {
        _currentPosition = pos;
      });
      _updateMarkers(); // Update markers with initial position
    }
    _moveCamera(pos);
    return pos;
  }

  /// Move camera smoothly
  Future<void> _moveCamera(LatLng target) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLng(target));
  }

  @override
  void dispose() {
    // Cancel subscriptions, timers, etc.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20.0),
      child: GoogleMap(
        onMapCreated: (GoogleMapController controller) {
          _controller.complete(controller);
          if (widget.onMapCreated != null) {
            widget.onMapCreated!(controller);
          }
        },
        initialCameraPosition: CameraPosition(
          target: widget.center,
          zoom: widget.initialZoom, // Use the initial zoom level
        ),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        markers: _markers, // Use internal markers
        polylines: widget.polylines, // Polylines are intact
      ),
    );
  }
}
