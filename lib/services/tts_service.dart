import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  Completer<void>? _completion;

  TtsService() {
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    await _tts.setLanguage('en-NG');
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.7);

    // Set Nigeria English voice if available
    try {
      List<dynamic> voices = await _tts.getVoices;
      // Look for Nigeria English voice
      final nigeriaNgVoice = voices.firstWhere(
        (voice) =>
            voice['name'].toString().toLowerCase().contains('nigeria') ||
            (voice['lang'].toString() == 'en-NG' &&
                voice['name'].toString().isNotEmpty),
        orElse: () => null,
      );
      if (nigeriaNgVoice != null) {
        await _tts.setVoice({
          "name": nigeriaNgVoice['name'],
          "locale": 'en-NG',
        });
        print('✅ Nigeria accent voice set: ${nigeriaNgVoice['name']}');
      } else {
        print('⚠️ Nigeria accent voice not found, using default en-NG');
      }
    } catch (e) {
      print('⚠️ Could not set Nigeria voice: $e');
    }

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      _completion?.complete();
    });

    _tts.setErrorHandler((msg) {
      print('TTS Error: $msg');
      _isSpeaking = false;
      _completion?.complete();
    });
  }

  Future<void> speak(String text) async {
    try {
      // Ensure TTS is ready
      await _tts.awaitSpeakCompletion(true);

      if (_isSpeaking) {
        await stop();
      }

      _isSpeaking = true;
      _completion = Completer<void>();

      // Add error handling
      final result = await _tts.speak(text);
      if (result == 1) {
        await _completion!.future;
      } else {
        print('TTS speak failed with result: $result');
        _isSpeaking = false;
        _completion?.complete();
      }
    } catch (e) {
      print('TTS speak error: $e');
      _isSpeaking = false;
      _completion?.complete();
    }
  }

  Future<void> stop() async {
    try {
      if (_isSpeaking) {
        await _tts.stop();
        _isSpeaking = false;
        _completion?.complete();
      }
    } catch (e) {
      print('TTS stop error: $e');
      _isSpeaking = false;
      _completion?.complete();
    }
  }

  // Add method for urgent alerts
  Future<void> speakUrgent(String text) async {
    await stop();
    await speak(text);
  }
}
