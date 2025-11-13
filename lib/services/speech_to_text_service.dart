import 'package:speech_to_text/speech_to_text.dart';

class SpeechToTextService {
  final SpeechToText _speech = SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;

  Future<bool> init() async {
    _isAvailable = await _speech.initialize();
    return _isAvailable;
  }

  bool get isAvailable => _isAvailable;
  bool get isListening => _isListening;

  Future<void> listen({
    required Function(String recognizedText) onResult,
    Function(String error)? onError,
  }) async {
    print('STT listen called');
    if (!_isAvailable) {
      bool available = await init();
      print('STT initialized: $available');
      if (!available) {
        onError?.call('Speech recognition not available');
        print('STT not available');
        return;
      }
    }

    if (_isAvailable) {
      print('STT starting to listen...');
      _isListening = true;

      try {
        await _speech.listen(
          onResult: (result) {
            print('STT onResult: ${result.recognizedWords}');
            if (result.finalResult) {
              _isListening = false;
            }
            onResult(result.recognizedWords);
          },
          listenFor: const Duration(seconds: 10),
          pauseFor: const Duration(seconds: 3),
          cancelOnError: true,
          partialResults: false,
          onSoundLevelChange: null,
        );
      } catch (e) {
        print('STT listen error: $e');
        _isListening = false;
        onError?.call('Microphone access error: $e');
      }
    } else {
      onError?.call('Speech recognition not available');
      print('STT not available after init');
    }
  }

  Future<void> stop() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
  }

  Future<void> cancel() async {
    if (_isListening) {
      await _speech.cancel();
      _isListening = false;
    }
  }
}
