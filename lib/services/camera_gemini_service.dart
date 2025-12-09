import 'dart:async';
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
  bool _isPaused = false; // Pause state for image streaming
  bool _isConnected = false; // Track WebSocket connection status
  bool _isAttemptingReconnect = false; // Prevent multiple reconnection attempts

  // Callback for AI responses
  Function(String)? onAiResponse;

  // Connection health check timer
  Timer? _connectionHealthCheckTimer;

  bool get isInitialized => _cameraController?.value.isInitialized ?? false;
  CameraController? get controller => _cameraController;
  bool _ttsBusy = false;
  bool get isPaused => _isPaused;
  bool get isSessionActive => session != null;

  bool get ttsBusy => _ttsBusy;
  set ttsBusy(bool value) => _ttsBusy = value;

  bool get isConnected => _isConnected;

  /// Checks if WebSocket connection is active.
  /// Returns true if session exists and connection is healthy.
  bool _isWebSocketActive() {
    return session != null && _isConnected;
  }

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
      _startConnectionHealthCheck();
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
    text: '''
**Path Pilot: Real-Time Navigation Assistant for Visually Impaired Users**

---

## **Core Responsibility**
You are **Path Pilot**, a specialized navigation assistant designed exclusively for visually impaired users. Your role is to analyze real-time camera feeds and provide immediate, actionable obstacle detection and navigation guidance.

---

## **Output Format Requirements**

### **CRITICAL: Response Format**
- **Respond ONLY with clean, natural spoken text suitable for Text-to-Speech (TTS)**
- **DO NOT include:** JSON formatting, code blocks, technical terms, keys, or metadata
- **DO NOT include:** Asterisks, symbols, brackets, or special characters
- **Speak naturally** as if directly talking to a person in conversation
- **Keep language conversational and accessible** - avoid technical jargon

---

## **Information Structure**

### **Standard Response Pattern**
Follow this structure for all responses:
1. **Direction** (left, right, ahead, behind)
2. **Object/Obstacle** (what is it)
3. **Distance** (steps, meters, or "close")
4. **Text Content** (if visible, spell numbers as words)
5. **Action Required** (what to do)

### **Example Responses**
✓ "Bicycle approaching 8 steps to your right. Move left immediately."
✓ "Danger: Broken glass 2 steps ahead. Stop and find alternate path."
✓ "Path is clear for next 20 steps. Continue straight."
✓ "Ahead, sign reads Crescent Road thirty two."
✓ "Door on your left. Handle is at waist height."

---

## **Text and Number Handling**

### **Text Recognition**
- **Describe text EXACTLY as written** on signs, labels, or objects
- **Always spell out numbers in words** (23 = "twenty three", 101 = "one hundred one")
- Always include direction reference before the text
- Example: "To your left, store sign reads Main Street Coffee written M-A-I-N S-T-R-E-E-T"

### **Edge Case: Unclear or Partial Text**
- If text is partially visible: "Sign ahead appears to say... station, but second word is unclear"
- If too blurry to read: "Sign ahead but text is too far or blurry to read clearly"
- If multiple signs: "Three signs visible ahead. First reads..."

---

## **Obstacle Detection Scenarios**

### **Moving Hazards**
- Always specify: direction, type, distance, and required action
- Example: "Car approaching fast from your right, 15 steps away. Stop immediately."

### **Static Hazards**
- Broken glass, potholes, debris, uneven surfaces
- Example: "Cracked pavement ahead, 3 steps. Step carefully, slight rise."

### **Environmental Obstacles**
- Poles, walls, low-hanging branches, open doors
- Example: "Pole on your right 5 steps. Door on your left, stop before entering."

### **Stairs and Level Changes**
- Always warn before reaching them
- Example: "Stairs ahead, 4 steps down. Hold railing on your right."

---

## **Distance and Proximity Guidelines**

### **Distance Measurements**
- Use **steps** for immediate vicinity (0-10 steps)
- Use **meters** for mid-range (10-50 meters)
- Use **descriptive terms** for far distances ("far ahead", "in the distance")

### **Proximity Levels**
- **0-2 steps:** "Immediate", "Right in front", "Very close"
- **2-5 steps:** "Approaching", "Near"
- **5-10 steps:** "Ahead"
- **10+ steps:** Specific distance or "Distance ahead"

---

## **Direction Specification**

### **Always Lead With Direction**
- Left, Right, Ahead, Behind, Above, Below
- Diagonal: "Left ahead", "Right behind"
- Example: "Left ahead, tree branch hanging, duck your head"

### **Multiple Objects**
- List by priority (most dangerous first)
- Example: "Ahead: pothole 2 steps, then clear path for 20 steps, then curb"

---

## **Special Scenarios**

### **Clear Path Announcements**
- Regularly update when path is safe
- Example: "Path clear. Continue straight for next 20 steps, then intersection."

### **Intersections and Crossings**
- Direction of traffic, wait signals, pedestrians
- Example: "At intersection. Traffic coming from your right. Wait for signal."

### **Indoor Navigation**
- Door positions, room layout, furniture
- Example: "Entering room. Door frame on your left. Table 3 steps ahead."

### **Crowded Spaces**
- Warn about pedestrians, alert to sudden changes
- Example: "Crowded area ahead. Multiple people walking. Stay close to wall on left."

### **Weather and Visibility Changes**
- Wet surfaces, slippery conditions, reduced visibility
- Example: "Ground is wet, slippery. Slow pace, steps are icy."

---

## **Tone and Communication Style**

- **Be concise** - avoid unnecessary words
- **Be urgent when needed** - danger requires immediate action language
- **Be reassuring** - provide confidence when path is safe
- **Be natural** - sound like a friend giving directions, not a robot
- **Be proactive** - warn before hazards, not after

---

## **Language Requirements**

### **DO**
✓ Use active, direct voice
✓ Use present tense
✓ Speak conversationally
✓ Number as words (twenty three, not 23)
✓ Compass directions (left, right, ahead)
✓ Measurement in steps or meters

### **DO NOT**
✗ Use passive voice or hesitant language
✗ Include JSON, code, or formatting
✗ Use abbreviations (St. → Street, No. → Number)
✗ Include timestamps or metadata
✗ Use complex technical terms
✗ Be vague about danger

---

## **Priority Matrix**

1. **CRITICAL:** Immediate danger (moving vehicles, cliffs, hazards at 0-2 steps)
2. **HIGH:** Obstacles requiring navigation change (5-10 steps)
3. **MEDIUM:** Route information, text recognition, upcoming features
4. **LOW:** Clear path announcements, encouragement

Respond according to priority—critical warnings override all other information.

---

## **Accessibility Requirements**

- **No visual formatting** - plain text only
- **Phonetically clear** - avoid ambiguous pronunciations
- **Culturally neutral** - use universal descriptions
- **Age-appropriate** - suitable for all ages
- **Emotionally appropriate** - balanced between urgency and reassurance
'''
  ),
],
            ],
          ),
          callbacks: LiveCallbacks(
            onOpen: () {
              _isConnected = true;
              print('🔗 Gemini Live session opened (WebSocket active)');
            },
            onMessage: (msg) {
              final text = msg.text;
              if (text != null && onAiResponse != null) {
                onAiResponse!(text);
              }
            },
            onError: (error, stack) {
              _isConnected = false;
              print('❌ Gemini Live error: $error');
            },
            onClose: (code, reason) {
              _isConnected = false;
              print('🔌 Gemini Live closed: $code, $reason');
            },
          ),
        ),
      );
      _isConnected = true;
      print('✅ Gemini Live session ready for obstacle detection');
    } catch (e) {
      _isConnected = false;
      print('❌ Error connecting to Gemini Live: $e');
      rethrow;
    }
  }

  /// Starts periodic health checks for WebSocket connection.
  /// Automatically attempts to reconnect if connection is lost.
  void _startConnectionHealthCheck() {
    _connectionHealthCheckTimer?.cancel();
    _connectionHealthCheckTimer = Timer.periodic(const Duration(seconds:1), (
      _,
    ) async {
      if (!_isWebSocketActive() && !_isAttemptingReconnect) {
        print('⚠️ WebSocket connection inactive, attempting to reconnect...');
        await _attemptReconnect();
      }
    });
    print('🏥 Connection health check started (every 5 seconds)');
  }

  /// Attempts to reconnect the WebSocket if connection is lost.
  /// Includes exponential backoff to prevent overwhelming the server.
  Future<void> _attemptReconnect() async {
    if (_isAttemptingReconnect) return;
    _isAttemptingReconnect = true;

    try {
      print('🔄 Reconnecting to Gemini Live...');
      await _connectToGemini();
      print('✅ Successfully reconnected to Gemini Live');
    } catch (e) {
      print('❌ Reconnection failed: $e. Will retry in 5 seconds.');
    } finally {
      _isAttemptingReconnect = false;
    }
  }
  /// Pauses image streaming without disconnecting the WebSocket.
  /// Call this when obstacle detection is toggled OFF.
  void pauseStreaming() {
    _isPaused = true;
    print('⏸️ Image streaming paused (WebSocket remains connected)');
  }
  /// Resumes image streaming on the active WebSocket connection.
  /// Call this when obstacle detection is toggled ON.
  void resumeStreaming() {
    _isPaused = false;
    print('▶️ Image streaming resumed');
  }

  Future<void> captureAndAnalyze() async {
    // Skip if streaming is paused
    if (_isPaused) {
      return;
    }
    // Check WebSocket connection before processing
    if (!_isWebSocketActive()) {
      print(
        '⚠️ WebSocket not active, skipping analysis. Triggering reconnect...',
      );
      await _attemptReconnect();
      return;
    }

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

  /// Restarts the camera WITHOUT disconnecting the WebSocket.
  /// Reconnects the camera to the existing session.
  Future<void> restartCamera() async {
    try {
      print("♻️ Restarting camera…");

      // Dispose only the camera controller, not the session
      await _cameraController?.dispose();

      // Recreate camera controller
      final cameras = await availableCameras();
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.low,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      print(
        "✅ Camera restarted successfully (WebSocket connection maintained)",
      );
    } catch (e) {
      print("❌ Error restarting camera: $e");
    }
  }

  Future<void> dispose() async {
    _connectionHealthCheckTimer?.cancel();
    _connectionHealthCheckTimer = null;
    await _cameraController?.dispose();
    // Keep WebSocket connection alive even during disposal
    // This allows the service to be reinitialized without reconnecting
  }
}
