import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/device_info.dart';
import '../services/storage_service.dart';
import '../services/ble_service.dart';
import '../widgets/device_edit_dialog.dart';
import 'device_detail_screen.dart';

const _sendexFilter = "SENDEX-VEST";

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

  int get _maxDevices => _storage.role == 'club' ? 11 : 1;
  bool get _canAdd => _devices.length < _maxDevices;

  bool _isSendexDevice(ScanResult r) =>
      r.device.platformName.toUpperCase().contains(_sendexFilter);

  @override
  void initState() {
    super.initState();
    _devices = _storage.getDevices();
    _ble.scanStream.listen((results) {
      if (!mounted) return;
      setState(() {
        _scanResults = results.where(_isSendexDevice).toList();
      });
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
    if (!_canAdd) {
      _showLimitMessage();
      return;
    }
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

  void _showLimitMessage() {
    final role = _storage.role == 'club' ? "club" : "player";
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          role == "club"
              ? "Club limit reached (max $_maxDevices vests)"
              : "Player limit reached (max $_maxDevices vest). Use a club account for more.",
        ),
      ),
    );
  }

  void _navigateToDevice(DeviceInfo device) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DeviceDetailScreen(device: device)),
    );
  }

  void _removeDevice(DeviceInfo device) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove Vest"),
        content: Text("Remove ${device.name} and all its sessions?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              _storage.removeDevice(device.id);
              setState(() => _devices = _storage.getDevices());
              Navigator.pop(ctx);
            },
            child: Text("Remove",
                style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  void _addSimulatedDevice() async {
    if (!_canAdd) {
      _showLimitMessage();
      return;
    }
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

  Widget _rssiBars(int rssi) {
    final bars = rssi > -50 ? 4 : rssi > -65 ? 3 : rssi > -80 ? 2 : 1;
    return Row(
      children: List.generate(4, (i) {
        final on = i < bars;
        return Container(
          width: 4,
          height: 6 + i * 4,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: on ? Colors.green[400] : Colors.grey[700],
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }

  bool _isSimulated(DeviceInfo d) => d.id.startsWith('sim-');

  void _logout() {
    _storage.logout();
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
          // Subscription banner
          if (_storage.getSubscription().isActive && !_storage.getSubscription().isExpired)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              color: _storage.getSubscription().isTrial ? Colors.blue[900] : Colors.green[900],
              child: Row(
                children: [
                  Icon(Icons.card_giftcard, size: 16, color: _storage.getSubscription().isTrial ? Colors.blue[200] : Colors.green[200]),
                  const SizedBox(width: 8),
                  Text(
                    _storage.getSubscription().isTrial
                        ? "Trial · ${_storage.getSubscription().daysRemaining} days left"
                        : "Subscribed",
                    style: TextStyle(fontSize: 13, color: Colors.white),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/subscription'),
                    child: const Text("Manage", style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                Text("Welcome, $playerName",
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _canAdd ? Colors.green.withAlpha(30) : Colors.orange.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${_devices.length}/$_maxDevices",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _canAdd ? Colors.green[300] : Colors.orange[300],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (_canAdd && !_scanning) ? _scan : null,
                    icon: Icon(_scanning ? Icons.bluetooth_searching : Icons.bluetooth),
                    label: Text(_scanning ? "Scanning..." : "Scan for Vest"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _canAdd ? _addSimulatedDevice : null,
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
                          Row(
                            children: [
                              Expanded(
                                child: Text(r.device.platformName.isNotEmpty ? r.device.platformName : "Sendex-Vest",
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              ),
                              Icon(Icons.bluetooth, size: 14, color: Colors.blue[300]),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(r.device.remoteId.toString(), style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                          const Spacer(),
                          Row(
                            children: [
                              _rssiBars(r.rssi),
                              const SizedBox(width: 6),
                              Text("${r.rssi} dBm", style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (alreadyAdded)
                            const Text("Added", style: TextStyle(color: Colors.green, fontSize: 12))
                          else if (!_canAdd)
                            Text("Limit reached", style: TextStyle(fontSize: 12, color: Colors.grey[500]))
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
                            child: Icon(
                              _isSimulated(d) ? Icons.phone_android : Icons.bluetooth,
                              color: Colors.white, size: 20,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(child: Text(d.name)),
                              if (_isSimulated(d))
                                Text("SIM", style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                            ],
                          ),
                          subtitle: Text(d.address, style: const TextStyle(fontSize: 12)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[300]),
                                onPressed: () => _removeDevice(d),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
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
