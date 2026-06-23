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
      MaterialPageRoute(
        builder: (_) => SessionScreen(device: _device),
      ),
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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(color: Color(_device.colorValue), shape: BoxShape.circle),
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
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Color(_device.colorValue),
                        radius: 28,
                        child: const Icon(Icons.sensors, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_device.name, style: Theme.of(context).textTheme.titleMedium),
                          Text(_device.address, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _StatRow("Battery", "${_device.batteryLevel}%"),
                  _StatRow("Status", "Paired"),
                  _StatRow("Sessions", "${_sessions.length}"),
                  _StatRow("Owner", _device.ownerName.isNotEmpty ? _device.ownerName : "—"),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _startSession,
            icon: const Icon(Icons.play_arrow),
            label: const Text("Start Session"),
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
          ),
          const SizedBox(height: 24),
          Text("Session History", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_sessions.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text("No sessions yet", style: TextStyle(color: Colors.grey[500])),
                ),
              ),
            )
          else
            ..._sessions.map((s) => _SessionCard(
              session: s,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SessionReviewScreen(session: s)),
                );
              },
            )),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: TextStyle(color: Colors.grey[400])), Text(value)],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final SessionData session;
  final VoidCallback? onTap;
  const _SessionCard({required this.session, this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = "${session.startTime.day}/${session.startTime.month}/${session.startTime.year}";
    final dur = session.duration;
    final durStr = dur.inHours > 0
        ? "${dur.inHours}h ${dur.inMinutes.remainder(60)}m"
        : "${dur.inMinutes}m ${dur.inSeconds.remainder(60)}s";
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.directions_run),
        title: Text("Session $date"),
        subtitle: Text("$durStr  •  ${session.points.length} points  •  ${session.sprintCount} sprints"),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("${session.maxSpeed.toStringAsFixed(1)} km/h",
                style: TextStyle(color: Colors.orange[300], fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }
}
