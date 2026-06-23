import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/device_info.dart';
import '../models/player_info.dart';
import '../services/storage_service.dart';
import '../services/ble_service.dart';
import '../widgets/device_edit_dialog.dart';
import '../widgets/register_player_dialog.dart';
import 'device_detail_screen.dart';
import 'session_review_screen.dart';

class ClubPlayerScreen extends StatefulWidget {
  final String playerName;
  const ClubPlayerScreen({super.key, required this.playerName});

  @override
  State<ClubPlayerScreen> createState() => _ClubPlayerScreenState();
}

class _ClubPlayerScreenState extends State<ClubPlayerScreen> {
  final _storage = StorageService.instance;
  final _ble = BleService();
  List<DeviceInfo> _devices = [];
  List<ScanResult> _scanResults = [];
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _devices = _storage.getDevicesForPlayer(widget.playerName);
    _ble.scanStream.listen((results) {
      if (!mounted) return;
      setState(() => _scanResults = results);
    });
  }

  String get _playerName => widget.playerName;

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
      ownerName: _playerName,
    );
    _storage.saveDevice(device);
    setState(() {
      _devices = _storage.getDevicesForPlayer(_playerName);
      _scanResults = [];
    });
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
      ownerName: _playerName,
      colorValue: result.$3,
      batteryLevel: 85,
    );
    _storage.saveDevice(device);
    setState(() => _devices = _storage.getDevicesForPlayer(_playerName));
  }

  @override
  void dispose() {
    _ble.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allSessions = _devices.expand((d) =>
      _storage.getSessions(d.id).where((s) => s.playerName == _playerName)
    ).toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    final totalSprints = allSessions.fold(0, (sum, s) => sum + s.sprintCount);
    final maxSpeed = allSessions.isEmpty
        ? 0.0
        : allSessions.map((s) => s.maxSpeed).reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(title: Text(_playerName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats overview
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _Metric(label: "Sessions", value: "${allSessions.length}", icon: Icons.directions_run),
                      _Metric(label: "Sprints", value: "$totalSprints", icon: Icons.flash_on),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _Metric(label: "Max Speed", value: "${maxSpeed.toStringAsFixed(1)} km/h", icon: Icons.trending_up),
                      _Metric(label: "Devices", value: "${_devices.length}", icon: Icons.sensors),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Devices section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Devices", style: Theme.of(context).textTheme.titleMedium),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.bluetooth_searching),
                    onPressed: _scanning ? null : _scan,
                    tooltip: "Scan BLE",
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _addSimulatedDevice,
                    tooltip: "Add simulator",
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Scan results
          if (_scanResults.isNotEmpty)
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _scanResults.length,
                itemBuilder: (_, i) {
                  final r = _scanResults[i];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          Text(r.device.platformName.isNotEmpty ? r.device.platformName : "Unknown",
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text("${r.rssi} dBm", style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                          const SizedBox(height: 4),
                          FilledButton.tonalIcon(
                            onPressed: () => _addDevice(r),
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text("Add", style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          if (_devices.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text("No devices for $_playerName",
                      style: TextStyle(color: Colors.grey[500])),
                ),
              ),
            )
          else
            ..._devices.map((d) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(d.colorValue),
                      child: const Icon(Icons.sensors, color: Colors.white, size: 20),
                    ),
                    title: Text(d.name),
                    subtitle: Text(d.address, style: const TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DeviceDetailScreen(device: d),
                        ),
                      );
                    },
                  ),
                )),

          const SizedBox(height: 20),

          // Recent sessions
          Text("Recent Sessions", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),

          if (allSessions.isEmpty)
            Card(child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text("No sessions yet", style: TextStyle(color: Colors.grey[500]))),
            ))
          else
            ...allSessions.take(10).map((s) {
              final dur = s.duration;
              final durStr = dur.inHours > 0
                  ? "${dur.inHours}h ${dur.inMinutes.remainder(60)}m"
                  : "${dur.inMinutes}m ${dur.inSeconds.remainder(60)}s";
              final date = "${s.startTime.day}/${s.startTime.month}/${s.startTime.year}";
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.directions_run),
                  title: Text(date),
                  subtitle: Text("$durStr  •  ${s.sprintCount} sprints  •  ${s.points.length} pts"),
                  trailing: Text("${s.maxSpeed.toStringAsFixed(1)} km/h",
                      style: TextStyle(color: Colors.orange[300], fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SessionReviewScreen(session: s),
                      ),
                    );
                  },
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _Metric({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 22, color: Colors.grey[400]),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ],
      ),
    );
  }
}
