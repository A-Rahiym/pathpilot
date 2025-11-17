/// Visual indicator displayed while speech recognition is active.
/// Consumes SpeechState via Riverpod to show/hide the indicator.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'speech_controller.dart';

class ListeningIndicator extends ConsumerWidget {
  const ListeningIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(speechControllerProvider);

    if (!state.isListening) {
      return const SizedBox.shrink();
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'Listening...',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
