import 'package:flutter/material.dart';
import '../models/device_info.dart';
import '../models/gps_point.dart';
import '../models/player_info.dart';
import '../models/session_data.dart';
import '../services/storage_service.dart';
import '../widgets/pitch_heatmap.dart';
import 'device_detail_screen.dart';
import 'session_review_screen.dart';

class PlayerProfileScreen extends StatefulWidget {
  final String playerName;
  const PlayerProfileScreen({super.key, required this.playerName});

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  final _storage = StorageService.instance;
  late PlayerInfo _player;
  List<SessionData> _sessions = [];
  List<DeviceInfo> _devices = [];

  @override
  void initState() {
    super.initState();
    _load();
    StorageService.sessionNotifier.addListener(_load);
    StorageService.deviceNotifier.addListener(_load);
  }

  @override
  void dispose() {
    StorageService.sessionNotifier.removeListener(_load);
    StorageService.deviceNotifier.removeListener(_load);
    super.dispose();
  }

  void _load() {
    final p = _storage.getPlayerInfo(widget.playerName);
    final devices = _storage.getDevicesForPlayer(widget.playerName);
    final sessions = devices.expand((d) =>
      _storage.getSessions(d.id).where((s) => s.playerName == widget.playerName)
    ).toList()..sort((a, b) => b.startTime.compareTo(a.startTime));

    if (mounted) setState(() {
      _player = p ?? PlayerInfo(name: widget.playerName);
      _devices = devices;
      _sessions = sessions;
    });
  }

  // ── Aggregated stats ──────────────────────────────────────

  int get _totalSessions => _sessions.length;
  Duration get _totalDuration {
    Duration d = Duration.zero;
    for (final s in _sessions) d += s.duration;
    return d;
  }

  double get _totalDistance => _sessions.fold(0.0, (sum, s) => sum + s.totalDistance);
  int get _totalSprints => _sessions.fold(0, (sum, s) => sum + s.sprintCount);
  double get _totalSprintDistance => _sessions.fold(0.0, (sum, s) => sum + s.totalSprintDistance);
  double get _avgHeartRate => _sessions.isEmpty ? 0 : _sessions.fold(0.0, (sum, s) => sum + s.avgHeartRate) / _sessions.length;
  int get _totalAccels => _sessions.fold(0, (sum, s) => sum + s.accelerations);
  int get _totalDecels => _sessions.fold(0, (sum, s) => sum + s.decelerations);

  // ── Personal records ──────────────────────────────────────

  double get _recordMaxSpeed => _sessions.isEmpty ? 0 : _sessions.map((s) => s.maxSpeed).reduce((a, b) => a > b ? a : b);
  double get _recordMaxHr => _sessions.isEmpty ? 0 : _sessions.map((s) => s.maxHeartRate).reduce((a, b) => a > b ? a : b);
  int get _recordSprints => _sessions.isEmpty ? 0 : _sessions.map((s) => s.sprintCount).reduce((a, b) => a > b ? a : b);
  double get _recordDistance => _sessions.isEmpty ? 0 : _sessions.map((s) => s.totalDistance).reduce((a, b) => a > b ? a : b);
  double get _recordIntensity => _sessions.isEmpty ? 0 : _sessions.map((s) => s.intensityIndex).reduce((a, b) => a > b ? a : b);

  List<GpsPoint> get _allPoints => _sessions.expand((s) => s.points).toList();

  String _fmtDur(Duration d) {
    final h = d.inHours, m = d.inMinutes.remainder(60);
    return h > 0 ? "${h}h ${m}m" : "${m}m";
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allPoints = _allPoints;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playerName),
        actions: [
          if (_sessions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: "Export all sessions",
              onPressed: () {},
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // ── Player info header ────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: cs.primary.withOpacity(0.15),
                    child: Text(widget.playerName[0].toUpperCase(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: cs.primary)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.playerName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Builder(builder: (_) {
                          final infoStr = [_player.sport, _player.position, _player.club]
                              .where((x) => x != null && x!.isNotEmpty)
                              .join(" · ");
                          return Text(
                            infoStr.isNotEmpty ? infoStr : "No info",
                            style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.6)),
                          );
                        }),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: cs.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                    child: Text("$_totalSessions sessions", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: cs.primary)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Aggregate stat cards ──────────────────────────
          _sectionTitle(cs, "Lifetime Stats"),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _statCard(cs, Icons.timer, "Total Time", _fmtDur(_totalDuration), cs.primary)),
              const SizedBox(width: 8),
              Expanded(child: _statCard(cs, Icons.map, "Distance", _fmtDist(_totalDistance), Colors.green)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _statCard(cs, Icons.flash_on, "Sprints", "$_totalSprints", Colors.orange)),
              const SizedBox(width: 8),
              Expanded(child: _statCard(cs, Icons.speed, "Avg HR", "${_avgHeartRate.toStringAsFixed(0)} bpm", Colors.red)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _statCard(cs, Icons.arrow_upward, "Accels", "$_totalAccels", cs.primary)),
              const SizedBox(width: 8),
              Expanded(child: _statCard(cs, Icons.arrow_downward, "Decels", "$_totalDecels", Colors.orange)),
            ],
          ),
          const SizedBox(height: 16),

          // ── Personal records ──────────────────────────────
          _sectionTitle(cs, "Personal Records"),
          const SizedBox(height: 8),
          SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _recordCard(cs, Icons.trending_up, "Max Speed", "${_recordMaxSpeed.toStringAsFixed(1)} km/h", "🥇"),
                _recordCard(cs, Icons.favorite, "Max HR", "${_recordMaxHr.toStringAsFixed(0)} bpm", "❤️"),
                _recordCard(cs, Icons.flash_on, "Most Sprints", "${_recordSprints}", "⚡"),
                _recordCard(cs, Icons.map, "Longest Run", _fmtDist(_recordDistance), "📏"),
                _recordCard(cs, Icons.analytics, "Best Intensity", "${_recordIntensity.toStringAsFixed(1)}%", "🎯"),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Heatmap ───────────────────────────────────────
          if (allPoints.isNotEmpty) ...[
            _sectionTitle(cs, "Movement Heatmap"),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: PitchHeatmap(
                  points: allPoints,
                  sport: _player.sport ?? 'Football',
                  fieldLength: _player.fieldLength ?? 105,
                  fieldWidth: _player.fieldWidth ?? 68,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Devices ───────────────────────────────────────
          _sectionTitle(cs, "Devices (${_devices.length})"),
          const SizedBox(height: 8),
          if (_devices.isEmpty)
            Card(child: Padding(padding: const EdgeInsets.all(24), child: Center(child: Text("No devices", style: TextStyle(color: cs.onSurface.withOpacity(0.5))))))
          else
            ..._devices.map((d) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: Color(d.colorValue).withOpacity(0.2), child: Icon(Icons.sensors, color: Color(d.colorValue), size: 20)),
                title: Text(d.name),
                subtitle: Text(d.address, style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.5))),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DeviceDetailScreen(device: d))),
              ),
            )),
          const SizedBox(height: 16),

          // ── Recent sessions ───────────────────────────────
          _sectionTitle(cs, "Recent Sessions (${_sessions.length})"),
          const SizedBox(height: 8),
          if (_sessions.isEmpty)
            Card(child: Padding(padding: const EdgeInsets.all(24), child: Center(child: Text("No sessions yet", style: TextStyle(color: cs.onSurface.withOpacity(0.5))))))
          else
            ..._sessions.take(10).map((s) => _sessionCard(cs, s)),
        ],
      ),
    );
  }

  Widget _sectionTitle(ColorScheme cs, String title) {
    return Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cs.onSurface));
  }

  Widget _statCard(ColorScheme cs, IconData icon, String label, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
                Text(label, style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.5))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordCard(ColorScheme cs, IconData icon, String label, String value, String emoji) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 6),
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: cs.primary)),
              Text(label, style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.5))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sessionCard(ColorScheme cs, SessionData s) {
    final date = "${s.startTime.day.toString().padLeft(2, '0')}/${s.startTime.month.toString().padLeft(2, '0')}/${s.startTime.year}";
    final time = "${s.startTime.hour.toString().padLeft(2, '0')}:${s.startTime.minute.toString().padLeft(2, '0')}";
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionReviewScreen(session: s))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: cs.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.directions_run, color: cs.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("$date · $time", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _chip(cs, Icons.timer, _fmtDur(s.duration)),
                        const SizedBox(width: 8),
                        _chip(cs, Icons.flash_on, "${s.sprintCount}"),
                        const SizedBox(width: 8),
                        _chip(cs, Icons.trending_up, "${s.maxSpeed.toStringAsFixed(1)} km/h"),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(ColorScheme cs, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: cs.onSurface.withOpacity(0.5)),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.7))),
      ],
    );
  }

  String _fmtDist(double d) {
    return d >= 1000 ? "${(d / 1000).toStringAsFixed(2)} km" : "${d.toStringAsFixed(0)} m";
  }
}
