import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:gemini_live/gemini_live.dart';
import '../core/constants.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';

class CameraGeminiService {
  CameraController? _cameraController;
  LiveSession? session;
  String? _latestImageBase64;
  bool _turnComplete = false;
  int _turnCount = 0;
  bool _isCapturing = false;

  // Callback for AI responses
  Function(String)? onAiResponse;

  bool get isInitialized => _cameraController?.value.isInitialized ?? false;
  CameraController? get controller => _cameraController;
  bool _ttsBusy = false;

  bool get ttsBusy => _ttsBusy;
  set ttsBusy(bool value) => _ttsBusy = value;

  Future<void> initCamera() async {
    try {
      final cameras = await availableCameras();
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.low,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      await _connectToGemini();
    } catch (e) {
      print('❌ Error initializing camera: $e');
    }
  }

  Future<void> _connectToGemini() async {
    final apiKey = AppConstants.geminiApiKey;
    final genAI = GoogleGenAI(apiKey: apiKey);

    try {
      session = await genAI.live.connect(
        LiveConnectParameters(
          model: 'gemini-2.0-flash-live-001',
          config: GenerationConfig(
            responseModalities: [Modality.TEXT],
            temperature: 0.2,
            maxOutputTokens: 50,
          ),
          systemInstruction: Content(
            parts: [
              Part(
                text:
                    'You are Path Pilot, a specialized navigation assistant for visually impaired users. '
                    'Analyze the camera feed and provide real-time obstacle detection and navigation guidance. '
                    'IMPORTANT: Respond ONLY with clean, spoken text. Do NOT include JSON formatting, keys, or technical terms. '
                    'Examples of good responses:\n'
                    '"Bicycle approaching 8 steps to your right. Move left immediately."\n'
                    '"Danger: Broken glass 2 steps ahead. Stop and find alternate path."\n'
                    '"Path is clear for next 20 steps. Continue straight."\n'
                    'Be concise, actionable, and speak naturally as if talking to a person.',
              ),
            ],
          ),
          callbacks: LiveCallbacks(
            onOpen: () => print('🔗 Gemini Live session opened'),
            onMessage: (msg) {
              final text = msg.text;
              if (text != null && onAiResponse != null) {
                onAiResponse!(text);
              }
            },
            onError: (error, stack) => print('❌ Gemini Live error: $error'),
            onClose: (code, reason) =>
                print('🔌 Gemini Live closed: $code, $reason'),
          ),
        ),
      );
      print('✅ Gemini Live session ready for obstacle detection');
    } catch (e) {
      print('❌ Error connecting to Gemini Live: $e');
    }
  }

  Future<void> captureAndAnalyze() async {
    if (_isCapturing) return;
    _isCapturing = true;

    if (!isInitialized || _cameraController!.value.isTakingPicture) {
      _isCapturing = false;
      return;
    }

    try {
      final image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      _latestImageBase64 = base64Image;

      _turnCount += 1;
      if (_turnCount >= 2) {
        _turnCount = 0;
        _turnComplete = true;
      }

      _sendAnalysisRequest(
        "Analyze the current scene for obstacles and hazards. Respond in one short sentence.",
      );
    } catch (e) {
      print("❌ Error capturing image: $e");
    } finally {
      _isCapturing = false;
    }
  }

  void _sendAnalysisRequest(String prompt) {
    if (_latestImageBase64 == null || session == null) return;

    session!.sendMessage(
      LiveClientMessage(
        clientContent: LiveClientContent(
          turns: [
            Content(
              role: "user",
              parts: [
                Part(text: prompt),
                Part(
                  inlineData: Blob(
                    mimeType: 'image/jpeg',
                    data: _latestImageBase64!,
                  ),
                ),
              ],
            ),
          ],
          turnComplete: _turnComplete,
        ),
      ),
    );

    if (_turnComplete) {
      _turnComplete = false;
    }
  }

  Future<void> restartCamera() async {
    try {
      print("♻️ Restarting camera…");

      // Dispose old instances safely
      await session?.close();
      await _cameraController?.dispose();

      // Recreate controller
      final cameras = await availableCameras();
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.low,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      await _connectToGemini();

      print("✅ Camera restarted successfully");
    } catch (e) {
      print("❌ Error restarting camera: $e");
    }
  }

  Future<void> dispose() async {
    await session?.close();
    await _cameraController?.dispose();
  }
}
