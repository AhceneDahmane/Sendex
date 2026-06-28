import 'package:flutter/material.dart';
import '../models/session_data.dart';
import '../services/storage_service.dart';

class _WeeklySummary {
  final int year;
  final int week;
  final DateTime startOfWeek;
  int sessionCount = 0;
  double totalDurationMinutes = 0;
  double totalDistance = 0;
  int totalSprints = 0;
  double totalSprintDistance = 0;
  double cumulativeMaxSpeed = 0;
  double cumulativeAvgSpeed = 0;
  double cumulativeAvgHr = 0;
  double cumulativeIntensity = 0;
  double cumulativeWorkload = 0;

  _WeeklySummary({required this.year, required this.week, required this.startOfWeek});

  double get avgMaxSpeed => sessionCount > 0 ? cumulativeMaxSpeed / sessionCount : 0;
  double get avgAvgSpeed => sessionCount > 0 ? cumulativeAvgSpeed / sessionCount : 0;
  double get avgHeartRate => sessionCount > 0 ? cumulativeAvgHr / sessionCount : 0;
  double get avgIntensityIndex => sessionCount > 0 ? cumulativeIntensity / sessionCount : 0;
  double get avgWorkload => sessionCount > 0 ? cumulativeWorkload / sessionCount : 0;
}

class TrendsScreen extends StatefulWidget {
  final String? initialPlayer; // null = show selector for clubs
  const TrendsScreen({super.key, this.initialPlayer});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  final _storage = StorageService.instance;
  String? _selectedPlayer;
  int _metricIndex = 0;

  static const _metrics = [
    "Max Speed",
    "Avg Speed",
    "Total Distance",
    "Sprint Count",
    "Sprint Distance",
    "Avg HR",
    "Intensity",
    "Workload",
  ];

  List<_WeeklySummary> _weeks = [];
  double _maxMetricValue = 0;

  @override
  void initState() {
    super.initState();
    _selectedPlayer = widget.initialPlayer ?? _storage.playerName;
    _aggregate();
    StorageService.sessionNotifier.addListener(_aggregate);
  }

  @override
  void dispose() {
    StorageService.sessionNotifier.removeListener(_aggregate);
    super.dispose();
  }

  void _aggregate() {
    if (_selectedPlayer == null) {
      if (mounted) setState(() { _weeks = []; _maxMetricValue = 0; });
      return;
    }

    final allSessions = <SessionData>[];
    for (final d in _storage.getDevices()) {
      allSessions.addAll(_storage.getSessions(d.id));
    }

    final playerSessions = allSessions
        .where((s) => s.playerName == _selectedPlayer)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final Map<String, _WeeklySummary> weekMap = {};
    for (final s in playerSessions) {
      final start = s.startTime;
      final weekStart = start.subtract(Duration(days: start.weekday - 1));
      final key = "${start.year}-${start.weekday <= 1 ? ((start.month == 1 && start.weekday == 1) ? 1 : start.weekday) : start.weekday}";
      // Use ISO week calculation
      final weekNum = _isoWeekNumber(start);
      final weekKey = "${start.year}-W${weekNum.toString().padLeft(2, '0')}";
      final ws = weekMap.putIfAbsent(weekKey, () => _WeeklySummary(
        year: start.year,
        week: weekNum,
        startOfWeek: weekStart,
      ));

      ws.sessionCount++;
      ws.totalDurationMinutes += s.duration.inMinutes;
      ws.totalDistance += s.totalDistance;
      ws.totalSprints += s.sprintCount;
      ws.totalSprintDistance += s.totalSprintDistance;
      ws.cumulativeMaxSpeed += s.maxSpeed;
      ws.cumulativeAvgSpeed += s.avgSpeed;
      ws.cumulativeAvgHr += s.avgHeartRate;
      ws.cumulativeIntensity += s.intensityIndex;
      ws.cumulativeWorkload += s.workload;
    }

    _weeks = weekMap.values.toList()..sort((a, b) {
      final cmp = a.year.compareTo(b.year);
      if (cmp != 0) return cmp;
      return a.week.compareTo(b.week);
    });

    _recalcMax();
    setState(() {});
  }

  int _isoWeekNumber(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(startOfYear).inDays + 1;
    final week = ((dayOfYear - date.weekday + 10) / 7).floor();
    if (week < 1) return _isoWeekNumber(DateTime(date.year - 1, 12, 31));
    if (week > 52) return 1;
    return week;
  }

  void _recalcMax() {
    if (_weeks.isEmpty) { _maxMetricValue = 0; return; }
    _maxMetricValue = _weeks.map((w) => _valueForMetric(w)).reduce((a, b) => a > b ? a : b);
    if (_maxMetricValue == 0) _maxMetricValue = 1;
  }

  double _valueForMetric(_WeeklySummary w) {
    switch (_metricIndex) {
      case 0: return w.avgMaxSpeed;
      case 1: return w.avgAvgSpeed;
      case 2: return w.totalDistance;
      case 3: return w.totalSprints.toDouble();
      case 4: return w.totalSprintDistance;
      case 5: return w.avgHeartRate;
      case 6: return w.avgIntensityIndex;
      case 7: return w.avgWorkload;
      default: return 0;
    }
  }

  String _formatValue(double v) {
    switch (_metricIndex) {
      case 0: case 1: return "${v.toStringAsFixed(1)} km/h";
      case 2: case 4: return v >= 1000 ? "${(v / 1000).toStringAsFixed(2)} km" : "${v.toStringAsFixed(0)} m";
      case 3: return "${v.toInt()}";
      case 5: return "${v.toStringAsFixed(0)} bpm";
      case 6: return "${v.toStringAsFixed(1)}%";
      case 7: return v >= 1000 ? "${(v / 1000).toStringAsFixed(1)}k" : v.toStringAsFixed(0);
      default: return v.toStringAsFixed(1);
    }
  }

  String _formatSmallValue(double v) {
    switch (_metricIndex) {
      case 2: case 4: return v >= 1000 ? "${(v / 1000).toStringAsFixed(1)} km" : "${v.toStringAsFixed(0)} m";
      case 7: return v >= 1000 ? "${(v / 1000).toStringAsFixed(1)}k" : v.toStringAsFixed(0);
      default: return v.toStringAsFixed(1);
    }
  }

  String _metricUnit() {
    switch (_metricIndex) {
      case 0: return "km/h";
      case 1: return "km/h";
      case 2: return "m";
      case 3: return "";
      case 4: return "m";
      case 5: return "bpm";
      case 6: return "%";
      case 7: return "";
      default: return "";
    }
  }

  String _weekLabel(_WeeklySummary w) {
    return "${w.startOfWeek.day}/${w.startOfWeek.month}";
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isClub = _storage.role == 'club';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Trends"),
        actions: isClub
            ? [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.person_search),
                  tooltip: "Select player",
                  onSelected: (name) {
                    _selectedPlayer = name;
                    _aggregate();
                  },
                  itemBuilder: (_) => [
                    for (final p in _storage.getPlayers())
                      PopupMenuItem(value: p, child: Text(p)),
                  ],
                ),
              ]
            : null,
      ),
      body: _selectedPlayer == null
          ? Center(child: Text("Select a player", style: TextStyle(color: cs.onSurface.withOpacity(0.6))))
          : _weeks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.trending_flat, size: 64, color: cs.onSurface.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text("No sessions yet", style: TextStyle(fontSize: 18, color: cs.onSurface.withOpacity(0.6))),
                      const SizedBox(height: 8),
                      Text("Sessions will appear here weekly", style: TextStyle(color: cs.onSurface.withOpacity(0.4))),
                    ],
                  ),
                )
              : _buildContent(cs),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    return Column(
      children: [
        // Player name header
        if (_storage.role == 'club')
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: cs.surfaceContainerHighest,
            child: Text(
              _selectedPlayer!,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cs.primary),
            ),
          ),
        // Metric chips
        Container(
          height: 44,
          margin: const EdgeInsets.only(top: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (var i = 0; i < _metrics.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(_metrics[i], style: TextStyle(fontSize: 12, fontWeight: i == _metricIndex ? FontWeight.w600 : FontWeight.normal)),
                    selected: i == _metricIndex,
                    onSelected: (_) => setState(() { _metricIndex = i; _recalcMax(); }),
                  ),
                ),
            ],
          ),
        ),
        // Summary cards
        if (_weeks.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(child: _summaryCard(cs, "Best Week", _formatValue(_maxMetricValue), cs.primary)),
                const SizedBox(width: 8),
                Expanded(child: _summaryCard(cs, "Average", _formatValue(_weeks.map((w) => _valueForMetric(w)).reduce((a, b) => a + b) / _weeks.length), Colors.orange)),
                const SizedBox(width: 8),
                Expanded(child: _summaryCard(cs, "Last Week", _formatValue(_valueForMetric(_weeks.last)), Colors.green)),
              ],
            ),
          ),
        ],
        // Bar chart
        Expanded(
          child: _weeks.length <= 6
              ? _buildBarChart(cs)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    SizedBox(
                      height: 220,
                      child: _buildBarChart(cs),
                    ),
                    const SizedBox(height: 16),
                    Text("Weekly Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cs.onSurface)),
                    const SizedBox(height: 8),
                    for (final w in _weeks.reversed)
                      _weeklyRow(cs, w),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _summaryCard(ColorScheme cs, String label, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.6))),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(ColorScheme cs) {
    if (_weeks.isEmpty) return const SizedBox();
    final maxVal = _maxMetricValue;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final w in _weeks)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _Bar(
                        value: _valueForMetric(w),
                        maxValue: maxVal,
                        label: _weekLabel(w),
                        color: cs.primary,
                        formatValue: (v) => _formatSmallValue(v),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final w in _weeks)
                Expanded(
                  child: Text(
                    _weekLabel(w),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, color: cs.onSurface.withOpacity(0.5)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _weeklyRow(ColorScheme cs, _WeeklySummary w) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              "W${w.week} ${w.year}",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: cs.onSurface.withOpacity(0.7)),
            ),
          ),
          Expanded(child: Text(_formatSmallValue(_valueForMetric(w)), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          Text(
            "${w.sessionCount} session${w.sessionCount > 1 ? 's' : ''}",
            style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double value;
  final double maxValue;
  final String label;
  final Color color;
  final String Function(double) formatValue;

  const _Bar({
    required this.value,
    required this.maxValue,
    required this.label,
    required this.color,
    required this.formatValue,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(formatValue(value), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
        const SizedBox(height: 2),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              height: (fraction * 160).clamp(4.0, double.infinity),
              decoration: BoxDecoration(
                color: color.withOpacity(0.7),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
