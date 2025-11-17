/// Controller for the Search feature.
/// Handles Places autocomplete, geocoding fallback, and result selection.
/// Communicates with DirectionsController when a destination is selected.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../providers/app_providers.dart';
import '../../services/places_service.dart';
import '../directions/directions_controller.dart';
import '../map/map_controller.dart';
import 'search_state.dart';

final searchControllerProvider =
    StateNotifierProvider<SearchController, SearchState>((ref) {
      return SearchController(ref);
    });

class SearchController extends StateNotifier<SearchState> {
  SearchController(this._ref)
    : _placesService = _ref.read(placesServiceProvider),
      super(SearchState.initial());

  final Ref _ref;
  final PlacesService _placesService;

  /// Drives live search suggestions (Places autocomplete + geocoding fallback).
  Future<void> searchLocations(String query) async {
    if (query.isEmpty) {
      clearSearchResults();
      return;
    }

    try {
      // Get map center for bias (if available)
      final mapState = _ref.read(mapControllerProvider);
      double? biasLat = mapState.mapCenter.latitude;
      double? biasLng = mapState.mapCenter.longitude;

      final predictions = await _placesService.autocomplete(
        query,
        lat: biasLat,
        lng: biasLng,
      );

      if (predictions.isEmpty) {
        // Fallback to geocoding
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
  /// Delegates to DirectionsController to start navigation.
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

    final directionsController = _ref.read(
      directionsControllerProvider.notifier,
    );

    if (placeId.isNotEmpty) {
      final details = await _placesService.getPlaceDetails(placeId);
      if (details != null) {
        final destLatLng = LatLng(details['lat'], details['lng']);
        final finalLabel = details['formatted_address'] as String? ?? label;
        await directionsController.navigateToDestination(
          destLatLng,
          finalLabel,
        );
        return;
      }
    }

    if (result != null) {
      final destLatLng = LatLng(result.latitude, result.longitude);
      await directionsController.navigateToDestination(destLatLng, label);
      return;
    }

    // Final fallback: use text search
    await directionsController.navigateToLocation(label);
  }

  /// Entry point for text-based navigation requests.
  /// Delegates to DirectionsController.
  Future<void> handleLocationRequest(String destination) async {
    final directionsController = _ref.read(
      directionsControllerProvider.notifier,
    );
    await directionsController.navigateToLocation(destination);
  }

  /// Clears any shown error message to avoid repeated snack bars.
  void clearErrorMessage() {
    state = state.copyWith(clearErrorMessage: true);
  }
}
