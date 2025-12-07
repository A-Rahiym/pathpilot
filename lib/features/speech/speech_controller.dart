/// Controller for the Speech feature.
/// Handles speech-to-text with Gemini function calling for intent extraction.
/// Local STT provides transcription, Gemini interprets intent via function calling.
/// Communicates with DirectionsController and CameraController for actions.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../../providers/app_providers.dart';
import '../../services/speech_to_text_service.dart';
import '../../services/tts_service.dart';
import '../../core/constants.dart';
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
      _geminiModel = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: AppConstants.googleStudiogeminikey,
      ),
      super(SpeechState.initial()) {
    _initialize();
  }

  final Ref _ref;
  final SpeechToTextService _speechService;
  final TtsService _ttsService;
  final GenerativeModel _geminiModel;
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

  /// Starts speech-to-text and processes transcription with Gemini function calling.
  /// Gemini extracts intent, then executes appropriate action.
  /// Falls back to traditional command matching if Gemini fails.
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
        // Try Gemini function calling first, fall back to keyword matching
        await _processTranscriptionWithGemini(recognizedText);
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

  /// Processes transcribed text with Gemini function calling.
  /// Extracts user intent and executes appropriate action.
  /// Falls back to keyword matching if Gemini fails.
  Future<void> _processTranscriptionWithGemini(String transcribedText) async {
    try {
      print(
        '🤖 Speech: Sending text to Gemini for intent extraction: "$transcribedText"',
      );

      // Define function schema for Gemini
      final tool = Tool(
        functionDeclarations: <FunctionDeclaration>[
          FunctionDeclaration(
            'execute_user_intent',
            'Extracts and executes the user intent from speech',
            Schema(
              SchemaType.object,
              properties: {
                'intent': Schema(
                  SchemaType.string,
                  description: 'The detected user intent',
                  enumValues: [
                    'where_am_i',
                    'start_detection',
                    'navigate_to',
                    'take_me_to',
                    'stop_navigation',
                  ],
                ),
                'destination': Schema(
                  SchemaType.string,
                  nullable: true,
                  description:
                      'Destination for navigate_to (ignored for other intents)',
                ),
              },
              requiredProperties: ['intent'],
            ),
          ),
        ],
      );

      // Send to Gemini with function calling
      final response = await _geminiModel.generateContent(
        [
          Content.text(
            '''Analyze the user speech, detect the language (English, Hausa, Yoruba, Igbo, or Nigerian Pidgin), then extract their intent after translating.
User speech:"$transcribedText"

Intents:
- "where_am_i": User wants their current location.
- "start_detection": User wants to start obstacle detection.
- "stop_detection": User wants to start obstacle detection.
- "navigate_to": User wants directions to a place.
- "take_me_to": User wants directions to a place.
- "stop_navigation": User wants to stop navigation.

If intent is "navigate_to", extract the destination.

After calling execute_user_intent(intent, destination) to return the result''',
          ),
        ],
        tools: [tool],
      );

      // Handle the response
      await _handleGeminiFunctionCall(response, transcribedText);
    } catch (e) {
      print('❌ Speech: Gemini error: $e, falling back to keyword matching');
      // Fallback to traditional keyword matching
      await _handleVoiceCommand(transcribedText);
    }
  }

  /// Handles function call response from Gemini.
  /// Extracts function call and executes the appropriate intent.
  Future<void> _handleGeminiFunctionCall(
    GenerateContentResponse response,
    String originalText,
  ) async {
    try {
      // Check if response contains function calls
      if (response.functionCalls.isEmpty) {
        print(
          '⚠️ Speech: No function calls in Gemini response, using fallback',
        );
        await _handleVoiceCommand(originalText);
        return;
      }

      // Get the first function call
      final functionCall = response.functionCalls.first;
      print(
        '✅ Speech: Function call - ${functionCall.name}, args: ${functionCall.args}',
      );

      // Extract intent and destination from function arguments
      final intent =
          functionCall.args['intent']?.toString().toLowerCase() ?? '';
      final destination = functionCall.args['destination']?.toString();

      print('✅ Speech: Parsed intent=$intent, destination=$destination');

      // Execute the intent
      await _executeIntent(functionCall.name, {
        'intent': intent,
        'destination': destination,
      });
    } catch (e) {
      print(
        '⚠️ Speech: Error processing function call: $e, falling back to keyword matching',
      );
      await _handleVoiceCommand(originalText);
    }
  }

  /// Executes the intent based on function name and arguments.
  /// Connects to appropriate controllers (DirectionsController, CameraController).
  Future<void> _executeIntent(
    String functionName,
    Map<String, dynamic> args,
  ) async {
    print('🔧 Speech: Executing intent - $functionName');

    final intent = args['intent']?.toString().toLowerCase() ?? '';
    final destination = args['destination']?.toString();

    final directionsController = _ref.read(
      directionsControllerProvider.notifier,
    );
    final cameraController = _ref.read(cameraControllerProvider.notifier);

    switch (intent) {
      case 'where_am_i':
        print('📍 Speech: Executing where_am_i');
        await directionsController.announceCurrentLocation();
        break;

      case 'start_detection':
        print('👁️ Speech: Executing start_detection');
        await cameraController.toggleCameraStreaming(command: 'on');
        break;

      case 'stop_detection':
        print('🛑 Speech: Executing stop_detection');
        await cameraController.toggleCameraStreaming(command: 'off');
        break;

      case 'navigate_to' || 'take_me_to':
        if (destination != null && destination.isNotEmpty) {
          print('🧭 Speech: Executing navigate_to - destination: $destination');
          await directionsController.handleConversationalNavigation(
            destination,
          );
        } else {
          print('⚠️ Speech: navigate_to without destination, asking user');
          if (state.voiceGuidance) {
            await _speak('Please specify a destination.');
          }
        }
        break;

      case 'stop_navigation':
        print('⛔ Speech: Executing stop_navigation');
        await directionsController.stopNavigation();
        break;
      default:
        print('❓ Speech: Unknown intent - $intent, falling back');
        // This shouldn't happen with proper function schema, but as safety
        break;
    }
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

    if (lowerCmd.contains('navigate to')) {
      await directionsController.navigateToLocation(
        command.replaceAll('navigate to', ''),
      );
      return;
    }

    if (lowerCmd.contains('take me to')) {
      // Handle navigation commands via conversational navigation
      await directionsController.handleConversationalNavigation(command);
    }

    if (lowerCmd.contains('stop navigation')) {
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

  /// Clears the TTS message from the UI.
  void clearTtsMessage() {
    state = state.copyWith(clearTtsMessage: true);
  }

  /// Public method to set the TTS message (called from other controllers).
  void setTtsMessage(String message) {
    state = state.copyWith(ttsMessage: message);
  }

  /// Toggles voice guidance on/off.
  void toggleVoiceGuidance() {
    state = state.copyWith(voiceGuidance: !state.voiceGuidance);
  }

  /// Safely performs TTS if voice guidance is enabled and text non-empty.
  Future<void> _speak(String message) async {
    if (!state.voiceGuidance || message.isEmpty) return;
    // Update state to display the TTS message in UI
    state = state.copyWith(ttsMessage: message);
    print('TTS about to be printed on the screen:$message');
    await _ttsService.stop();
    await _ttsService.speak(message);
  }

  /// Disposes speech resources.
  Future<void> disposeController() async {
    await _speechService.stop();
    await _ttsService.stop();
  }
}
