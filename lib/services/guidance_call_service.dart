/// Service to manage calls to the predefined Guidance Contact.
/// Uses url_launcher to initiate phone calls via native dialer.
/// Provides spoken instructions to the user via SpeechController integration.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../features/speech/speech_controller.dart';
import '../providers/app_providers.dart';

class GuidanceCallService {
  GuidanceCallService(this._ref);

  final Ref _ref;

  /// Predefined guidance contact number.
  /// TODO: Replace with your actual guidance contact number or fetch from settings.
  static const String _guidanceContactNumber = '+2348100000000';
  /// Helper method to speak a message using TtsService and updates SpeechController.
  /// Follows the same pattern as DirectionsController._speak().
  Future<void> _speak(String message) async {
    final speechState = _ref.read(speechControllerProvider);
    if (!speechState.voiceGuidance || message.isEmpty) return;

    // Update SpeechController to display the TTS message
    final speechController = _ref.read(speechControllerProvider.notifier);
    speechController.setTtsMessage(message);

    final ttsService = _ref.read(ttsServiceProvider);
    await ttsService.stop();
    await ttsService.speak(message);
  }

  /// Initiates a phone call to the Guidance Contact.
  /// Reads out instructions to the user before launching the dialer.
  ///
  /// Returns:
  /// - `true` if the call was successfully launched
  /// - `false` if the call could not be launched
  Future<bool> callGuidanceContact() async {
    try {
      final Uri telUri = Uri(scheme: 'tel', path: _guidanceContactNumber);

      print('📞 GuidanceCall: Checking if device can launch dialer...');

      // Speak instructions to user via SpeechController
      await _speak(
        'I will now open the phone dialer with your guidance contact.',
      );

      // Check if device can launch phone dialer
      if (await canLaunchUrl(telUri)) {
        print(
          '📞 GuidanceCall: Device can launch dialer. Initiating call to $_guidanceContactNumber',
        );

        // Speak confirmation
        await _speak(
          'Opening phone dialer now. Your guidance contact number is $_guidanceContactNumber.',
        );

        final bool launched = await launchUrl(telUri);

        if (launched) {
          print('✅ GuidanceCall: Phone dialer launched successfully');
          return true;
        } else {
          print('❌ GuidanceCall: Failed to launch phone dialer');
          await _speak('Failed to open the phone dialer.');
          return false;
        }
      } else {
        print(
          '❌ GuidanceCall: Device cannot launch phone dialer (no calling capability)',
        );
        await _speak('Your device does not have phone calling capability.');
        return false;
      }
    } catch (e) {
      print('❌ GuidanceCall: Error initiating call: $e');
      await _speak(
        'An error occurred while trying to call your guidance contact.',
      );
      return false;
    }
  }

  /// Updates the guidance contact number.
  /// TODO: Implement persistent storage (SharedPreferences, local database, etc.)
  Future<void> setGuidanceContactNumber(String phoneNumber) async {
    try {
      // Validate phone number format (basic check)
      if (phoneNumber.isEmpty) {
        throw Exception('Phone number cannot be empty');
      }
      print('✅ GuidanceCall: Guidance contact updated to $phoneNumber');
      // TODO: Save to persistent storage
    } catch (e) {
      print('❌ GuidanceCall: Error updating contact: $e');
      rethrow;
    }
  }
  /// Retrieves the current guidance contact number.
  /// TODO: Fetch from persistent storage if implemented.
  String getGuidanceContactNumber() {
    return _guidanceContactNumber;
  }
}
