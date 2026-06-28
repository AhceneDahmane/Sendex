import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class FirmwarePoint {
  final String version;
  final double lat;
  final double lng;
  final double speed;
  final double altitude;
  final double heartRate;
  final int satellites;
  final double hdop;
  final int battery;
  final double accel;

  FirmwarePoint({
    this.version = '',
    required this.lat,
    required this.lng,
    required this.speed,
    this.altitude = 0,
    this.heartRate = 0,
    this.satellites = 0,
    this.hdop = 99.9,
    this.battery = 0,
    this.accel = 0,
  });

  factory FirmwarePoint.fromJson(Map<String, dynamic> json) {
    return FirmwarePoint(
      version: json['v'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0,
      altitude: (json['alt'] as num?)?.toDouble() ?? 0,
      heartRate: (json['hr'] as num?)?.toDouble() ?? 0,
      satellites: (json['sat'] as num?)?.toInt() ?? 0,
      hdop: (json['hdop'] as num?)?.toDouble() ?? 99.9,
      battery: (json['bat'] as num?)?.toInt() ?? 0,
      accel: (json['accel'] as num?)?.toDouble() ?? 0,
    );
  }
}

enum BleConnectionState { disconnected, connecting, connected }

class BleService {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _cmdChar;
  StreamSubscription<List<int>>? _dataSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  final StreamController<FirmwarePoint> _dataController =
      StreamController<FirmwarePoint>.broadcast();
  final StreamController<List<ScanResult>> _scanController =
      StreamController<List<ScanResult>>.broadcast();
  final ValueNotifier<BleConnectionState> connectionState =
      ValueNotifier(BleConnectionState.disconnected);
  final ValueNotifier<int> batteryLevel = ValueNotifier(0);
  final ValueNotifier<String> firmwareVersion = ValueNotifier('');
  final ValueNotifier<bool> sessionActive = ValueNotifier(false);

  Stream<FirmwarePoint> get dataStream => _dataController.stream;
  Stream<List<ScanResult>> get scanStream => _scanController.stream;
  bool get isConnected => _device != null && connectionState.value == BleConnectionState.connected;
  BluetoothDevice? get device => _device;

  static const String serviceUuid = "FFF0";
  static const String dataCharUuid = "FFF1";
  static const String cmdCharUuid = "FFF2";

  void startScan() {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    FlutterBluePlus.scanResults.listen((results) {
      _scanController.add(results);
    });
  }

  void stopScan() {
    FlutterBluePlus.stopScan();
  }

  Future<void> connect(BluetoothDevice device) async {
    _device = device;
    connectionState.value = BleConnectionState.connecting;
    try {
      await device.connect();
      _connSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.connected) {
          connectionState.value = BleConnectionState.connected;
        } else {
          connectionState.value = BleConnectionState.disconnected;
        }
      });
      await _discoverServices();
    } catch (e) {
      connectionState.value = BleConnectionState.disconnected;
      rethrow;
    }
  }

  Future<void> _discoverServices() async {
    if (_device == null) return;
    final services = await _device!.discoverServices();
    for (final svc in services) {
      if (svc.uuid.toString().toUpperCase() == serviceUuid) {
        for (final chr in svc.characteristics) {
          final uuid = chr.uuid.toString().toUpperCase();
          if (uuid == dataCharUuid) {
            await chr.setNotifyValue(true);
            _dataSub = chr.onValueReceived.listen(_onDataReceived);
          } else if (uuid == cmdCharUuid) {
            _cmdChar = chr;
          }
        }
      }
    }
  }

  void _onDataReceived(List<int> data) {
    try {
      final json = utf8.decode(data);
      final parsed = jsonDecode(json) as Map<String, dynamic>;
      final point = FirmwarePoint.fromJson(parsed);
      if (point.battery > 0) batteryLevel.value = point.battery;
      if (point.version.isNotEmpty) firmwareVersion.value = point.version;
      _dataController.add(point);
    } catch (_) {}
  }

  Future<void> writeCommand(String cmd) async {
    if (_cmdChar == null) return;
    await _cmdChar!.write(utf8.encode(cmd));
    if (cmd == "START") sessionActive.value = true;
    if (cmd == "STOP") sessionActive.value = false;
  }

  Future<void> disconnect() async {
    await _dataSub?.cancel();
    await _connSub?.cancel();
    await _device?.disconnect();
    _device = null;
    _cmdChar = null;
    connectionState.value = BleConnectionState.disconnected;
    sessionActive.value = false;
  }

  void dispose() {
    _dataSub?.cancel();
    _connSub?.cancel();
    _dataController.close();
    _scanController.close();
    FlutterBluePlus.stopScan();
  }
}
