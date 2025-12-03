/// Status bar widget displaying hardware connection status and current location.
/// Purely presentational UI component that reads from mapControllerProvider.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/map/map_controller.dart';

class StatusBarWidget extends ConsumerWidget {
  const StatusBarWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Placeholder for hardware status (to be implemented later)
    const bool hardwareConnected = true;
    
    // Read current location from map state
    // Format coordinates as location label
    final mapState = ref.watch(mapControllerProvider);
    final currentLocationLabel = '${mapState.mapCenter.latitude.toStringAsFixed(4)}, ${mapState.mapCenter.longitude.toStringAsFixed(4)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF).withOpacity(0.90),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Hardware/connection icon
          Icon(
            hardwareConnected ? Icons.check_circle : Icons.error,
            color: hardwareConnected ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          // Hardware status text
          Text(
            hardwareConnected ? 'Hardware OK' : 'Hardware Disconnected',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          // Location icon
          const Icon(
            Icons.location_on,
            color: Colors.black,
            size: 20,
          ),
          const SizedBox(width: 8),
          // Current location text
          Flexible(
            child: Text(
              currentLocationLabel,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

