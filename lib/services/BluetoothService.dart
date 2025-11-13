import 'dart:async';
import 'dart:typed_data';
// import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:pathpilot/core/constants.dart';

// Define a callback type for state changes
typedef ConnectionStatusCallback =
    void Function(bool isConnected, String message);
typedef MessageReceivedCallback = void Function(String message);

class BluetoothService {
  final String deviceAddress = AppConstants.bluetoothDeviceAddress;
  BluetoothConnection? _connection;
  bool _isConnected = false;
  String _statusMessage = 'Ready to connect';

  // Callbacks for notifying the UI
  final ConnectionStatusCallback _onStatusChanged;
  final MessageReceivedCallback _onMessageReceived;

  BluetoothService(this._onStatusChanged, this._onMessageReceived);

  bool get isConnected => _isConnected;
  String get statusMessage => _statusMessage;

  void _updateStatus(bool connected, String message) {
    _isConnected = connected;
    _statusMessage = message;
    _onStatusChanged(_isConnected, _statusMessage);
  }

  Future<void> connectToDevice({int maxAttempts = 3}) async {
    int attempt = 0;
    bool connected = false;

    while (attempt < maxAttempts && !connected) {
      attempt++;
      try {
        _updateStatus(false, '🔍 Attempt $attempt: Searching for devices...');

        List<BluetoothDevice> devices = await FlutterBluetoothSerial.instance
            .getBondedDevices();

        BluetoothDevice? device;
        try {
          device = devices.firstWhere((d) => d.address == deviceAddress);
        } catch (_) {
          device = null;
        }

        if (device == null) {
          _updateStatus(false, '❗ Device not found (Attempt $attempt)');
          await Future.delayed(Duration(seconds: 1)); // Delay for better UX
          continue;
        }

        _updateStatus(
          false,
          '🔌 Attempt $attempt: Connecting to ${device.name ?? device.address}...',
        );

        _connection = await BluetoothConnection.toAddress(device.address);
        connected = true;

        _updateStatus(true, '✅ Connected to ${device.name ?? device.address}');

        // Start listening for incoming data
        _connection!.input
            ?.listen((Uint8List data) {
              final received = String.fromCharCodes(data);
              print('📥 Received data: $received');
              _onMessageReceived(received);
            })
            .onDone(() {
              print('🔌 Disconnected by remote device');
              _updateStatus(false, '🔌 Disconnected');
              // Re-establish connection or notify user
            });
      } catch (error) {
        print('❌ Attempt $attempt failed: $error');
        if (attempt >= maxAttempts) {
          _updateStatus(false, '❌ Connection failed after $attempt attempts');
        } else {
          await Future.delayed(
            Duration(seconds: 2),
          ); // Optional delay before retry
        }
      }
    }
  }

  void disconnect() {
    if (_isConnected && _connection != null) {
      _connection!.dispose();
      _connection!.finish();
      _updateStatus(false, '🔌 Disconnected manually');
    }
  }

  void sendMessage(String message) {
    if (_connection != null && _isConnected && message.isNotEmpty) {
      final formatted = "$message\r\n"; // Append newline if required by device
      _connection!.output.add(Uint8List.fromList(formatted.codeUnits));
      _connection!.output.allSent;

      print('📤 Sent: $formatted');
      _onMessageReceived('You: $formatted'); // Echo back to the local log/UI
    } else {
      print('⚠️ Cannot send: Not connected or message is empty.');
    }
  }

  void dispose() {
    disconnect();
  }
}
