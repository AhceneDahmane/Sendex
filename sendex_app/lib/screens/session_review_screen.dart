import 'package:flutter/material.dart';
import '../models/session_data.dart';
import '../models/player_info.dart';
import '../services/export_service.dart';
import '../services/storage_service.dart';
import '../widgets/pitch_heatmap.dart';
import '../widgets/speed_chart.dart';
import '../widgets/metric_ring.dart';
import '../widgets/zone_bar_chart.dart';

class SessionReviewScreen extends StatelessWidget {
  final SessionData session;

  const SessionReviewScreen({super.key, required this.session});

  String _getSport() {
    final info = StorageService.instance.getPlayerInfo(session.playerName);
    return info?.sport ?? 'Football';
  }

  double _getFieldLength() {
    final info = StorageService.instance.getPlayerInfo(session.playerName);
    return info?.fieldLength ?? 105;
  }

  double _getFieldWidth() {
    final info = StorageService.instance.getPlayerInfo(session.playerName);
    return info?.fieldWidth ?? 68;
  }

  @override
  Widget build(BuildContext context) {
    final dur = session.duration;
    final durStr = dur.inHours > 0
        ? "${dur.inHours}h ${dur.inMinutes.remainder(60)}m ${dur.inSeconds.remainder(60)}s"
        : "${dur.inMinutes}m ${dur.inSeconds.remainder(60)}s";

    final speedZones = [
      ZoneData(label: "0-7 km/h", value: session.timeInZone0to7.inSeconds.toDouble(), gradient: const LinearGradient(colors: [Colors.blue, Colors.lightBlue])),
      ZoneData(label: "7-12 km/h", value: session.timeInZone7to12.inSeconds.toDouble(), gradient: const LinearGradient(colors: [Colors.green, Colors.lightGreen])),
      ZoneData(label: "12-18 km/h", value: session.timeInZone12to18.inSeconds.toDouble(), gradient: const LinearGradient(colors: [Colors.orange, Colors.deepOrange])),
      ZoneData(label: "18+ km/h", value: session.timeInZone18plus.inSeconds.toDouble(), gradient: const LinearGradient(colors: [Colors.red, Colors.deepOrange])),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text("Session ${session.startTime.day}/${session.startTime.month}"),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.download),
            onSelected: (v) async {
              if (v == 'csv') {
                await ExportService.exportCsv(session);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("CSV copied to clipboard")),
                  );
                }
              } else if (v == 'pdf') {
                await ExportService.exportPdf(session);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'csv', child: ListTile(leading: Icon(Icons.table_chart), title: Text("Export CSV"), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'pdf', child: ListTile(leading: Icon(Icons.picture_as_pdf), title: Text("Export PDF"), contentPadding: EdgeInsets.zero)),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Metric rings row
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  MetricRing(value: session.maxSpeed, maxValue: 35, label: "Max Speed", unit: "km/h", icon: Icons.trending_up, color: Colors.orange),
                  MetricRing(value: session.avgSpeed, maxValue: 20, label: "Avg Speed", unit: "km/h", icon: Icons.speed, color: Colors.cyan),
                  MetricRing(value: session.sprintCount.toDouble(), maxValue: 50, label: "Sprints", unit: "count", icon: Icons.flash_on, color: Colors.amber),
                  MetricRing(value: session.avgHeartRate, maxValue: 200, label: "Avg HR", unit: "bpm", icon: Icons.favorite, color: Colors.red),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Key stats in a grid
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Overview", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[300])),
                  const SizedBox(height: 16),
                  Row(children: [
                    _StatBox(icon: Icons.timer, label: "Duration", value: durStr),
                    _StatBox(icon: Icons.map, label: "Distance", value: "${session.totalDistance.toStringAsFixed(0)} m"),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    _StatBox(icon: Icons.favorite, label: "Max HR", value: "${session.maxHeartRate.toStringAsFixed(0)} bpm"),
                    _StatBox(icon: Icons.analytics, label: "Intensity", value: "${session.intensityIndex.toStringAsFixed(0)}%"),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Speed & Acceleration
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Speed & Acceleration", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[300])),
                  const SizedBox(height: 16),
                  Row(children: [
                    _StatBox(icon: Icons.speed, label: "Avg Sprint", value: "${session.avgSprintSpeed.toStringAsFixed(1)} km/h"),
                    _StatBox(icon: Icons.trending_up, label: "Max Sprint", value: "${session.maxSprintSpeed.toStringAsFixed(1)} km/h"),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    _StatBox(icon: Icons.arrow_upward, label: "Accelerations", value: "${session.accelerations}"),
                    _StatBox(icon: Icons.arrow_downward, label: "Decelerations", value: "${session.decelerations}"),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Speed zone distribution bar chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ZoneBarChart(zones: speedZones),
            ),
          ),
          const SizedBox(height: 12),

          // Sprint distance and workload
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Performance", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[300])),
                  const SizedBox(height: 16),
                  Row(children: [
                    _StatBox(icon: Icons.flash_on, label: "Sprint Distance", value: "${session.totalSprintDistance.toStringAsFixed(0)} m"),
                    _StatBox(icon: Icons.fitness_center, label: "Workload", value: "${session.workload.toStringAsFixed(0)}"),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    _StatBox(icon: Icons.speed, label: "Avg Acceleration", value: "${session.avgAcceleration.toStringAsFixed(1)} m/s²"),
                    _StatBox(icon: Icons.trending_down, label: "Min Speed", value: "${session.minSpeed.toStringAsFixed(1)} km/h"),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Heatmap
          Text("Position Heatmap", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 280,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: PitchHeatmap(points: session.points, sport: _getSport(), fieldLength: _getFieldLength(), fieldWidth: _getFieldWidth()),
            ),
          ),
          const SizedBox(height: 16),

          // Speed chart
          Text("Speed Over Time", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SpeedChart(points: session.points),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatBox({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey[400]),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
