/// Immutable state for the Bluetooth connection feature.
/// Tracks connection status, device information, and status messages.

enum BluetoothStatus { disconnected, connecting, connected, deviceNotConnected }

/// Enum to track last direction sent via Bluetooth
enum LastDirection { none, left, right }

class BluetoothConnectionState {
  const BluetoothConnectionState({
    required this.status,
    required this.statusMessage,
    this.isConnected = false,
    this.lastDirection = LastDirection.none,
  });

  factory BluetoothConnectionState.initial() {
    return const BluetoothConnectionState(
      status: BluetoothStatus.disconnected,
      statusMessage: 'Disconnected',
      isConnected: false,
      lastDirection: LastDirection.none,
    );
  }

  final BluetoothStatus status;
  final String statusMessage;
  final bool isConnected;
  final LastDirection lastDirection;

  /// Returns a new state with selective overrides.
  BluetoothConnectionState copyWith({
    BluetoothStatus? status,
    String? statusMessage,
    bool? isConnected,
    LastDirection? lastDirection,
  }) {
    return BluetoothConnectionState(
      status: status ?? this.status,
      statusMessage: statusMessage ?? this.statusMessage,
      isConnected: isConnected ?? this.isConnected,
      lastDirection: lastDirection ?? this.lastDirection,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BluetoothConnectionState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          statusMessage == other.statusMessage &&
          isConnected == other.isConnected &&
          lastDirection == other.lastDirection;

  @override
  int get hashCode =>
      status.hashCode ^
      statusMessage.hashCode ^
      isConnected.hashCode ^
      lastDirection.hashCode;
}