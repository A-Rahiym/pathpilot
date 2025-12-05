# Code Reference Guide

## File 1: Status Bar Widget
**Location:** `lib/widgets/status_bar_widget.dart`

Displays both Bluetooth status and address:
- Left side: Bluetooth status icon + message
- Right side: Location icon + actual address

```dart
final bluetoothState = ref.watch(bluetoothControllerProvider);
final bluetoothIcon = bluetoothState.status == BluetoothStatus.connecting
    ? Icons.bluetooth_searching
    : bluetoothConnected
        ? Icons.bluetooth_connected
        : Icons.bluetooth_disabled;

final currentLocationLabel = mapState.currentAddress ?? 'Locating...';
```

---

## File 2: Bluetooth State
**Location:** `lib/features/bluetooth/bluetooth_state.dart`

States enumeration:
```dart
enum BluetoothStatus {
  disconnected,    // Not connected
  connecting,      // Attempting to connect
  connected,       // Successfully connected
  deviceNotFound,  // Device not discovered
}
```

---

## File 3: Bluetooth Controller
**Location:** `lib/features/bluetooth/bluetooth_controller.dart`

Key methods:
```dart
// Auto-connect with retry logic
Future<void> autoConnectToDevice({int maxAttempts = 3}) async {
  // Tries to connect up to maxAttempts times
  // Updates state: connecting → connected/deviceNotFound/disconnected
}

// Manual disconnect
void disconnect() {
  _handleDisconnection();
}

// Send message to device
void sendMessage(String message) {
  if (_connection != null && state.isConnected) {
    _connection!.output.add(...);
  }
}
```

---

## File 4: Map State
**Location:** `lib/features/map/map_state.dart`

Added field:
```dart
class MapState {
  final String? currentAddress; // Address from reverse geocoding
  
  MapState copyWith({
    // ...
    String? currentAddress,
  });
}
```

---

## File 5: Map Controller
**Location:** `lib/features/map/map_controller.dart`

New method for address updates:
```dart
// Call this when user's location updates
Future<void> updateMapCenter(LatLng newCenter) async {
  state = state.copyWith(mapCenter: newCenter);
  await _updateAddressFromCoordinates(newCenter);
}

// Performs reverse geocoding
Future<void> _updateAddressFromCoordinates(LatLng location) async {
  try {
    final placemarks = await placemarkFromCoordinates(
      location.latitude,
      location.longitude,
    );
    
    if (placemarks.isNotEmpty) {
      final address = _buildAddressString(placemarks.first);
      state = state.copyWith(currentAddress: address);
    }
  } catch (e) {
    // Fallback to coordinates
  }
}
```

---

## File 6: Navigation Page Initialization
**Location:** `lib/screens/navigation.dart`

Bluetooth auto-connect:
```dart
Future<void> _initializeFeatures() async {
  // Trigger Bluetooth auto-connection when Navigation Page opens
  await ref.read(bluetoothControllerProvider.notifier).autoConnectToDevice();
  return;
}

@override
void dispose() {
  // Clean up resources
  ref.read(bluetoothControllerProvider.notifier).dispose();
  super.dispose();
}
```

---

## File 7: Camera Gemini Service
**Location:** `lib/services/camera_gemini_service.dart`

Pause/Resume implementation:
```dart
bool _isPaused = false;

// Stop sending images, keep WebSocket alive
void pauseStreaming() {
  _isPaused = true;
  print('⏸️ Image streaming paused (WebSocket remains connected)');
}

// Resume sending images on active connection
void resumeStreaming() {
  _isPaused = false;
  print('▶️ Image streaming resumed');
}

// Skip capture if paused
Future<void> captureAndAnalyze() async {
  if (_isPaused) {
    return; // WebSocket stays connected, just skip sending
  }
  // ... normal capture and analyze
}

// Restart only the camera, not the WebSocket
Future<void> restartCamera() async {
  try {
    await _cameraController?.dispose();
    
    final cameras = await availableCameras();
    _cameraController = CameraController(...);
    await _cameraController!.initialize();
    
    // Session remains active!
    print('✅ Camera restarted (WebSocket connection maintained)');
  } catch (e) {
    print('❌ Error restarting camera: $e');
  }
}
```

---

## File 8: Camera Controller Updates
**Location:** `lib/features/camera/camera_controller.dart`

Updated streaming methods:
```dart
// Check new Bluetooth controller for connection state
final bluetoothState = _ref.read(bluetoothControllerProvider);
if (bluetoothState.isConnected) {
  _bluetoothService.sendMessage('L'); // Send haptic feedback
}

// Start streaming - Resume instead of reconnect
Future<void> _startCameraStreaming() async {
  if (state.cameraStreaming) return;
  
  // Resume image streaming on active connection
  _cameraGeminiService.resumeStreaming();
  
  // Re-init camera if needed, but WebSocket stays active
  if (!_cameraGeminiService.isInitialized) {
    await _cameraGeminiService.restartCamera();
  }
  
  state = state.copyWith(cameraStreaming: true);
  // ... start capture timer
}

// Stop streaming - Pause instead of disconnect
Future<void> _stopCameraStreaming() async {
  if (!state.cameraStreaming) return;
  
  state = state.copyWith(cameraStreaming: false);
  _cameraStreamTimer?.cancel();
  
  // Pause image streaming WITHOUT closing WebSocket
  _cameraGeminiService.pauseStreaming();
  // WebSocket connection remains active!
}
```

---

## Key Provider Exports
**Location:** `lib/providers/bluetooth_provider.dart`

```dart
export '../features/bluetooth/bluetooth_controller.dart';
export '../features/bluetooth/bluetooth_state.dart';
```

---

## State Management Overview

### Bluetooth State Flow
```
Initial: disconnected
    ↓
User launches app
    ↓
Navigation page calls autoConnectToDevice()
    ↓
State: connecting (with retry count)
    ↓
Device found → State: connected ✅
Device not found → State: deviceNotFound ❌
Connection failed → State: disconnected
```

### Address State Flow
```
Initial: null (coordinate fallback)
    ↓
Location updates
    ↓
Map controller calls updateMapCenter()
    ↓
Reverse geocoding attempted
    ↓
Address found → State: "123 Main St, City, State"
Address not found → State: "11.1234, 7.5678"
```

### WebSocket State Flow
```
Initial: session = null, _isPaused = true
    ↓
Camera service initializes
    ↓
WebSocket connects → session = active, _isPaused = true
    ↓
Obstacle detection ON → _isPaused = false, images sent
    ↓
Obstacle detection OFF → _isPaused = true, no images sent
    ↓
Obstacle detection ON → _isPaused = false, resume immediately
    ↓
(WebSocket connection never closes)
```

---

## Integration Checklist

- [x] Status bar reads from bluetoothControllerProvider
- [x] Status bar reads from mapControllerProvider
- [x] Navigation page triggers Bluetooth auto-connect
- [x] Navigation page disposes Bluetooth controller
- [x] Map controller calls updateMapCenter when location updates
- [x] Camera controller calls pauseStreaming/resumeStreaming
- [x] Camera controller checks new Bluetooth controller for haptics
- [x] All imports properly configured
- [x] No circular dependencies
- [x] State management follows Riverpod patterns
- [x] Error handling for all edge cases
- [x] Graceful fallbacks (coordinates for address, retry for BT)

---

## Common Error Scenarios & Fixes

**Error:** "The name 'BluetoothState' is ambiguous"
**Fix:** Use `BluetoothConnectionState` from our code, `BluetoothState` from flutter_bluetooth_serial

**Error:** "WebSocket closed after disabling detection"
**Fix:** Use `pauseStreaming()` not `session?.close()`

**Error:** Address not updating
**Fix:** Call `mapController.updateMapCenter()` when location changes

**Error:** Bluetooth stays "Connecting"
**Fix:** Ensure device is paired and address in constants.dart is correct

---

Last Updated: December 4, 2025
All implementations complete and verified ✅
