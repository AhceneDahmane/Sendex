import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ble_service.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final BleService _ble = BleService();
  final Random _rng = Random();
  Timer? _simTimer;
  GpsData? _data;
  bool _scanning = false;
  bool _simulating = false;
  String _status = "Tap scan or simulate";

  double _simLat = 48.8566;
  double _simLng = 2.3522;

  @override
  void initState() {
    super.initState();
    _ble.dataStream.listen((d) => setState(() => _data = d));
    _ble.scanStream.listen((results) {
      if (!mounted) return;
      _showDevices(results);
    });
  }

  void _startSimulate() {
    _simulating = true;
    _status = "Simulating...";
    _simTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final speed = (_rng.nextDouble() * 3).toStringAsFixed(1);
      _simLat += (_rng.nextDouble() - 0.5) / 10000;
      _simLng += (_rng.nextDouble() - 0.5) / 10000;
      setState(() {
        _data = GpsData(
          lat: _simLat,
          lng: _simLng,
          speed: double.parse(speed),
        );
      });
    });
  }

  void _stopSimulate() {
    _simTimer?.cancel();
    setState(() {
      _simulating = false;
      _status = "Simulation stopped";
    });
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  void _startScan() async {
    await _requestPermissions();
    setState(() {
      _scanning = true;
      _status = "Scanning...";
    });
    _ble.startScan();
  }

  void _showDevices(List<ScanResult> results) {
    final devices = results
        .where((r) => r.device.platformName.contains("Sendex"))
        .toList();
    if (!mounted || devices.isEmpty) return;

    _ble.stopScan();
    setState(() => _status = "Connecting...");
    _ble.connect(devices.first.device).then((_) {
      setState(() {
        _scanning = false;
        _status = "Connected to ${devices.first.device.platformName}";
      });
    });
  }

  @override
  void dispose() {
    _simTimer?.cancel();
    _ble.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sendex")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _DataCard(data: _data),
            const SizedBox(height: 20),
            Text(_status, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            if (!_ble.isConnected && !_simulating)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _scanning ? null : _startScan,
                    icon: Icon(_scanning ? Icons.bluetooth_searching : Icons.bluetooth),
                    label: Text(_scanning ? "Scanning..." : "BT Scan"),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _startSimulate,
                    icon: const Icon(Icons.phone_android),
                    label: const Text("Simulate"),
                  ),
                ],
              )
            else if (_simulating)
              OutlinedButton(
                onPressed: _stopSimulate,
                child: const Text("Stop Simulate"),
              )
            else
              OutlinedButton(
                onPressed: () async {
                  await _ble.disconnect();
                  setState(() => _status = "Disconnected");
                },
                child: const Text("Disconnect"),
              ),
          ],
        ),
      ),
    );
  }
}

class _DataCard extends StatelessWidget {
  final GpsData? data;

  const _DataCard({this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: data != null ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  data != null ? "LIVE" : "Waiting...",
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const Divider(height: 24),
            _Row("Latitude", data?.lat.toStringAsFixed(6) ?? "--"),
            _Row("Longitude", data?.lng.toStringAsFixed(6) ?? "--"),
            _Row("Speed", data != null ? "${data!.speed} km/h" : "--"),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[400])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
