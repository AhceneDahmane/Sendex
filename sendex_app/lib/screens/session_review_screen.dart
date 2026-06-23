import 'package:flutter/material.dart';
import '../models/session_data.dart';
import '../services/export_service.dart';
import '../widgets/pitch_heatmap.dart';
import '../widgets/speed_chart.dart';

class SessionReviewScreen extends StatelessWidget {
  final SessionData session;

  const SessionReviewScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final dur = session.duration;
    final durStr = dur.inHours > 0
        ? "${dur.inHours}h ${dur.inMinutes.remainder(60)}m ${dur.inSeconds.remainder(60)}s"
        : "${dur.inMinutes}m ${dur.inSeconds.remainder(60)}s";

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
          // Stats grid
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _Metric(label: "Duration", value: durStr, icon: Icons.timer),
                      _Metric(label: "Max Speed", value: "${session.maxSpeed.toStringAsFixed(1)} km/h", icon: Icons.trending_up),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _Metric(label: "Avg Speed", value: "${session.avgSpeed.toStringAsFixed(1)} km/h", icon: Icons.speed),
                      _Metric(label: "Sprints", value: "${session.sprintCount}", icon: Icons.flash_on),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _Metric(label: "Data Points", value: "${session.points.length}", icon: Icons.gps_fixed),
                      _Metric(label: "Player", value: session.playerName, icon: Icons.person),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Pitch heatmap
          Text("Position Heatmap", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 280,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: PitchHeatmap(points: session.points),
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

          // Data table header
          Text("GPS Data Log", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),

          if (session.points.isEmpty)
            Card(child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text("No data points", style: TextStyle(color: Colors.grey[500]))),
            ))
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: session.points.length,
                    itemBuilder: (_, i) {
                      final p = session.points[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(width: 40, child: Text("${i + 1}", style: TextStyle(color: Colors.grey[500], fontSize: 12))),
                            Expanded(flex: 2, child: Text(p.lat.toStringAsFixed(5), style: const TextStyle(fontSize: 12))),
                            Expanded(flex: 2, child: Text(p.lng.toStringAsFixed(5), style: const TextStyle(fontSize: 12))),
                            Expanded(child: Text("${p.speed} km/h", style: const TextStyle(fontSize: 12))),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
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
