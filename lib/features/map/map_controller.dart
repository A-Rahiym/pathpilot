/// Controller for the Map feature.
/// Manages map markers, polylines, camera animations, and reverse geocoding for addresses.
/// Communicates with DirectionsController to receive route updates.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

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

  /// Updates the map center and performs reverse geocoding to get the address.
  /// This is called when the user's location updates.
  Future<void> updateMapCenter(LatLng newCenter) async {
    state = state.copyWith(mapCenter: newCenter);
    await _updateAddressFromCoordinates(newCenter);
  }

  /// Performs reverse geocoding to convert coordinates to a readable address.
  Future<void> _updateAddressFromCoordinates(LatLng location) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;

        // Build a readable address from the placemark
        final addressParts = <String>[];

        if (placemark.name != null && placemark.name!.isNotEmpty) {
          addressParts.add(placemark.name!);
        }
        if (placemark.street != null && placemark.street!.isNotEmpty) {
          addressParts.add(placemark.street!);
        }
        if (placemark.locality != null && placemark.locality!.isNotEmpty) {
          addressParts.add(placemark.locality!);
        }
        if (placemark.administrativeArea != null &&
            placemark.administrativeArea!.isNotEmpty) {
          addressParts.add(placemark.administrativeArea!);
        }

        final address = addressParts.isNotEmpty
            ? addressParts.join(', ')
            : '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';

        state = state.copyWith(currentAddress: address);
        print('📍 Address updated: $address');
      } else {
        // Fallback to coordinates if no placemark found
        final coordinateAddress =
            '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
        state = state.copyWith(currentAddress: coordinateAddress);
      }
    } catch (e) {
      print('❌ Error during reverse geocoding: $e');
      // Fallback to coordinates on error
      final fallbackAddress =
          '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
      state = state.copyWith(currentAddress: fallbackAddress);
    }
  }

  /// Disposes the map controller.
  void disposeController() {
    _mapController?.dispose();
  }
}
