/// Immutable state for the Map feature.
/// Holds markers, polylines, and camera position for rendering the Google Map.
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapState {
  const MapState({
    required this.markers,
    required this.polylines,
    required this.mapCenter,
  });

  factory MapState.initial() {
    return const MapState(
      markers: {},
      polylines: {},
      mapCenter: LatLng(11.15, 7.65), // ABU Zaria default
    );
  }

  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final LatLng mapCenter;

  /// Returns a new state with selective overrides.
  MapState copyWith({
    Set<Marker>? markers,
    Set<Polyline>? polylines,
    LatLng? mapCenter,
  }) {
    return MapState(
      markers: markers ?? this.markers,
      polylines: polylines ?? this.polylines,
      mapCenter: mapCenter ?? this.mapCenter,
    );
  }
}
