/// Controller for the Map feature.
/// Manages map markers, polylines, and camera animations.
/// Communicates with DirectionsController to receive route updates.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'map_state.dart';

final mapControllerProvider = StateNotifierProvider<MapController, MapState>((
  ref,
) {
  return MapController();
});

class MapController extends StateNotifier<MapState> {
  MapController() : super(MapState.initial());

  GoogleMapController? _mapController;

  /// Captures the GoogleMap controller when the widget finishes building.
  void onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  /// Updates markers on the map (e.g., destination, current location).
  void updateMarkers(Set<Marker> markers) {
    state = state.copyWith(markers: markers);
  }

  /// Updates route polylines on the map.
  void updatePolylines(Set<Polyline> polylines) {
    state = state.copyWith(polylines: polylines);
  }

  /// Clears all markers from the map.
  void clearMarkers() {
    state = state.copyWith(markers: {});
  }

  /// Clears all polylines from the map.
  void clearPolylines() {
    state = state.copyWith(polylines: {});
  }

  /// Animates the camera to a specific location with zoom level.
  Future<void> animateToLocation(LatLng location, double zoom) async {
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(location, zoom),
    );
  }

  /// Animates the camera back to the default center point.
  Future<void> recenterMap() async {
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: state.mapCenter, zoom: 12, tilt: 0, bearing: 0),
      ),
    );
  }

  /// Updates both markers and polylines (used by DirectionsController).
  void updateRoute({
    required Set<Marker> markers,
    required Set<Polyline> polylines,
  }) {
    state = state.copyWith(markers: markers, polylines: polylines);
  }

  /// Disposes the map controller.
  void disposeController() {
    _mapController?.dispose();
  }
}
