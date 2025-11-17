/// Immutable state for the Search feature.
/// Holds autocomplete results, place IDs, and UI visibility flags.
import 'package:geocoding/geocoding.dart';

class SearchState {
  const SearchState({
    required this.showSearchResults,
    required this.searchResults,
    required this.searchLabels,
    required this.searchPlaceIds,
    required this.pendingSearch,
    required this.errorMessage,
  });

  factory SearchState.initial() {
    return const SearchState(
      showSearchResults: false,
      searchResults: [],
      searchLabels: [],
      searchPlaceIds: [],
      pendingSearch: null,
      errorMessage: null,
    );
  }

  final bool showSearchResults;
  final List<Location> searchResults;
  final List<String> searchLabels;
  final List<String> searchPlaceIds;
  final String? pendingSearch;
  final String? errorMessage;

  /// Returns a new state with selective overrides.
  SearchState copyWith({
    bool? showSearchResults,
    List<Location>? searchResults,
    List<String>? searchLabels,
    List<String>? searchPlaceIds,
    String? pendingSearch,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return SearchState(
      showSearchResults: showSearchResults ?? this.showSearchResults,
      searchResults: searchResults ?? this.searchResults,
      searchLabels: searchLabels ?? this.searchLabels,
      searchPlaceIds: searchPlaceIds ?? this.searchPlaceIds,
      pendingSearch: pendingSearch ?? this.pendingSearch,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }
}
