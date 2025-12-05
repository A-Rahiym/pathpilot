/// Immutable state for the Bluetooth connection feature.
/// Tracks connection status, device information, and status messages.

enum BluetoothStatus { disconnected, connecting, connected, deviceNotFound }

class BluetoothConnectionState {
  const BluetoothConnectionState({
    required this.status,
    required this.statusMessage,
    this.isConnected = false,
  });

  factory BluetoothConnectionState.initial() {
    return const BluetoothConnectionState(
      status: BluetoothStatus.disconnected,
      statusMessage: 'Disconnected',
      isConnected: false,
    );
  }

  final BluetoothStatus status;
  final String statusMessage;
  final bool isConnected;

  /// Returns a new state with selective overrides.
  BluetoothConnectionState copyWith({
    BluetoothStatus? status,
    String? statusMessage,
    bool? isConnected,
  }) {
    return BluetoothConnectionState(
      status: status ?? this.status,
      statusMessage: statusMessage ?? this.statusMessage,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BluetoothConnectionState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          statusMessage == other.statusMessage &&
          isConnected == other.isConnected;

  @override
  int get hashCode =>
      status.hashCode ^ statusMessage.hashCode ^ isConnected.hashCode;
}
