/// Immutable state for the Speech feature.
/// Holds listening status, detected commands, voice guidance toggle, and errors.
class SpeechState {
  const SpeechState({
    required this.isListening,
    required this.voiceGuidance,
    required this.detectedCommand,
    required this.errorMessage,
    required this.ttsMessage,
  });

  factory SpeechState.initial() {
    return const SpeechState(
      isListening: false,
      voiceGuidance: true,
      detectedCommand: null,
      errorMessage: null,
      ttsMessage: null,
    );
  }

  final bool isListening;
  final bool voiceGuidance;
  final String? detectedCommand;
  final String? errorMessage;
  final String? ttsMessage;

  /// Returns a new state with selective overrides.
  SpeechState copyWith({
    bool? isListening,
    bool? voiceGuidance,
    String? detectedCommand,
    bool clearDetectedCommand = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? ttsMessage,
    bool clearTtsMessage = false,
  }) {
    return SpeechState(
      isListening: isListening ?? this.isListening,
      voiceGuidance: voiceGuidance ?? this.voiceGuidance,
      detectedCommand: clearDetectedCommand
          ? null
          : detectedCommand ?? this.detectedCommand,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      ttsMessage: clearTtsMessage
          ? null
          : ttsMessage ?? this.ttsMessage,
    );
  }
}
