/// Navigation control buttons widget (Start, Pause, Listen).
/// Purely presentational UI component that calls controller methods.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/directions/directions_controller.dart';
import '../features/speech/speech_controller.dart';

class NavigationControls extends ConsumerWidget {
  const NavigationControls({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final directionsController = ref.read(directionsControllerProvider.notifier);
    final speechController = ref.read(speechControllerProvider.notifier);
    final directionsState = ref.watch(directionsControllerProvider);
return Row(
  children: [
    // START AREA
    Expanded(
      child: InkWell(
        onTap: () async {
          if (directionsState.isNavigating) return;

          if (directionsState.currentDestination != null) {
            await speechController.startListening();
          } else {
            await speechController.startListening();
          }
        },
        child: Container(
          height: 100, // Adjust height as needed
          color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.85),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.navigation, color: Colors.white, size: 64),
              SizedBox(height: 20),
              Text("Start", style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    ),

    // LISTEN AREA
    Expanded(
      child: InkWell(
        onTap: () async {
          final speechState = ref.read(speechControllerProvider);
          if (speechState.isListening) {
            await speechController.stopListening();
          } else {
            await speechController.startListening();
          }
        },
        child: Container(
          height: 100,
          color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.85),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.mic, color: Colors.white, size: 64),
              SizedBox(height: 20),
              Text("Listen", style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    ),

    // PAUSE AREA
    Expanded(
      child: InkWell(
        onTap: () async {
          if (directionsState.isNavigating) {
            await directionsController.stopNavigation();
          }
        },
        child: Container(
          height: 100,
          color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.85),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.pause, color: Colors.white, size: 64),
              SizedBox(height: 8),
              Text("Pause", style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    ),
  ],
);

  }
}

/// Individual control button with circular white background.
class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 60,
              height: 60,
              child: Icon(icon, color: Colors.black),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

