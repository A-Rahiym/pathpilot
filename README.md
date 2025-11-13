# 🧭 PathPilot

PathPilot is an advanced navigation assistant designed specifically for visually impaired users, combining voice interaction, real-time obstacle detection, and intuitive navigation features to provide a safer and more accessible way to navigate.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)
![Platform](https://img.shields.io/badge/platform-Android%20|%20iOS-lightgrey.svg)

## ✨ Features

### 🎤 Voice Interaction
- Wake word detection using Porcupine
- Natural language command processing
- Voice-activated navigation
- Text-to-speech feedback

### 🗺️ Navigation
- Real-time GPS tracking
- Google Maps integration
- Turn-by-turn directions
- Route visualization with polylines
- Current location detection

### 🎥 Safety Features
- Real-time obstacle detection
- Camera-based environment analysis
- Continuous scene monitoring
- Hazard alerts and warnings

### 🤖 AI Integration
- Gemini AI for command interpretation
- Real-time scene analysis
- Intelligent obstacle recognition
- Natural language processing

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (^3.7.2)
- Android Studio / Xcode
- API Keys:
  - Google Maps API key
  - Picovoice (Porcupine) Access key
  - Gemini API key

### Required Permissions
- Location access
- Camera access
- Microphone access
- Internet access

### Installation

1. Clone the repository:
```bash
git clone https://github.com/Abdoul2146/pathpilot.git
cd pathpilot
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure API keys:
   - Add your Google Maps API key in `android/app/src/main/AndroidManifest.xml`
   - Add your Porcupine access key in `lib/screens/homePage.dart`
   - Add your Gemini API key in `lib/screens/homePage.dart`

4. Run the application:
```bash
flutter run
```

## 📱 Usage

### Voice Commands
1. Activate the assistant using the wake word
2. Say your command naturally:
   - "Navigate to the library"
   - "Where am I?"
   - "Take me to the nearest restaurant"

### Obstacle Detection
- Enable camera monitoring using the eye icon
- Receive real-time alerts about obstacles
- Voice feedback for potential hazards

### Navigation
- Search for destinations using voice or text
- Follow the blue polyline route
- Receive turn-by-turn voice guidance
- View current location and destination markers

## 🛠️ Technical Architecture

### Key Components
- `CustomMap`: Custom Google Maps implementation
- `PorcupineService`: Wake word detection
- `SpeechToTextService`: Voice command processing
- `GeminiService`: AI command interpretation
- `CameraGeminiService`: Real-time scene analysis
- `TtsService`: Text-to-speech feedback

### Dependencies
```yaml
google_maps_flutter: ^2.12.3
speech_to_text: ^7.3.0
geocoding: ^4.0.0
permission_handler: ^12.0.1
flutter_tts: 4.2.3
porcupine_flutter: ^3.0.5
camera: ^0.11.2
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Google Maps Platform for navigation services
- Picovoice for Porcupine wake word detection
- Google's Gemini AI for natural language processing
- Flutter team for the amazing framework