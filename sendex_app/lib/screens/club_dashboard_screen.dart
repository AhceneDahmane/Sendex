import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/device_info.dart';
import '../models/player_info.dart';
import '../services/storage_service.dart';
import 'device_detail_screen.dart';

class _DeviceState {
  bool connected;
  bool inSession;
  int batteryLevel;
  DateTime? sessionStart;

  _DeviceState({
    this.connected = true,
    this.inSession = false,
    this.batteryLevel = 80,
    this.sessionStart,
  });
}

class ClubDashboardScreen extends StatefulWidget {
  const ClubDashboardScreen({super.key});

  @override
  State<ClubDashboardScreen> createState() => _ClubDashboardScreenState();
}

class _ClubDashboardScreenState extends State<ClubDashboardScreen> {
  final _storage = StorageService.instance;
  final _rng = Random();
  Timer? _tick;

  List<DeviceInfo> _devices = [];
  Map<String, PlayerInfo> _playerMap = {};
  final Map<String, _DeviceState> _states = {};

  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(const Duration(seconds: 5), (_) => _simulate());
  }

  void _load() {
    final devices = _storage.getDevices();
    final players = <String, PlayerInfo>{};
    for (final p in _storage.getPlayerInfoList()) {
      players[p.name] = p;
    }
    for (final d in devices) {
      _states.putIfAbsent(d.id, () => _DeviceState(
        batteryLevel: 50 + _rng.nextInt(51),
        connected: _rng.nextBool(),
        inSession: false,
      ));
    }
    setState(() {
      _devices = devices;
      _playerMap = players;
    });
  }

  void _simulate() {
    for (final d in _devices) {
      final s = _states[d.id]!;
      if (s.connected && s.batteryLevel > 5) {
        s.batteryLevel -= _rng.nextInt(4);
      }
      if (s.connected && !s.inSession && s.batteryLevel > 10 && _rng.nextDouble() < 0.12) {
        s.inSession = true;
        s.sessionStart = DateTime.now();
      }
      if (s.inSession && _rng.nextDouble() < 0.08) {
        s.inSession = false;
        s.sessionStart = null;
      }
      if (!s.connected && _rng.nextDouble() < 0.1) {
        s.connected = true;
        s.batteryLevel = 30 + _rng.nextInt(71);
        s.inSession = false;
        s.sessionStart = null;
      }
      if (s.connected && s.batteryLevel <= 5 && _rng.nextDouble() < 0.3) {
        s.connected = false;
        s.inSession = false;
        s.sessionStart = null;
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  int get _connectedCount => _states.values.where((s) => s.connected).length;
  int get _sessionCount => _states.values.where((s) => s.inSession).length;

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  Color _batteryColor(int level) {
    if (level > 60) return Colors.green;
    if (level > 20) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_devices.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Live Dashboard")),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sensors_off, size: 64, color: cs.onSurface.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text("No devices yet", style: TextStyle(fontSize: 18, color: cs.onSurface.withOpacity(0.6))),
              const SizedBox(height: 8),
              Text("Add devices in the Devices tab", style: TextStyle(color: cs.onSurface.withOpacity(0.4))),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Dashboard"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusDot(Colors.green),
                const SizedBox(width: 4),
                Text("$_sessionCount", style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                _StatusDot(Colors.orange),
                const SizedBox(width: 4),
                Text("$_connectedCount", style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async { _load(); },
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: _devices.length,
          itemBuilder: (_, i) => _buildCard(_devices[i]),
        ),
      ),
    );
  }

  Widget _buildCard(DeviceInfo device) {
    final cs = Theme.of(context).colorScheme;
    final state = _states[device.id]!;
    final player = _playerMap[device.ownerName];

    final statusColor = state.inSession
        ? Colors.green
        : state.connected
            ? Colors.orange
            : Colors.grey;

    final statusLabel = state.inSession
        ? "In Session"
        : state.connected
            ? "Connected"
            : "Offline";

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DeviceDetailScreen(device: device)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Color(device.colorValue).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(Icons.sensors, color: Color(device.colorValue), size: 24),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          device.ownerName.isNotEmpty ? device.ownerName : device.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        if (player?.sport != null) ...[
                          const SizedBox(width: 8),
                          Text(player!.sport!, style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.5))),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      device.name,
                      style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.6)),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        state.batteryLevel > 60
                            ? Icons.battery_full
                            : state.batteryLevel > 20
                                ? Icons.battery_5_bar
                                : Icons.battery_2_bar,
                        size: 18,
                        color: _batteryColor(state.batteryLevel),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "${state.batteryLevel}%",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: _batteryColor(state.batteryLevel),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (state.inSession) ...[
                          Icon(Icons.fiber_manual_record, size: 10, color: Colors.red),
                          const SizedBox(width: 4),
                          Text(
                            _formatDuration(DateTime.now().difference(state.sessionStart ?? DateTime.now())),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                          ),
                        ] else ...[
                          Text(statusLabel, style: TextStyle(fontSize: 11, color: statusColor)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;
  const _StatusDot(this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
