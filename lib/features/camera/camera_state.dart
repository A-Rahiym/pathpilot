/// Immutable state for the Camera feature.
/// Holds streaming status, AI response text, and response queue configuration.
class CameraState {
  const CameraState({
    required this.cameraStreaming,
    required this.cameraAiResponse,
    required this.responseQueue,
    required this.queueProcessingInterval,
    required this.isProcessing,
  });

  factory CameraState.initial() {
    return const CameraState(
      cameraStreaming: false,
      cameraAiResponse: '',
      responseQueue: const [],
      queueProcessingInterval: Duration(
        seconds: 1,
      ), // Default 2 second interval
      isProcessing: false,
    );
  }

  final bool cameraStreaming;
  final String cameraAiResponse;
  final List<String> responseQueue; // Queue of collected AI responses
  final Duration
  queueProcessingInterval; // Time period between processing queue items
  final bool isProcessing; // Flag to track if currently processing a response

  /// Returns a new state with selective overrides.
  CameraState copyWith({
    bool? cameraStreaming,
    String? cameraAiResponse,
    List<String>? responseQueue,
    Duration? queueProcessingInterval,
    bool? isProcessing,
  }) {
    return CameraState(
      cameraStreaming: cameraStreaming ?? this.cameraStreaming,
      cameraAiResponse: cameraAiResponse ?? this.cameraAiResponse,
      responseQueue: responseQueue ?? this.responseQueue,
      queueProcessingInterval:
          queueProcessingInterval ?? this.queueProcessingInterval,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CameraState &&
          runtimeType == other.runtimeType &&
          cameraStreaming == other.cameraStreaming &&
          cameraAiResponse == other.cameraAiResponse &&
          responseQueue == other.responseQueue &&
          queueProcessingInterval == other.queueProcessingInterval &&
          isProcessing == other.isProcessing;

  @override
  int get hashCode =>
      cameraStreaming.hashCode ^
      cameraAiResponse.hashCode ^
      responseQueue.hashCode ^
      queueProcessingInterval.hashCode ^
      isProcessing.hashCode;
}
