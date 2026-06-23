import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/device_info.dart';
import '../services/storage_service.dart';
import '../services/ble_service.dart';
import '../widgets/device_edit_dialog.dart';
import 'device_detail_screen.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final _storage = StorageService.instance;
  final _ble = BleService();
  List<DeviceInfo> _devices = [];
  List<ScanResult> _scanResults = [];
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _devices = _storage.getDevices();
    _ble.scanStream.listen((results) {
      if (!mounted) return;
      setState(() => _scanResults = results);
    });
  }

  Future<void> _scan() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    setState(() => _scanning = true);
    _ble.startScan();
    Future.delayed(const Duration(seconds: 15), () {
      _ble.stopScan();
      if (mounted) setState(() => _scanning = false);
    });
  }

  void _addDevice(ScanResult result) {
    final device = DeviceInfo(
      id: result.device.remoteId.toString(),
      name: result.device.platformName.isNotEmpty ? result.device.platformName : "Unknown",
      address: result.device.remoteId.toString(),
      ownerName: _storage.playerName ?? '',
    );
    _storage.saveDevice(device);
    setState(() {
      _devices = _storage.getDevices();
      _scanResults = [];
    });
  }

  void _navigateToDevice(DeviceInfo device) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DeviceDetailScreen(device: device)),
    );
  }

  void _addSimulatedDevice() async {
    final result = await showDialog<(String, String, int)>(
      context: context,
      builder: (_) => const DeviceEditDialog(),
    );
    if (result == null) return;
    final device = DeviceInfo(
      id: "sim-${DateTime.now().millisecondsSinceEpoch}",
      name: result.$1,
      address: result.$2,
      ownerName: _storage.playerName ?? '',
      colorValue: result.$3,
      batteryLevel: 85,
    );
    _storage.saveDevice(device);
    setState(() => _devices = _storage.getDevices());
  }

  void _logout() {
    _storage.isLoggedIn = false;
    _storage.playerName = null;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  void dispose() {
    _ble.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerName = _storage.playerName ?? "";
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Devices"),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text("Welcome, $playerName",
                style: Theme.of(context).textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _scanning ? null : _scan,
                    icon: Icon(_scanning ? Icons.bluetooth_searching : Icons.bluetooth),
                    label: Text(_scanning ? "Scanning..." : "Scan for Vest"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addSimulatedDevice,
                    icon: const Icon(Icons.phone_android),
                    label: const Text("Simulate"),
                  ),
                ),
              ],
            ),
          ),
          if (_scanResults.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text("Nearby devices", style: Theme.of(context).textTheme.labelLarge),
            ),
            SizedBox(
              height: 160,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _scanResults.length,
                itemBuilder: (_, i) {
                  final r = _scanResults[i];
                  final alreadyAdded = _devices.any((d) => d.id == r.device.remoteId.toString());
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.device.platformName.isNotEmpty ? r.device.platformName : "Unknown",
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(r.device.remoteId.toString(), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                          const Spacer(),
                          Text("${r.rssi} dBm", style: TextStyle(color: Colors.grey[400])),
                          const SizedBox(height: 8),
                          if (alreadyAdded)
                            const Text("Added", style: TextStyle(color: Colors.green))
                          else
                            FilledButton.tonalIcon(
                              onPressed: () => _addDevice(r),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text("Add", style: TextStyle(fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text("Saved vests", style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(
            child: _devices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey[700]),
                        const SizedBox(height: 12),
                        Text("No vests added yet", style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _devices.length,
                    itemBuilder: (_, i) {
                      final d = _devices[i];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Color(d.colorValue),
                            child: const Icon(Icons.sensors, color: Colors.white),
                          ),
                          title: Text(d.name),
                          subtitle: Text(d.address, style: const TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _navigateToDevice(d),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
