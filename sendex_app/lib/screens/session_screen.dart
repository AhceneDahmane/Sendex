import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/device_info.dart';
import '../models/gps_point.dart';
import '../models/session_data.dart';
import '../services/storage_service.dart';
import '../widgets/pitch_heatmap.dart';
import '../widgets/speed_chart.dart';

class SessionScreen extends StatefulWidget {
  final DeviceInfo device;
  const SessionScreen({super.key, required this.device});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  final _rng = Random();
  final _storage = StorageService.instance;

  bool _active = false;
  DateTime? _startTime;
  Timer? _timer;
  List<GpsPoint> _points = [];
  double _currentSpeed = 0;

  // Base position (centered on a football pitch)
  double _baseLat = 48.8566;
  double _baseLng = 2.3522;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleSession() {
    if (_active) {
      _stopSession();
    } else {
      _startSession();
    }
  }

  void _startSession() {
    _active = true;
    _startTime = DateTime.now();
    _points = [];
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _simulatePoint());
  }

  void _stopSession() {
    _active = false;
    _timer?.cancel();
    _timer = null;

    final session = SessionData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      deviceId: widget.device.id,
      playerName: _storage.playerName ?? "",
      startTime: _startTime!,
      endTime: DateTime.now(),
      points: List.from(_points),
    );

    Navigator.pop(context, session);
  }

  void _simulatePoint() {
    final speed = _rng.nextDouble() * 25;
    _currentSpeed = speed;

    // Wander within pitch bounds
    _baseLat += (_rng.nextDouble() - 0.5) / 5000;
    _baseLng += (_rng.nextDouble() - 0.5) / 5000;

    final point = GpsPoint(
      lat: _baseLat,
      lng: _baseLng,
      speed: double.parse(speed.toStringAsFixed(1)),
      heartRate: (80 + _rng.nextInt(60)).toDouble(),
    );

    setState(() => _points.add(point));
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    final dup = _startTime != null
        ? _formatDuration(DateTime.now().difference(_startTime!))
        : "00:00:00";
    final sprints = _points.where((p) => p.speed > 18).length;
    final maxSpeed = _points.isEmpty
        ? 0.0
        : _points.map((p) => p.speed).reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
        actions: [
          if (!_active)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
        ],
      ),
      body: Column(
        children: [
          // Stats bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(label: "Time", value: dup, icon: Icons.timer),
                _StatItem(
                    label: "Speed",
                    value: "${_currentSpeed.toStringAsFixed(1)} km/h",
                    icon: Icons.speed),
                _StatItem(label: "Sprints", value: "$sprints", icon: Icons.flash_on),
                _StatItem(
                    label: "Max",
                    value: "${maxSpeed.toStringAsFixed(1)} km/h",
                    icon: Icons.trending_up),
              ],
            ),
          ),

          // Pitch heatmap
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: PitchHeatmap(points: _points),
              ),
            ),
          ),

          // Speed chart
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SpeedChart(points: _points.length > 50 ? _points.sublist(_points.length - 50) : _points),
              ),
            ),
          ),

          // Controls
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: _toggleSession,
              icon: Icon(_active ? Icons.stop : Icons.play_arrow),
              label: Text(_active ? "Stop Session" : "Start Session"),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                backgroundColor: _active ? Colors.red : Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.grey[400]),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }
}
