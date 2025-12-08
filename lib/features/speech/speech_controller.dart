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
import '../../services/guidance_call_service.dart';
import '../../services/nearby_places_service.dart';
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
      _guidanceCallService = _ref.read(guidanceCallServiceProvider),
      _nearbyPlacesService = _ref.read(nearbyPlacesServiceProvider),
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
  final GuidanceCallService _guidanceCallService;
  final NearbyPlacesService _nearbyPlacesService;
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
      await _speak('Listening for command...');
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
            'where_am_i',
            'Get the user’s current GPS location as text.',
            Schema(SchemaType.object, properties: {}),
          ),

          FunctionDeclaration(
            'start_detection',
            'Start real-time obstacle detection using the camera.',
            Schema(SchemaType.object, properties: {}),
          ),

          FunctionDeclaration(
            'stop_navigation',
            'Stop all navigation or guidance activity.',
            Schema(SchemaType.object, properties: {}),
          ),

          FunctionDeclaration(
            'call_guidance',
            'Trigger a phone call to the configured emergency or guidance number.',
            Schema(
              SchemaType.object,
              properties: {
                'phone': Schema(
                  SchemaType.string,
                  description: 'Phone number to call',
                ),
              },
            ),
          ),

          FunctionDeclaration(
            'take_me_to',
            'Start navigation to a specific destination.',
            Schema(
              SchemaType.object,
              properties: {
                'destination': Schema(
                  SchemaType.string,
                  description: 'The destination the user wants to navigate to.',
                ),
              },
            ),
          ),

          FunctionDeclaration(
            'get_nearby_places',
            'Retrieve nearby places using the already-existing PlacesService.',
            Schema(
              SchemaType.object,
              properties: {
                'category': Schema(
                  SchemaType.string,
                  nullable: true,
                  description:
                      'Optional category filter (e.g., hospital, restaurant, bank).',
                ),
              },
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
- "stop_detection": User wants to stop obstacle detection.
- "navigate_to": User wants directions to a place.
- "take_me_to": User wants directions/navigation to a place.
- "stop_navigation": User wants to stop navigation.
- "call_guidance": User wants to call their guidance contact.
- "get_nearby_places": User wants to know about nearby places around them.
If intent is "navigate_to" or "take_me_to", extract the destination.
Call execute_user_intent(intent, destination) to return the result.''',
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

      case 'call_guidance':
        print('☎️ Speech: Executing call_guidance');
        await _callGuidance();
        break;

      case 'get_nearby_places':
        print('🏢 Speech: Executing get_nearby_places');
        await _getNearbyPlaces();
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

    if (lowerCmd.contains('take me')) {
      // Handle navigation commands via conversational navigation
      await directionsController.handleConversationalNavigation(command);
    }

    if (lowerCmd.contains('stop navigation')) {
      await directionsController.stopNavigation();
      return;
    }
    if (lowerCmd.contains('near me')) {
      await _getNearbyPlaces();
      return;
    }
    if (lowerCmd.contains('call guide')) {
      await _callGuidance();
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

  /// Public speak method for use by other services.
  /// Safely performs TTS if voice guidance is enabled and text non-empty.
  Future<void> speak(String message) async {
    await _speak(message);
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

  /// Initiates a phone call to the predefined Guidance Contact.
  /// Provides spoken instructions via TtsService.
  Future<void> _callGuidance() async {
    try {
      print('📞 Speech: Executing call_guidance');

      // Call the Guidance Contact (which will provide spoken instructions)
      final bool success = await _guidanceCallService.callGuidanceContact();

      if (success) {
        print('✅ Speech: Guidance Contact call launched successfully');
      } else {
        print('❌ Speech: Failed to launch phone dialer');
      }
    } catch (e) {
      print('❌ Speech: Error calling Guidance: $e');
      if (state.voiceGuidance) {
        await _speak('Unable to call Guidance Contact at this time.');
      }
    }
  }

  /// Retrieves nearby places around the user's current location.
  /// Uses NearbyPlacesService to query Google Places API with user's location.
  /// Returns formatted list: \"Place Name (Type) - distance away\".
  Future<void> _getNearbyPlaces() async {
    try {
      print('🏢 Speech: Fetching nearby places...');
      if (state.voiceGuidance) {
        await _speak('Searching for nearby places...');
      }

      // Fetch nearby places
      final List<NearbyPlace> nearbyPlaces = await _nearbyPlacesService
          .getNearbyPlaces(
            radius: 500, // 500 meters
            type: '', // All types
          );

      if (nearbyPlaces.isEmpty) {
        print('⚠️ Speech: No nearby places found');
        if (state.voiceGuidance) {
          await _speak('No nearby places found in your area.');
        }
        return;
      }

      // Format response: limit to top 5 places
      final List<NearbyPlace> topPlaces = nearbyPlaces.take(5).toList();
      final String placesDescription = topPlaces
          .asMap()
          .entries
          .map(
            (entry) =>
                '${entry.key + 1}. ${entry.value.name} - ${entry.value.distanceMeters.toStringAsFixed(0)} meters away',
          )
          .join('. ');

      print('✅ Speech: Found ${topPlaces.length} nearby places');
      print('Speech: Top places: $placesDescription');

      if (state.voiceGuidance) {
        await _speak(
          'Found ${topPlaces.length} nearby places. $placesDescription',
        );
      }
    } catch (e) {
      print('❌ Speech: Error fetching nearby places: $e');
      if (state.voiceGuidance) {
        await _speak('Unable to retrieve nearby places at this time.');
      }
    }
  }

  /// Disposes speech resources.
  Future<void> disposeController() async {
    await _speechService.stop();
    await _ttsService.stop();
  }
}
