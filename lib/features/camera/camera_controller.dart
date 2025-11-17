/// Controller for the Camera feature.
/// Manages camera streaming, obstacle detection, and AI analysis.
/// Communicates with SpeechController for TTS feedback and BluetoothService for haptics.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../services/BluetoothService.dart';
import '../../services/camera_gemini_service.dart';
import '../../services/tts_service.dart';
import '../speech/speech_controller.dart';
import 'camera_state.dart';

final cameraControllerProvider =
    StateNotifierProvider<CameraController, CameraState>((ref) {
      return CameraController(ref);
    });

class CameraController extends StateNotifier<CameraState> {
  CameraController(this._ref)
    : _cameraGeminiService = _ref.read(cameraGeminiServiceProvider),
      _ttsService = _ref.read(ttsServiceProvider),
      super(CameraState.initial()) {
    _bluetoothService = BluetoothService(
      _handleBluetoothStatus,
      _handleBluetoothMessage,
    );
    _initCamera();
  }

  final Ref _ref;
  final CameraGeminiService _cameraGeminiService;
  final TtsService _ttsService;
  late final BluetoothService _bluetoothService;

  Timer? _cameraStreamTimer;
  bool _initialized = false;

  /// Initializes camera service and routes AI responses to feedback channels.
  Future<void> _initCamera() async {
    if (_initialized) return;
    _initialized = true;

    await _cameraGeminiService.initCamera();
    _cameraGeminiService.onAiResponse = (response) async {
      state = state.copyWith(cameraAiResponse: response);
      _cameraGeminiService.ttsBusy = true;

      // Bluetooth haptic feedback based on AI response
      final lowerResp = response.toLowerCase();
      if (_bluetoothService.isConnected) {
        if (lowerResp.contains('left') || lowerResp.contains('move left')) {
          _bluetoothService.sendMessage('L');
        }
        if (lowerResp.contains('right') || lowerResp.contains('move right')) {
          _bluetoothService.sendMessage('R');
        }
      }

      // TTS feedback (check voice guidance from speech state)
      final speechState = _ref.read(speechControllerProvider);
      if (speechState.voiceGuidance) {
        await _ttsService.stop();
        await _ttsService.speak(response);
      }
      _cameraGeminiService.ttsBusy = false;
    };
  }

  /// Toggles camera-driven obstacle detection.
  Future<void> toggleCameraStreaming() async {
    if (state.cameraStreaming) {
      await _stopCameraStreaming();
    } else {
      await _startCameraStreaming();
    }
  }

  /// Begins periodic capture/analysis loop for obstacle detection.
  Future<void> _startCameraStreaming() async {
    if (!_cameraGeminiService.isInitialized || state.cameraStreaming) return;
    state = state.copyWith(cameraStreaming: true);

    final speechState = _ref.read(speechControllerProvider);
    if (speechState.voiceGuidance) {
      await _ttsService.speak('Camera obstacle detection started');
    }

    _cameraStreamTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) async {
      if (!state.cameraStreaming) {
        timer.cancel();
        return;
      }
      if (!_cameraGeminiService.ttsBusy) {
        await _cameraGeminiService.captureAndAnalyze();
      }
    });
  }

  /// Stops the capture timer and notifies the user.
  Future<void> _stopCameraStreaming() async {
    if (!state.cameraStreaming) return;
    state = state.copyWith(cameraStreaming: false);
    _cameraStreamTimer?.cancel();
    await _cameraGeminiService.session?.close();

    final speechState = _ref.read(speechControllerProvider);
    if (speechState.voiceGuidance) {
      await _ttsService.speak('Obstacle detection stopped');
    }
  }

  /// Reacts to Bluetooth connectivity, giving audible confirmation + handshake.
  Future<void> _handleBluetoothStatus(bool connected, String message) async {
    final speechState = _ref.read(speechControllerProvider);
    if (connected && speechState.voiceGuidance) {
      await _ttsService.speak('Hardware device connected successfully');
      _bluetoothService.sendMessage("LRLRLRLRLRLRLRLRRLRLRLRLRLR");
    }
  }

  /// Records inbound Bluetooth messages for display/logging.
  void _handleBluetoothMessage(String message) {
    // Could be stored in state if needed for UI display
  }

  /// Disposes camera resources.
  Future<void> disposeController() async {
    _cameraStreamTimer?.cancel();
    await _cameraGeminiService.dispose();
    _bluetoothService.dispose();
  }
}
