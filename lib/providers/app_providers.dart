import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/tts_service.dart';
import '../services/speech_to_text_service.dart';
import '../services/gemini_service.dart';
import '../services/camera_gemini_service.dart';
import '../services/places_service.dart';
import '../core/constants.dart';

// Providers for core services (singleton-like providers)
final ttsServiceProvider = Provider<TtsService>((ref) {
  final tts = TtsService();
  ref.onDispose(() => tts.stop());
  return tts;
});

final speechServiceProvider = Provider<SpeechToTextService>((ref) {
  final speech = SpeechToTextService();
  // No explicit dispose method; stop if available in the widget
  return speech;
});

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});

final cameraGeminiServiceProvider = Provider<CameraGeminiService>((ref) {
  final service = CameraGeminiService();
  ref.onDispose(() => service.dispose());
  return service;
});

final placesServiceProvider = Provider(
  (ref) => PlacesService(AppConstants.googleMapsApiKey),
);
