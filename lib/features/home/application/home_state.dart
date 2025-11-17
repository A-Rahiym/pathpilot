/// Immutable snapshot of everything the home feature needs to render.
/// It centralizes markers/polylines, search results, voice/camera flags, and
/// transient feedback (detected commands, errors) for the controller + UI.
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

class HomeState {
  /// Builds immutable home state.
  const HomeState({
    required this.markers,
    required this.polylines,
    required this.isListening,
    required this.cameraStreaming,
    required this.voiceGuidance,
    required this.showSearchResults,
    required this.searchResults,
    required this.searchLabels,
    required this.searchPlaceIds,
    required this.pendingSearch,
    required this.cameraAiResponse,
    required this.receivedMessages,
    required this.mapCenter,
    required this.isInitializing,
    required this.detectedCommand,
    required this.errorMessage,
  });

  factory HomeState.initial() {
    return const HomeState(
      markers: {},
      polylines: {},
      isListening: false,
      cameraStreaming: false,
      voiceGuidance: true,
      showSearchResults: false,
      searchResults: [],
      searchLabels: [],
      searchPlaceIds: [],
      pendingSearch: null,
      cameraAiResponse: '',
      receivedMessages: [],
      mapCenter: LatLng(11.15, 7.65),
      isInitializing: true,
      detectedCommand: null,
      errorMessage: null,
    );
  }

  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final bool isListening;
  final bool cameraStreaming;
  final bool voiceGuidance;
  final bool showSearchResults;
  final List<Location> searchResults;
  final List<String> searchLabels;
  final List<String> searchPlaceIds;
  final String? pendingSearch;
  final String cameraAiResponse;
  final List<String> receivedMessages;
  final LatLng mapCenter;
  final bool isInitializing;
  final String? detectedCommand;
  final String? errorMessage;

  /// Returns a new state with selective overrides; helper flags clear
  /// transient fields without requiring null arguments.
  HomeState copyWith({
    Set<Marker>? markers,
    Set<Polyline>? polylines,
    bool? isListening,
    bool? cameraStreaming,
    bool? voiceGuidance,
    bool? showSearchResults,
    List<Location>? searchResults,
    List<String>? searchLabels,
    List<String>? searchPlaceIds,
    String? pendingSearch,
    String? cameraAiResponse,
    List<String>? receivedMessages,
    LatLng? mapCenter,
    bool? isInitializing,
    String? detectedCommand,
    bool clearDetectedCommand = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return HomeState(
      markers: markers ?? this.markers,
      polylines: polylines ?? this.polylines,
      isListening: isListening ?? this.isListening,
      cameraStreaming: cameraStreaming ?? this.cameraStreaming,
      voiceGuidance: voiceGuidance ?? this.voiceGuidance,
      showSearchResults: showSearchResults ?? this.showSearchResults,
      searchResults: searchResults ?? this.searchResults,
      searchLabels: searchLabels ?? this.searchLabels,
      searchPlaceIds: searchPlaceIds ?? this.searchPlaceIds,
      pendingSearch: pendingSearch ?? this.pendingSearch,
      cameraAiResponse: cameraAiResponse ?? this.cameraAiResponse,
      receivedMessages: receivedMessages ?? this.receivedMessages,
      mapCenter: mapCenter ?? this.mapCenter,
      isInitializing: isInitializing ?? this.isInitializing,
      detectedCommand: clearDetectedCommand
          ? null
          : detectedCommand ?? this.detectedCommand,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }
}
