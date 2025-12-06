/// Controller for the Bluetooth feature.
/// Manages Bluetooth connection state, device pairing, and connection attempts.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import '../../core/constants.dart';
import 'bluetooth_state.dart';

final bluetoothControllerProvider =
    StateNotifierProvider<BluetoothController, BluetoothConnectionState>((ref) {
      return BluetoothController();
    });

class BluetoothController extends StateNotifier<BluetoothConnectionState> {
  BluetoothController() : super(BluetoothConnectionState.initial());

  final String deviceAddress = AppConstants.bluetoothDeviceAddress;
  BluetoothConnection? _connection;
  Timer? _connectionRetryTimer;

  /// Callback for message reception
  Function(String)? onMessageReceived;

  /// Automatically attempts to connect to the paired Bluetooth device.
  /// Tries up to [maxAttempts] times with delays between attempts.
  Future<void> autoConnectToDevice({int maxAttempts = 3}) async {
    int attempt = 0;
    bool connected = false;

    while (attempt < maxAttempts && !connected) {
      attempt++;

      try {
        // Update state: Connecting...
        state = state.copyWith(
          status: BluetoothStatus.connecting,
          statusMessage: 'Connecting... (Attempt $attempt/$maxAttempts)',
          isConnected: false,
        );

        // Get bonded devices
        final devices = await FlutterBluetoothSerial.instance
            .getBondedDevices();

        // Find our target device
        BluetoothDevice? targetDevice;
        try {
          targetDevice = devices.firstWhere((d) => d.address == deviceAddress);
        } catch (_) {
          targetDevice = null;
        }

        // Device not found
        if (targetDevice == null) {
          if (attempt >= maxAttempts) {
            state = state.copyWith(
              status: BluetoothStatus.deviceNotConnected,
              statusMessage: 'Device Not Connected',
              isConnected: false,
            );
            print('❌ Device not found after $attempt attempts');
            return;
          } else {
            // Retry with delay
            await Future.delayed(const Duration(seconds: 1));
            continue;
          }
        }

        // Attempt to connect
        _connection = await BluetoothConnection.toAddress(deviceAddress);
        connected = true;

        // Update state: Connected
        state = state.copyWith(
          status: BluetoothStatus.connected,
          statusMessage: 'Connected',
          isConnected: true,
        );

        print('✅ Connected to ${targetDevice.name ?? deviceAddress}');

        // Start listening for incoming data
        _connection!.input?.listen(
          (Uint8List data) {
            final received = String.fromCharCodes(data);
            print('📥 Received: $received');
            onMessageReceived?.call(received);
          },
          onDone: () {
            print('🔌 Disconnected by remote device');
            _handleDisconnection();
          },
          onError: (error) {
            print('❌ Connection error: $error');
            _handleDisconnection();
          },
        );
      } catch (error) {
        print('❌ Connection attempt $attempt failed: $error');

        if (attempt >= maxAttempts) {
          state = state.copyWith(
            status: BluetoothStatus.disconnected,
            statusMessage: 'Connection Failed',
            isConnected: false,
          );
          return;
        }

        // Wait before retry
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  /// Handles disconnection by updating state and cleaning up connection.
  void _handleDisconnection() {
    _connection?.dispose();
    _connection = null;
    state = state.copyWith(
      status: BluetoothStatus.disconnected,
      statusMessage: 'Disconnected',
      isConnected: false,
    );
  }

  /// Manually disconnect from the device.
  void disconnect() {
    _connectionRetryTimer?.cancel();
    _connection?.dispose();
    _connection?.finish();
    _handleDisconnection();
  }

  /// Sends a message to the connected device.
  void sendMessage(String message) {
    if (_connection != null && state.isConnected && message.isNotEmpty) {
      final formatted = "$message\r\n";
      _connection!.output.add(Uint8List.fromList(formatted.codeUnits));
      print('📤 Sent: $formatted');
    } else {
      print('⚠️ Cannot send: Not connected or message is empty.');
    }
  }

  /// Disposes Bluetooth resources.
  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
