/// Status bar widget displaying Bluetooth status, direction indicators, and current location (with reverse geocoding).
/// Reads from Bluetooth controller and map controller providers.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/map/map_controller.dart';
import '../providers/bluetooth_provider.dart';

class StatusBarWidget extends ConsumerWidget {
  const StatusBarWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read Bluetooth state
    final bluetoothState = ref.watch(bluetoothControllerProvider);

    // Read current location and address from map state
    final mapState = ref.watch(mapControllerProvider);
    final currentLocationLabel = mapState.currentAddress ?? 'Locating...';

    // Determine Bluetooth icon and color
    final bluetoothConnected = bluetoothState.isConnected;
    final bluetoothIcon = bluetoothState.status == BluetoothStatus.connecting
        ? Icons.bluetooth_searching
        : bluetoothConnected
        ? Icons.bluetooth_connected
        : Icons.bluetooth_disabled;

    final bluetoothColor = bluetoothState.status == BluetoothStatus.connecting
        ? Colors.orange
        : bluetoothConnected
        ? Colors.green
        : Colors.green;

    // Determine Bluetooth status text
    final bluetoothText = bluetoothState.statusMessage;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.20),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Bluetooth icon and status
          Icon(bluetoothIcon, color: bluetoothColor, size: 40),
          const SizedBox(width: 8),
          // Bluetooth status text
          Flexible(
            child: Text(
              bluetoothText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const Spacer(),

          // LEFT DIRECTION INDICATOR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bluetoothState.lastDirection == LastDirection.left
                  ? Colors.cyan
                  : const Color.fromARGB(255, 93, 56, 241),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.arrow_left,
              color: bluetoothState.lastDirection == LastDirection.left
                  ? Colors.black
                  : const Color.fromARGB(255, 255, 255, 255),
              size: 28,
            ),
          ),
          const SizedBox(width: 8),

          // RIGHT DIRECTION INDICATOR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bluetoothState.lastDirection == LastDirection.right
                 ? Colors.cyan
                : const Color.fromARGB(255, 93, 56, 241),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.arrow_right,
              color: bluetoothState.lastDirection == LastDirection.right
                  ? Colors.black
                  : const Color.fromARGB(255, 255, 255, 255),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),

          // Location icon
          const Icon(
            Icons.location_on,
            color: Color.fromARGB(255, 68, 1, 226),
            size: 40,
          ),
          const SizedBox(width: 8),
          // Current location text (address from reverse geocoding)
          Flexible(
            child: Text(
              currentLocationLabel,
              style: const TextStyle(
                color: Color.fromARGB(255, 255, 255, 255),
                fontSize: 28,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
