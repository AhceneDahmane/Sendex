import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class GpsData {
  final double lat;
  final double lng;
  final double speed;

  GpsData({required this.lat, required this.lng, required this.speed});

  factory GpsData.fromJson(Map<String, dynamic> json) {
    return GpsData(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      speed: (json['speed'] as num).toDouble(),
    );
  }
}

class BleService {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _char;
  StreamSubscription<List<int>>? _sub;
  final StreamController<GpsData> _dataController =
      StreamController<GpsData>.broadcast();
  final StreamController<List<ScanResult>> _scanController =
      StreamController<List<ScanResult>>.broadcast();

  Stream<GpsData> get dataStream => _dataController.stream;
  Stream<List<ScanResult>> get scanStream => _scanController.stream;
  bool get isConnected => _device != null && _device!.isConnected;

  static const String serviceUuid = "FFF0";
  static const String charUuid = "FFF1";

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
    await device.connect();
    await _discoverServices();
  }

  Future<void> _discoverServices() async {
    if (_device == null) return;
    final services = await _device!.discoverServices();
    for (final svc in services) {
      if (svc.uuid.toString().toUpperCase() == serviceUuid) {
        for (final chr in svc.characteristics) {
          if (chr.uuid.toString().toUpperCase() == charUuid) {
            _char = chr;
            await chr.setNotifyValue(true);
            _sub = chr.onValueReceived.listen((data) {
              final json = utf8.decode(data);
              try {
                final parsed = jsonDecode(json) as Map<String, dynamic>;
                _dataController.add(GpsData.fromJson(parsed));
              } catch (_) {}
            });
          }
        }
      }
    }
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    await _device?.disconnect();
    _device = null;
    _char = null;
  }

  void dispose() {
    _sub?.cancel();
    _dataController.close();
    _scanController.close();
    FlutterBluePlus.stopScan();
  }
}
