import 'package:flutter/material.dart';
import '../models/device_info.dart';
import '../models/session_data.dart';
import '../services/storage_service.dart';
import '../widgets/device_edit_dialog.dart';
import 'session_screen.dart';
import 'session_review_screen.dart';

class DeviceDetailScreen extends StatefulWidget {
  final DeviceInfo device;
  const DeviceDetailScreen({super.key, required this.device});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  final _storage = StorageService.instance;
  late DeviceInfo _device;
  List<SessionData> _sessions = [];

  @override
  void initState() {
    super.initState();
    _device = widget.device;
    _sessions = _storage.getSessions(_device.id);
  }

  void _startSession() async {
    final session = await Navigator.push<SessionData>(
      context,
      MaterialPageRoute(builder: (_) => SessionScreen(device: _device)),
    );
    if (session != null) {
      await _storage.saveSession(_device.id, session);
      setState(() => _sessions = _storage.getSessions(_device.id));
    }
  }

  Future<void> _editDevice() async {
    final result = await showDialog<(String, String, int)>(
      context: context,
      builder: (_) => DeviceEditDialog(device: _device),
    );
    if (result == null) return;
    final updated = _device.copyWith(
      name: result.$1,
      address: result.$2,
      colorValue: result.$3,
    );
    _storage.saveDevice(updated);
    setState(() => _device = updated);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final battColor = _device.batteryLevel > 60
        ? Colors.green
        : _device.batteryLevel > 20
            ? Colors.orange
            : Colors.red;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Color(_device.colorValue),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(_device.name),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: _editDevice),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // ── Device info card ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(_device.colorValue).withAlpha(200),
                              Color(_device.colorValue),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Color(_device.colorValue).withAlpha(60),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.sensors, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_device.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(_device.address,
                                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Icon(Icons.bluetooth_connected, size: 20, color: cs.primary),
                          const SizedBox(height: 4),
                          Text("Paired",
                              style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 28),

                  // Stats grid
                  Row(
                    children: [
                      _StatBox(
                        icon: Icons.battery_std,
                        iconColor: battColor,
                        label: "Battery",
                        value: "${_device.batteryLevel}%",
                      ),
                      const SizedBox(width: 12),
                      _StatBox(
                        icon: Icons.history,
                        iconColor: cs.primary,
                        label: "Sessions",
                        value: "${_sessions.length}",
                      ),
                      if (_storage.role == 'club') ...[
                        const SizedBox(width: 12),
                        _StatBox(
                          icon: Icons.person,
                          iconColor: Colors.amber,
                          label: "Owner",
                          value: _device.ownerName.isNotEmpty ? _device.ownerName : "—",
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Start session button ──
          SizedBox(
            width: double.infinity,
            height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(colors: [cs.primary, cs.tertiary]),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withAlpha(80),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FilledButton.icon(
                onPressed: _startSession,
                icon: const Icon(Icons.play_arrow),
                label: const Text("Start Session",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ── Session history header ──
          Row(
            children: [
              Text("Session History",
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              if (_sessions.isNotEmpty)
                Text("${_sessions.length} total",
                    style: TextStyle(fontSize: 13, color: Colors.grey[500])),
            ],
          ),
          const SizedBox(height: 12),

          if (_sessions.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.directions_run, size: 48, color: Colors.grey[700]),
                      const SizedBox(height: 12),
                      Text("No sessions yet",
                          style: TextStyle(color: Colors.grey[500], fontSize: 15)),
                      const SizedBox(height: 4),
                      Text("Tap start to begin tracking",
                          style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                    ],
                  ),
                ),
              ),
            )
          else
            ..._sessions.map(
              (s) => _SessionCard(
                session: s,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => SessionReviewScreen(session: s)),
                  ).then((_) => setState(() {}));
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatBox({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final SessionData session;
  final VoidCallback? onTap;

  const _SessionCard({required this.session, this.onTap});

  String _fmtDur(Duration d) {
    final h = d.inHours, m = d.inMinutes.remainder(60), s = d.inSeconds.remainder(60);
    return h > 0 ? "${h}h ${m}m" : "${m}m ${s}s";
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final date =
        "${session.startTime.day.toString().padLeft(2, '0')}/${session.startTime.month.toString().padLeft(2, '0')}/${session.startTime.year}";
    final time =
        "${session.startTime.hour.toString().padLeft(2, '0')}:${session.startTime.minute.toString().padLeft(2, '0')}";

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.directions_run, color: cs.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("$date · $time",
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      "${_fmtDur(session.duration)}  ·  ${session.totalDistance.toStringAsFixed(0)}m",
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Icon(Icons.flash_on, size: 14, color: Colors.amber[300]),
                      const SizedBox(width: 2),
                      Text("${session.sprintCount}",
                          style: TextStyle(
                              color: Colors.amber[300],
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text("${session.maxSpeed.toStringAsFixed(1)} km/h",
                      style: TextStyle(
                          color: Colors.orange[300],
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 18, color: Colors.grey[600]),
            ],
          ),
        ),
      ),
    );
  }
}
