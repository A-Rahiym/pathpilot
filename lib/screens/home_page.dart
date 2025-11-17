/// Thin shell HomePage that assembles feature widgets in a Stack layout.
/// All business logic is delegated to feature controllers via Riverpod.
/// This page is purely presentational and coordinates feature widgets.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/camera/camera_controller.dart';
import '../features/camera/camera_panel.dart';
import '../features/map/map_controller.dart';
import '../features/map/map_widget.dart';
import '../features/search/search_controller.dart';
import '../features/search/search_panel.dart';
import '../features/speech/listening_indicator.dart';
import '../features/speech/speech_controller.dart';
import '../features/speech/speech_state.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    // Initialize feature controllers after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFeatures();
    });

    // Listen for speech state changes to show detected command dialog
    ref.listen<SpeechState>(speechControllerProvider, (previous, next) {
      if (next.detectedCommand != null &&
          next.detectedCommand != previous?.detectedCommand) {
        _showDetectedCommandDialog(next.detectedCommand!);
        ref.read(speechControllerProvider.notifier).clearDetectedCommandFlag();
      }

      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        _showErrorSnackBar(next.errorMessage!);
        ref.read(speechControllerProvider.notifier).clearErrorMessage();
      }
    });

    // Listen for search state changes to show errors
    ref.listen(searchControllerProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        _showErrorSnackBar(next.errorMessage!);
        ref.read(searchControllerProvider.notifier).clearErrorMessage();
      }
    });
  }

  /// Initializes all feature controllers (permissions, services, etc.)
  Future<void> _initializeFeatures() async {
    // Speech controller handles its own initialization
    // Camera controller handles its own initialization
    // Map controller is ready immediately
    // Directions controller is ready immediately
    // Search controller is ready immediately
    return;
  }

  @override
  Widget build(BuildContext context) {
    final speechState = ref.watch(speechControllerProvider);
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
              // Search panel (top overlay)
              const Positioned(
                top: 24,
                left: 24,
                right: 24,
                child: SearchPanel(),
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
              // Listening indicator (bottom center overlay)
              const Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: ListeningIndicator(),
              ),
              // Camera panel (bottom left overlay)
              const Positioned(bottom: 24, left: 24, child: CameraPanel()),
              // Invisible tap area for voice activation (bottom right)
              Positioned(
                bottom: 0,
                right: 0,
                child: Opacity(
                  opacity: 0.15,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: 240,
                    child: InkWell(
                      onTap: speechState.isListening
                          ? () {
                              speechController.stopListening();
                            }
                          : () {
                              speechController.startListening();
                            },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Displays a transient dialog echoing recognized voice commands.
  void _showDetectedCommandDialog(String command) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        content: Text(
          'Detected command:\n$command',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  /// Shows errors surfaced by feature controllers as snack bars.
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    // Clean up feature controllers
    ref.read(mapControllerProvider.notifier).disposeController();
    ref.read(cameraControllerProvider.notifier).disposeController();
    ref.read(speechControllerProvider.notifier).disposeController();
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
