/// Navigation message box displaying the current voice/navigation message.
/// Purely presentational UI component that reads from speechControllerProvider.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/speech/speech_controller.dart';

class NavigationMessageBox extends ConsumerWidget {
  const NavigationMessageBox({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speechState = ref.watch(speechControllerProvider);
    // Display TTS output (processed response) instead of raw command
    final displayText = speechState.ttsMessage ?? 'Waiting for input...';
    return Container(
      alignment: Alignment.center,
      height: 160,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 0, 0, 0).withValues(),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 30,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}