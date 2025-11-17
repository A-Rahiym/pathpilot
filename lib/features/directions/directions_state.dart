/// Immutable state for the Directions/Navigation feature.
/// Currently minimal as most state is managed by MapController.
/// Can be extended for navigation-specific state like ETA, turn-by-turn instructions, etc.
class DirectionsState {
  const DirectionsState({
    required this.isNavigating,
    required this.currentDestination,
  });

  factory DirectionsState.initial() {
    return const DirectionsState(isNavigating: false, currentDestination: null);
  }

  final bool isNavigating;
  final String? currentDestination;

  /// Returns a new state with selective overrides.
  DirectionsState copyWith({bool? isNavigating, String? currentDestination}) {
    return DirectionsState(
      isNavigating: isNavigating ?? this.isNavigating,
      currentDestination: currentDestination ?? this.currentDestination,
    );
  }
}
