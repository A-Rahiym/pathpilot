/// Controller for the Speech feature.
/// Handles speech-to-text, voice commands, and TTS feedback.
/// Communicates with DirectionsController for navigation commands.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../providers/app_providers.dart';
import '../../services/speech_to_text_service.dart';
import '../../services/tts_service.dart';
import '../camera/camera_controller.dart';
import '../directions/directions_controller.dart';
import 'speech_state.dart';

final speechControllerProvider =
    StateNotifierProvider<SpeechController, SpeechState>((ref) {
      return SpeechController(ref);
    });

class SpeechController extends StateNotifier<SpeechState> {
  SpeechController(this._ref)
    : _speechService = _ref.read(speechServiceProvider),
      _ttsService = _ref.read(ttsServiceProvider),
      super(SpeechState.initial()) {
    _initialize();
  }

  final Ref _ref;
  final SpeechToTextService _speechService;
  final TtsService _ttsService;
  bool _initialized = false;

  /// One-time initialization for microphone permission and speech service.
  Future<void> _initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _requestMicPermission();
    await _speechService.init();
  }

  /// Requests microphone access and guides the user if denied.
  Future<void> _requestMicPermission() async {
    final status = await Permission.microphone.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      if (state.voiceGuidance) {
        await _speak(
          'Microphone permission denied. Please enable it in settings.',
        );
      }
      if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
    }
  }

  /// Starts speech-to-text and feeds recognized phrases into navigation logic.
  Future<void> startListening() async {
    state = state.copyWith(isListening: true);
    if (state.voiceGuidance) {
      await _speak('Listening...');
    }
    await _speechService.listen(
      onResult: (recognizedText) async {
        state = state.copyWith(
          isListening: false,
          detectedCommand: recognizedText,
        );
        await _handleVoiceCommand(recognizedText);
      },
      onError: (error) async {
        state = state.copyWith(
          isListening: false,
          errorMessage: 'Speech recognition error: $error',
        );
        if (state.voiceGuidance) {
          await _speak('Speech recognition error: $error');
        }
      },
    );
  }

  /// Stops the speech session and notifies the user.
  Future<void> stopListening() async {
    await _speechService.stop();
    state = state.copyWith(isListening: false, clearDetectedCommand: true);
    if (state.voiceGuidance) {
      await _speak('Stopped listening.');
    }
  }

  /// Handles voice commands and delegates to appropriate controllers.
  Future<void> _handleVoiceCommand(String command) async {
    final lowerCmd = command.toLowerCase();

    // Get directions controller for navigation
    final directionsController = _ref.read(
      directionsControllerProvider.notifier,
    );

    // Handle "where am I" / current location
    if (lowerCmd.contains('where am i') ||
        lowerCmd.contains('current location') ||
        lowerCmd.contains('where is my location') ||
        lowerCmd.contains('where am')) {
      await directionsController.announceCurrentLocation();
      return;
    }

    // Handle camera toggle
    if (lowerCmd.contains('detect')) {
      final cameraController = _ref.read(cameraControllerProvider.notifier);
      await cameraController.toggleCameraStreaming();
      return;
    }

    if(lowerCmd.contains('navigate to')) {
      await directionsController.navigateToLocation(command.replaceAll('navigate to', ''));
      return;
    } 
    
    if(lowerCmd.contains('take me to')) {
      // Handle navigation commands via conversational navigation
      await directionsController.handleConversationalNavigation(command);
    }

    if(lowerCmd.contains('stop navigation')) {
      await directionsController.stopNavigation();
      return;
    }
  }

/// Clears the detected command marker after the UI has reacted.
  void clearDetectedCommandFlag() {
    state = state.copyWith(clearDetectedCommand: true);
  }

/// Clears any shown error message to avoid repeated snack bars.
  void clearErrorMessage() {
    state = state.copyWith(clearErrorMessage: true);
  }

/// Toggles voice guidance on/off.
  void toggleVoiceGuidance() {
    state = state.copyWith(voiceGuidance: !state.voiceGuidance);
  }

/// Safely performs TTS if voice guidance is enabled and text non-empty.
  Future<void> _speak(String message) async {
    if (!state.voiceGuidance || message.isEmpty) return;
    await _ttsService.stop();
    await _ttsService.speak(message);
  }

  /// Disposes speech resources.
  Future<void> disposeController() async {
    await _speechService.stop();
    await _ttsService.stop();
  }
}
