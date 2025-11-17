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

| Layer / Module        | Responsibility                                                                                          |
| --------------------- | ------------------------------------------------------------------------------------------------------- |
| `lib/features/home`   | Feature module for the home screen (state, controller, UI bindings).                                   |
| `HomeController`      | StateNotifier that orchestrates services (Places, Gemini, camera, TTS, Bluetooth, permissions, etc.).   |
| `HomeState`           | Immutable data snapshot consumed by the UI (markers, polylines, search results, voice flags, errors).   |
| `lib/services/*`      | Thin service wrappers around platform/HTTP SDKs (speech, TTS, Gemini, Google Places, Bluetooth, etc.).  |
| `lib/widgets`         | Reusable presentation widgets (`CustomMap`, navigation shell, etc.).                                   |
| Riverpod Providers    | Wire services and controller instances into the widget tree with clear lifetimes.                       |

### Directory Highlights

```
lib/
├─ core/constants.dart         # API keys, shared constants
├─ features/
│  └─ home/
│      └─ application/
│          ├─ home_state.dart  # Immutable UI state
│          └─ home_controller.dart  # Business logic + orchestration
├─ providers/app_providers.dart # Riverpod service providers
├─ services/                   # Speech, TTS, Gemini, Places, Camera, Bluetooth
└─ screens/
   ├─ homePage.dart           # UI layer (driven entirely by HomeState)
   └─ settingsPage.dart
```

---

## 🔄 Flowchart

```mermaid
flowchart TD
    User[(User)]
    UI[Home UI\n(search bar, gestures,\nmap, camera panel)]
    Controller[HomeController\n(StateNotifier)]
    State[HomeState\n(markers, polylines,\nflags, messages)]
    SpeechService[SpeechToTextService]
    GeminiService[GeminiService]
    PlacesService[PlacesService]
    CameraService[CameraGeminiService]
    TTS[TtsService]
    Bluetooth[BluetoothService]
    MapAPI[Google Maps\nDirections]
    Location[Geolocator / Permissions]

    User -->|Text input,\nlong press,\nbuttons| UI
    UI -->|Intents| Controller
    Controller -->|copyWith()| State
    State -->|ref.watch| UI

    Controller -->|startListening()| SpeechService -->|recognized text| Controller
    Controller -->|getMapsGroundedDirections()| GeminiService -->|instructions,\ndestination| Controller
    Controller -->|autocomplete()/nearby| PlacesService --> Controller
    Controller -->|captureAndAnalyze()| CameraService -->|AI response| Controller
    Controller -->|speak()| TTS
    Controller -->|sendMessage()| Bluetooth
    Controller -->|Directions API| MapAPI -->|polyline| Controller
    Controller -->|current position| Location
```

---

## 🚀 Getting Started

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

- **Voice navigation** – long-press anywhere, speak commands such as:
  - “Navigate to ABU Zaria Gate”
  - “Where am I?”
  - “Start obstacle detection”
- **Text search** – type in the search bar for live predictions; tap a result or
  use the “Navigate” button to draw a route.
- **Map controls** – use the explore button to re-center; markers show current
  location and target.
- **Camera panel** – tap the mini FAB to start/stop obstacle detection. Voice +
  Bluetooth cues indicate left/right guidance.

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