/// Thin shell HomePage that assembles feature widgets in a Stack layout.
/// All business logic is delegated to feature controllers via Riverpod.
/// This page is purely presentational and coordinates feature widgets.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/camera/camera_controller.dart';
import '../features/camera/camera_panel.dart';
import '../features/map/map_controller.dart';
import '../features/map/map_widget.dart';
import '../features/speech/speech_controller.dart';
import '../providers/bluetooth_provider.dart';
import '../widgets/navigation_controls.dart';
import '../widgets/navigation_message_box.dart';
import '../widgets/status_bar_widget.dart';

class NavigationPage extends ConsumerStatefulWidget {
  const NavigationPage({super.key});

  @override
  ConsumerState<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends ConsumerState<NavigationPage> {
  @override
  void initState() {
    super.initState();
    // Initialize feature controllers after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFeatures();
    });

    // Listen for speech state changes to show detected command dialog
    // ref.listen<SpeechState>(speechControllerProvider, (previous, next) {
    //   if (next.detectedCommand != null &&
    //       next.detectedCommand != previous?.detectedCommand) {
    //     _showDetectedCommandDialog(next.detectedCommand!);
    //     ref.read(speechControllerProvider.notifier).clearDetectedCommandFlag();
    //   }

    //   if (next.errorMessage != null &&
    //       next.errorMessage != previous?.errorMessage) {
    //     _showErrorSnackBar(next.errorMessage!);
    //     ref.read(speechControllerProvider.notifier).clearErrorMessage();
    //   }
    // });

    // // Listen for search state changes to show errors
    // ref.listen(searchControllerProvider, (previous, next) {
    //   if (next.errorMessage != null &&
    //       next.errorMessage != previous?.errorMessage) {
    //     _showErrorSnackBar(next.errorMessage!);
    //     ref.read(searchControllerProvider.notifier).clearErrorMessage();
    //   }
    // });
  }

  /// Initializes all feature controllers (permissions, services, etc.)
  Future<void> _initializeFeatures() async {
    // Trigger Bluetooth auto-connection when Navigation Page opens
    await ref.read(bluetoothControllerProvider.notifier).autoConnectToDevice();

    // Speech controller handles its own initialization
    // Camera controller handles its own initialization
    // Map controller is ready immediately
    // Directions controller is ready immediately
    // Search controller is ready immediately
    return;
  }

  @override
  Widget build(BuildContext context) {
    final speechController = ref.read(speechControllerProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF232323),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () {
          speechController.startListening();
        },
        onLongPressUp: () {
          speechController.stopListening();
        },
        child: SafeArea(
          child: Stack(
            children: [
              // Map widget (full screen background)
              const MapWidget(),
              // 1. Status Bar (top)
              const Positioned(
                top: 24,
                left: 24,
                right: 24,
                child: StatusBarWidget(),
              ),
              // 2. Navigation message box
              const Positioned(
                top: 90,
                left: 24,
                right: 24,
                child: NavigationMessageBox(),
              ),
              // Map control button (recenter)
              Positioned(
                right: 24,
                bottom: 700,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    _MapControlButton(
                      onPressed: () async {
                        await ref
                            .read(mapControllerProvider.notifier)
                            .recenterMap();
                      },
                    ),
                  ],
                ),
              ),
              // 3. Navigation control buttons (bottom center)
              const Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: NavigationControls(),
              ),
              // Camera panel (bottom left overlay)
              const Positioned(bottom: 100, left: 24, child: CameraPanel()),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up feature controllers
    ref.read(mapControllerProvider.notifier).disposeController();
    ref.read(cameraControllerProvider.notifier).disposeController();
    ref.read(speechControllerProvider.notifier).disposeController();
    ref.read(bluetoothControllerProvider.notifier).dispose();
    super.dispose();
  }
}

/// Simple reusable explore/center button overlay for the map.
class _MapControlButton extends StatelessWidget {
  const _MapControlButton({required this.onPressed});

  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF232323),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          onPressed();
        },
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.explore, color: Colors.white),
        ),
      ),
    );
  }
}
