import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/device_info.dart';
import '../models/gps_point.dart';
import '../models/session_data.dart';
import '../services/storage_service.dart';
import '../services/ble_service.dart';
import '../widgets/pitch_heatmap.dart';
import '../widgets/speed_chart.dart';

class SessionScreen extends StatefulWidget {
  final DeviceInfo device;
  final BleService? bleService;

  const SessionScreen({super.key, required this.device, this.bleService});

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
  double _prevSpeed = 0;
  StreamSubscription<FirmwarePoint>? _bleSub;

  double _baseLat = 48.8566;
  double _baseLng = 2.3522;

  bool get _useBle => widget.bleService != null && widget.bleService!.isConnected;

  String get _sport => _storage.getPlayerInfo(_storage.playerName ?? '')?.sport ?? 'Football';
  double get _fieldLength => _storage.getPlayerInfo(_storage.playerName ?? '')?.fieldLength ?? 105;
  double get _fieldWidth => _storage.getPlayerInfo(_storage.playerName ?? '')?.fieldWidth ?? 68;

  @override
  void initState() {
    super.initState();
    if (_useBle && widget.bleService!.sessionActive.value) {
      _startSession();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bleSub?.cancel();
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
    _prevSpeed = 0;

    if (_useBle) {
      // Prepend any buffered data from before (phone was off, etc.)
      final buffered = widget.bleService!.takePendingData();
      _points = buffered.map((fp) => GpsPoint(
        lat: fp.lat,
        lng: fp.lng,
        speed: fp.speed,
        heartRate: fp.heartRate,
        acceleration: fp.accel,
      )).toList();
      if (_points.isNotEmpty) {
        _currentSpeed = _points.last.speed;
        _prevSpeed = _currentSpeed;
      }

      widget.bleService!.writeCommand("START");
      _bleSub?.cancel();
      _bleSub = widget.bleService!.dataStream.listen(_onBlePoint);
    } else {
      _points = [];
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _simulatePoint());
    }
  }

  void _stopSession() {
    _active = false;
    _timer?.cancel();
    _bleSub?.cancel();
    _bleSub = null;

    if (_useBle) {
      widget.bleService!.writeCommand("STOP");
    }

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

  void _onBlePoint(FirmwarePoint fp) {
    if (!_active) return;
    final speed = fp.speed;
    _currentSpeed = speed;
    final accel = _prevSpeed == 0 ? 0.0 : speed - _prevSpeed;
    _prevSpeed = speed;

    final point = GpsPoint(
      lat: fp.lat,
      lng: fp.lng,
      speed: speed,
      heartRate: fp.heartRate,
      acceleration: fp.accel,
    );

    _baseLat = fp.lat;
    _baseLng = fp.lng;

    setState(() => _points.add(point));
  }

  void _simulatePoint() {
    final raw = _rng.nextDouble() * 28;
    final speed = double.parse(raw.toStringAsFixed(1));
    _currentSpeed = speed;
    final accel = _prevSpeed == 0 ? 0.0 : double.parse((speed - _prevSpeed).toStringAsFixed(1));
    _prevSpeed = speed;

    _baseLat += (_rng.nextDouble() - 0.5) / 5000;
    _baseLng += (_rng.nextDouble() - 0.5) / 5000;

    final point = GpsPoint(
      lat: _baseLat,
      lng: _baseLng,
      speed: speed,
      heartRate: (80 + _rng.nextInt(60)).toDouble(),
      acceleration: accel,
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
    final accelerations = _points.where((p) => p.acceleration > 3).length;
    final decelerations = _points.where((p) => p.acceleration < -3).length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(widget.device.name),
            if (_useBle)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.bluetooth_connected, size: 16, color: Colors.blue[300]),
              ),
          ],
        ),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(label: "Time", value: dup, icon: Icons.timer),
                _StatItem(label: "Speed", value: "${_currentSpeed.toStringAsFixed(1)} km/h", icon: Icons.speed),
                _StatItem(label: "Sprints", value: "$sprints", icon: Icons.flash_on),
                _StatItem(label: "Max", value: "${maxSpeed.toStringAsFixed(1)}", icon: Icons.trending_up),
                _StatItem(label: "Accel", value: "$accelerations", icon: Icons.arrow_upward),
                _StatItem(label: "Decel", value: "$decelerations", icon: Icons.arrow_downward),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: PitchHeatmap(points: _points, sport: _sport, fieldLength: _fieldLength, fieldWidth: _fieldWidth),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SpeedChart(points: _points.length > 60 ? _points.sublist(_points.length - 60) : _points),
              ),
            ),
          ),
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
        Icon(icon, size: 16, color: Colors.grey[400]),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      ],
    );
  }
}
