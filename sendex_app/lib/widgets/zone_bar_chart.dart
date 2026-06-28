import 'package:flutter/material.dart';

class ZoneData {
  final String label;
  final double value;
  final Gradient gradient;

  ZoneData({required this.label, required this.value, required this.gradient});
}

class ZoneBarChart extends StatelessWidget {
  final List<ZoneData> zones;
  final String title;

  const ZoneBarChart({super.key, required this.zones, this.title = "Speed Zones"});

  @override
  Widget build(BuildContext context) {
    final max = zones.fold<double>(0, (a, b) => a > b.value ? a : b.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[300])),
        const SizedBox(height: 12),
        ...zones.map((z) => _buildBar(z, max)),
      ],
    );
  }

  Widget _buildBar(ZoneData zone, double max) {
    final fraction = max > 0 ? zone.value / max : 0.0;
    const barHeight = 28.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(zone.label, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(
                    height: barHeight,
                    decoration: BoxDecoration(
                      gradient: zone.gradient,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "${(zone.value / 60).toStringAsFixed(0)}m ${(zone.value % 60).toStringAsFixed(0)}s",
                      style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
