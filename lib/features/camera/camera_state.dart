/// Immutable state for the Camera feature.
/// Holds streaming status and AI response text for obstacle detection.
class CameraState {
  const CameraState({
    required this.cameraStreaming,
    required this.cameraAiResponse,
  });

  factory CameraState.initial() {
    return const CameraState(cameraStreaming: false, cameraAiResponse: '');
  }

  final bool cameraStreaming;
  final String cameraAiResponse;

  /// Returns a new state with selective overrides.
  CameraState copyWith({bool? cameraStreaming, String? cameraAiResponse}) {
    return CameraState(
      cameraStreaming: cameraStreaming ?? this.cameraStreaming,
      cameraAiResponse: cameraAiResponse ?? this.cameraAiResponse,
    );
  }
}
