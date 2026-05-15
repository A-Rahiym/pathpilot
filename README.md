# 🧭 PathPilot

PathPilot is a Flutter assistant that fuses conversational navigation, obstacle
avoidance, and hardware feedback to help visually impaired travelers move
confidently through unfamiliar environments.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)
![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-lightgrey.svg)

---

## ✨ Core Capabilities

- **Voice-first navigation** – long-press anywhere to capture commands such as
  “navigate to the pharmacy” or “where am I?”
- **Text search + autocomplete** – Google Places predictions with geocoding
  fallback plus a one-tap “Navigate” action.
- **Turn-by-turn map guidance** – Google Maps polyline rendering, markers, and
  voice prompts for every new destination.
- **Camera obstacle detection** – continuous captures streamed to Gemini
  multimodal analysis plus tactile feedback through Bluetooth hardware.
- **Hands-free feedback** – speech-to-text, text-to-speech, and haptic cues keep
  users informed without looking at the screen.

---

## 🧱 Architecture Overview

| Layer / Module            | Responsibility                                                                                                    |
| ------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `lib/features/*/`         | Feature modules (speech, map, directions, camera, search, etc.) with controller, state, and UI components       |
| `*Controller`             | StateNotifier that manages feature logic and communicates with services and other controllers                     |
| `*State`                  | Immutable data snapshot consumed by UI (markers, polylines, listening flags, messages, errors)                   |
| `lib/services/*`          | Thin service wrappers around external APIs (Gemini, Google Maps/Places, speech-to-text, TTS, Bluetooth, camera) |
| `lib/widgets`             | Reusable presentation widgets (CustomMap, navigation controls, status bar, message box, camera panel)             |
| `lib/screens/`            | Page-level UI that assembles feature widgets and manages navigation (HomePage, NavigationPage, Settings, etc.)   |
| Riverpod Providers        | Singleton factories for services and feature notifiers; manage lifecycle and dependencies                        |
| `MainNav` (StatefulWidget)| Router widget that manages bottom navigation and page switching between Home, Map, Settings, Onboarding           |

### Directory Highlights

```
lib/
├─ core/constants.dart         # API keys (Gemini, Google Maps/Places, Bluetooth device), shared constants
├─ features/
│  ├─ speech/
│  │  ├─ speech_controller.dart      # Handles STT, Gemini intent parsing, and command execution
│  │  ├─ speech_state.dart           # Immutable state (listening flag, detected command, voice guidance flag)
│  │  └─ listening_indicator.dart    # UI for listening status
│  ├─ map/
│  │  ├─ map_controller.dart         # Manages markers, polylines, camera animations, reverse geocoding
│  │  ├─ map_state.dart              # Immutable state (markers, polylines, map center, current address)
│  │  └─ map_widget.dart             # GoogleMap widget
│  ├─ directions/
│  │  ├─ directions_controller.dart  # Route calculation, turn-by-turn guidance, navigation orchestration
│  │  └─ directions_state.dart       # Immutable state (destination, route, navigation flags)
│  ├─ camera/
│  │  ├─ camera_controller.dart      # Frame capture and obstacle detection via Gemini
│  │  ├─ camera_state.dart           # Immutable state (camera active flag, detected obstacles)
│  │  └─ camera_panel.dart           # Camera feed UI
│  ├─ search/
│  │  ├─ search_controller.dart      # Google Places autocomplete and geocoding
│  │  ├─ search_state.dart           # Immutable state (search results, loading flag)
│  │  └─ search_panel.dart           # Search UI with autocomplete
│  └─ bluetooth/
│     ├─ bluetooth_controller.dart   # Bluetooth device connection and message sending
│     └─ bluetooth_state.dart        # Immutable state (connected device, connection status)
├─ providers/
│  ├─ app_providers.dart             # Riverpod singleton providers for all services
│  └─ bluetooth_provider.dart        # Bluetooth service provider
├─ services/
│  ├─ gemini_service.dart            # Gemini LLM API wrapper (intent parsing + multimodal analysis)
│  ├─ camera_gemini_service.dart     # Camera controller + Gemini obstacle detection
│  ├─ places_service.dart            # Google Places autocomplete and geocoding
│  ├─ nearby_places_service.dart     # Nearby places discovery
│  ├─ speech_to_text_service.dart    # Speech-to-text via speech_to_text package
│  ├─ tts_service.dart               # Text-to-speech via flutter_tts
│  ├─ guidance_call_service.dart     # Guidance callback management
│  ├─ BluetoothService.dart          # Bluetooth communication with haptic hardware
│  └─ gemini_function_call.dart      # Gemini function call schema definitions
├─ screens/
│  ├─ home.dart                      # HomePage landing screen with action buttons
│  ├─ navigation.dart                # NavigationPage with map, camera, and controls
│  ├─ settings.dart                  # SettingsPage
│  └─ onboarding.dart                # OnboardingPage
├─ widgets/
│  ├─ main_nav.dart                  # Bottom nav router switching between pages
│  ├─ custom_map.dart                # Map utility widget
│  ├─ navigation_controls.dart       # Map controls (recenter, zoom, etc.)
│  ├─ navigation_message_box.dart    # Displays navigation messages and guidance
│  └─ status_bar_widget.dart         # Status display (connection, location, etc.)
└─ main.dart                         # App entry point; initializes ProviderScope and MainNav
```

---

## 🔄 Data Flow & Orchestration

```mermaid
flowchart TD
    User[(User)]
    MainNav[MainNav\nBottom Navigation<br/>Home|Map|Settings]
    Home[HomePage\nAction Buttons]
    NavPage[NavigationPage\nStack: Map, Camera,<br/>Controls, Messages]
    SpeechUI[Microphone Button]
    MapUI[GoogleMap Widget]
    
    SpeechController["SpeechController<br/>(StateNotifier)"]
    DirectionsController["DirectionsController<br/>(StateNotifier)"]
    MapController["MapController<br/>(StateNotifier)"]
    CameraController["CameraController<br/>(StateNotifier)"]
    BluetoothController["BluetoothController<br/>(StateNotifier)"]
    
    SpeechService[SpeechToTextService]
    GeminiService[GeminiService<br/>LLM Intent Parsing]
    DirectionsAPI[Google Directions API]
    PlacesAPI[Google Places API]
    CameraGemini[CameraGeminiService<br/>Multimodal Analysis]
    TTS[TtsService]
    Bluetooth[BluetoothService]
    Location[Geolocator]
    
    User -->|Tap buttons| Home
    User -->|Navigate| MainNav
    MainNav -->|Tab| NavPage
    NavPage -->|Listen| SpeechUI
    
    SpeechUI -->|Speak command| SpeechService
    SpeechService -->|Transcribed text| SpeechController
    SpeechController -->|Parse intent| GeminiService
    GeminiService -->|{intent, destination}| SpeechController
    
    SpeechController -->|navigate_to()| DirectionsController
    SpeechController -->|Speak response| TTS
    
    DirectionsController -->|Get current location| Location
    DirectionsController -->|Geocode destination| PlacesAPI
    DirectionsController -->|Route polyline| DirectionsAPI
    DirectionsController -->|updateRoute()| MapController
    
    MapController -->|copyWith()| MapUI
    MapUI -->|ref.watch| NavPage
    
    DirectionsController -->|Speak directions| TTS
    DirectionsController -->|Start camera| CameraController
    
    CameraController -->|Frame + prompt| CameraGemini
    CameraGemini -->|Obstacle detection| CameraController
    CameraController -->|Speak guidance| TTS
    CameraController -->|sendMessage()| BluetoothController
    
    BluetoothController -->|Haptic feedback| Bluetooth
```

### Key Execution Paths

**1. Voice Navigation (the main flow):**
- User presses microphone → `SpeechToTextService.listen()` captures audio → transcribed text sent to `SpeechController`
- `SpeechController` sends text to `GeminiService` (LLM API with function calling) to extract intent (e.g., "navigate") and destination
- If intent is "navigate", `SpeechController.startListening()` callback calls `DirectionsController.navigateToLocation(destination)`
- `DirectionsController` geocodes destination (Google Places), gets current user location (geolocator), calls Google Directions API for polyline
- Creates map markers and polylines, passes to `MapController.updateRoute()` to trigger UI update
- Animates map camera to show route, calls `TtsService.speak()` for turn-by-turn directions, starts camera obstacle detection

**2. Text Search (alternative entry point):**
- User types in search bar → `SearchController` queries `PlacesService` (Google Places autocomplete)
- User taps result → `DirectionsController.navigateToDestination()` executes same routing flow as above

**3. Obstacle Detection (continuous while navigating):**
- `CameraController` continuously captures frames from camera
- Sends frame + prompt to `CameraGeminiService` (Gemini multimodal) asking for left/right/stop guidance
- Response is spoken via `TtsService` and sent to `BluetoothController` for haptic feedback
- Loop continues until navigation ends or user stops camera

**4. Where Am I? (location awareness):**
- User asks or taps "Where Am I?" button
- `DirectionsController.announceCurrentLocation()` calls geolocator for current position
- `MapController._updateAddressFromCoordinates()` reverses geocode to get readable address
- Spoken via `TtsService`

---

## � State Management & Controller Pattern

PathPilot uses **Riverpod + StateNotifier** for predictable, testable state management. Each feature follows this layered pattern:

```dart
// 1. Immutable state class
class DirectionsState {
  final String? currentDestination;
  final bool isNavigating;
  final String? currentInstruction;
  
  DirectionsState copyWith({String? currentDestination, bool? isNavigating}) {
    return DirectionsState(
      currentDestination: currentDestination ?? this.currentDestination,
      isNavigating: isNavigating ?? this.isNavigating,
    );
  }
}

// 2. StateNotifier controller (business logic)
class DirectionsController extends StateNotifier<DirectionsState> {
  DirectionsController(Ref ref) : super(DirectionsState.initial()) {
    _ttsService = ref.read(ttsServiceProvider);
    _geminiService = ref.read(geminiServiceProvider);
  }
  
  Future<void> navigateToLocation(String destination) async {
    state = state.copyWith(isNavigating: true);
    // ... perform API calls and state updates
    state = state.copyWith(currentInstruction: "Head north");
  }
}

// 3. Riverpod provider (singleton factory)
final directionsControllerProvider = 
  StateNotifierProvider<DirectionsController, DirectionsState>((ref) {
    return DirectionsController(ref);
  });

// 4. In UI, watch state and call methods
ConsumerWidget build(BuildContext context, WidgetRef ref) {
  final directions = ref.watch(directionsControllerProvider);
  final controller = ref.read(directionsControllerProvider.notifier);
  
  return ElevatedButton(
    onPressed: () => controller.navigateToLocation("Pharmacy"),
    child: Text(directions.currentInstruction ?? "Navigate"),
  );
}
```

**Benefits:**
- **Immutability**: Every state change is a fresh instance (copyWith pattern)
- **Testability**: Controllers are pure Dart; no Flutter coupling
- **Performance**: Riverpod rebuilds only widgets watching changed state
- **Separation**: Controllers handle logic, state holds data, UI consumes both

---

## 🎙️ Speech Intent Parsing

[SpeechController](lib/features/speech/speech_controller.dart) is the command nerve center:

1. **Capture**: `SpeechToTextService.listen()` → transcribed text (e.g., "Navigate to pharmacy")
2. **Parse**: Text sent to **Gemini LLM with function calling** → returns structured intent:
   ```json
   {
     "intent": "navigate",
     "destination": "pharmacy"
   }
   ```
3. **Dispatch**: Based on intent, call appropriate controller:
   - `navigate` → `DirectionsController.navigateToLocation(destination)`
   - `show_camera` → `CameraController.startCapture()`
   - `location` → `DirectionsController.announceCurrentLocation()`
   - `stop_navigation` → `DirectionsController.stopNavigation()`

**Why function calling?** More reliable than parsing JSON from raw LLM output. Gemini enforces schema, so we always get valid structured data.

---

## 📍 Navigation Flow (Complete Example)

When user says **"Navigate to ABU Zaria Gate"**:

```
┌─ SpeechController.startListening()
├─ SpeechToTextService transcribes → "Navigate to ABU Zaria Gate"
├─ GeminiService.parseCommandLLM() → {intent: "navigate", destination: "ABU Zaria Gate"}
├─ SpeechController detects "navigate" → calls DirectionsController.navigateToLocation("ABU Zaria Gate")
├─ DirectionsController.navigateToDestination(LatLng, label):
│  ├─ Get current position (Geolocator)
│  ├─ Geocode destination (Google Places API)
│  ├─ Call Google Directions API → get polyline + turn-by-turn steps
│  ├─ Create markers (😊 current + 🚩 destination)
│  ├─ MapController.updateRoute(markers, polylines) → UI updates via ref.watch()
│  ├─ Animate camera to show full route
│  ├─ TtsService.speak("Head north on Main Street. 1 of 5 turns.")
│  └─ CameraController.startCapture() ← begin obstacle detection
├─ CameraController loop (every 1-2s):
│  ├─ Capture frame
│  ├─ CameraGeminiService: send frame + prompt → Gemini multimodal
│  ├─ Gemini response: "Clear ahead, small obstacle on your left at 5 meters"
│  ├─ TtsService.speak("Small obstacle on your left")
│  ├─ BluetoothController.sendMessage(haptic: "left") → haptic pulse to left arm
│  └─ loop continues...
├─ DirectionsController monitors location updates:
│  ├─ When ~50m from next turn: speak next instruction
│  ├─ When approaching destination: "Arriving at ABU Zaria Gate"
│  └─ On arrival: stop camera, clear route from map
└─ End
```

---

## 🤖 Gemini Multimodal Integration

PathPilot uses Gemini API in two ways:

### Intent Parsing (Text-based)
- **Model**: `gemini-2.0-flash`
- **Input**: Transcribed speech (string)
- **Output**: JSON with intent + destination
- **Purpose**: Command understanding
- **Called by**: SpeechController

### Obstacle Detection (Multimodal)
- **Model**: `gemini-2.0-flash-exp` (vision + text)
- **Input**: Camera frame (image) + detailed prompt
- **Output**: Guidance string ("Clear ahead", "Obstacle 2m on left", etc.)
- **Purpose**: Real-time scene understanding for navigation safety
- **Called by**: CameraController (every 1-2 seconds while navigating)
- **Integration**: Response is spoken via TTS + sent to Bluetooth for haptic feedback

**Sample obstacle detection prompt:**
```
You are helping a blind user navigate outdoors. Analyze this image and describe
any immediate hazards or obstacles. Focus on three directions: left, center, right.
Be concise and actionable. Examples:
- "Clear ahead, watch out for step up on your right"
- "Obstacle on your left 2 meters, clear ahead"
- "Safe, no obstacles detected"
```

---

## 🗺️ Map & Route Rendering

**MapController** ([lib/features/map/map_controller.dart](lib/features/map/map_controller.dart)):
- Manages **markers** (current location 🟡, destination 📍)
- Manages **polylines** (route path from Google Directions API)
- Handles **camera animations** (pan, zoom, recenter)
- Performs **reverse geocoding** (lat/lng → readable address for "Where Am I?")

**DirectionsController** ([lib/features/directions/directions_controller.dart](lib/features/directions/directions_controller.dart)):
- Calls Google Directions API for polyline + turn-by-turn steps
- Tracks current navigation segment + next instruction
- Computes distance to next turn + ETA
- Coordinates with MapController to render route

**UI is lightweight:**
```dart
// In NavigationPage
final mapState = ref.watch(mapControllerProvider);
GoogleMap(
  markers: mapState.markers,       // 🟡 current + 📍 destination
  polylines: mapState.polylines,   // Route path
  // ...
)
```
Riverpod automatically rebuilds GoogleMap only when markers/polylines change.

---

## 🎬 Camera & Real-Time Obstacle Detection

**CameraController** ([lib/features/camera/camera_controller.dart](lib/features/camera/camera_controller.dart)):
1. Requests camera permission (permission_handler)
2. Opens native camera (camera package)
3. Captures frames in loop (every 1-2 seconds)
4. Sends each frame to **CameraGeminiService** with obstacle prompt
5. Parses Gemini response (obstacle direction, confidence)
6. Speaks guidance via TTS
7. Sends haptic cue via Bluetooth (left/right/stop)
8. Continues until user stops or navigation ends

**Why continuous capture?** Static scene description from one frame isn't enough. Visually impaired users need real-time feedback as they move and obstacles appear/disappear.

---

## �🚀 Getting Started

### Prerequisites

- Flutter SDK 3.7+ (uses Dart 3 features)
- Android Studio or Xcode toolchain
- API keys (configure inside `AppConstants` or your preferred secrets store):
  - Google Maps (Maps SDK + Directions + Places)
  - Gemini API key

### Required Permissions

- Location (foreground, precise)
- Camera
- Microphone
- Bluetooth (optional but recommended for haptic hardware)
- Internet

### Installation

```bash
git clone https://github.com/Abdoul2146/pathpilot.git
cd pathpilot
flutter pub get
```

Update `lib/core/constants.dart` (or dotenv/secure storage) with your API keys,
then run:

```bash
flutter run
```

---

## 📱 Usage Cheatsheet

### Home Page (Landing Screen)
- **Microphone Button** (large blue circle) – Tap to start voice input; speak commands
- **Start Navigation** – Switch to map page
- **Where Am I?** – Announces current location (street address)
- **Object Detection** – Manually start camera obstacle detection

### Map Page (Navigation Hub)
- **Map** – Shows live location (blue marker), destination (red marker), and routed path (polyline)
- **Navigation Controls** – Recenter map, zoom in/out
- **Message Box** – Displays current instruction, status messages, errors
- **Floating Action Button** – Start/stop camera for real-time obstacle detection
- **Status Bar** – Shows Bluetooth connection status, current location, GPS accuracy

### Voice Commands
- *"Navigate to [destination]"* – Start turn-by-turn navigation
- *"Where am I?"* – Announce current location address
- *"Show camera"* – Start obstacle detection
- *"Hide camera"* – Stop obstacle detection
- *"Help" / "User guide"* – Play onboarding instructions
- *"Stop navigation"* – End current navigation

### Interaction Patterns
- **Voice-first**: Designed for hands-free use; tap mic button
- **Audio feedback**: Every action is announced via TTS
- **Haptic feedback**: Bluetooth hardware sends left/right/stop pulses during navigation
- **Visual fallback**: Map and text display for sighted users or reference

---

## 🧩 Key Dependencies

```yaml
flutter_riverpod: ^2.5.0
google_maps_flutter: ^2.12.0
geocoding: ^4.0.0
geolocator: ^10.0.0
camera: ^0.11.0
speech_to_text: ^7.0.0
flutter_tts: ^4.0.0
permission_handler: ^12.0.0
```

*(Exact versions may vary; check `pubspec.yaml` for the authoritative list.)*

---

## 🤝 Contributing

1. Fork the repo & create a feature branch (`git checkout -b feature/xyz`).
2. Run `flutter format` / `dart format` and `dart analyze` before committing.
3. Submit a concise pull request describing the change and testing steps.

---

## 📄 License & Credits

PathPilot is distributed under the MIT License. See [LICENSE](LICENSE) for
details.

Special thanks to:

- Google Maps Platform (Maps, Places, Directions SDKs)
- Google Gemini multimodal APIs
- Flutter & Riverpod communities