import 'gps_point.dart';

class SessionData {
  final String id;
  final String deviceId;
  final String playerName;
  final DateTime startTime;
  final DateTime? endTime;
  final List<GpsPoint> points;
  final Map<String, dynamic>? summary;

  SessionData({
    required this.id,
    required this.deviceId,
    required this.playerName,
    required this.startTime,
    this.endTime,
    List<GpsPoint>? points,
    this.summary,
  }) : points = points ?? [];

  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  double get maxSpeed {
    if (points.isEmpty) return 0;
    return points.map((p) => p.speed).reduce((a, b) => a > b ? a : b);
  }

  double get avgSpeed {
    if (points.isEmpty) return 0;
    return points.map((p) => p.speed).reduce((a, b) => a + b) / points.length;
  }

  double get minSpeed => points.isEmpty ? 0 : points.map((p) => p.speed).reduce((a, b) => a < b ? a : b);

  double get totalDistance {
    if (points.length < 2) return 0;
    double dist = 0;
    for (int i = 1; i < points.length; i++) {
      dist += points[i - 1].distanceTo(points[i]);
    }
    return dist;
  }

  int get sprintCount => points.where((p) => p.speed > 18).length;

  double get avgSprintSpeed {
    final sprints = points.where((p) => p.speed > 18);
    if (sprints.isEmpty) return 0;
    return sprints.map((p) => p.speed).reduce((a, b) => a + b) / sprints.length;
  }

  double get maxSprintSpeed => points.where((p) => p.speed > 18).map((p) => p.speed).fold<double>(0, (a, b) => a > b ? a : b);

  double get totalSprintDistance {
    if (points.length < 2) return 0;
    double dist = 0;
    for (int i = 1; i < points.length; i++) {
      if (points[i].speed > 18 || points[i - 1].speed > 18) {
        dist += points[i - 1].distanceTo(points[i]);
      }
    }
    return dist;
  }

  double get avgHeartRate {
    final rates = points.where((p) => p.heartRate > 0);
    if (rates.isEmpty) return 0;
    return rates.map((p) => p.heartRate).reduce((a, b) => a + b) / rates.length;
  }

  double get maxHeartRate {
    final rates = points.where((p) => p.heartRate > 0);
    if (rates.isEmpty) return 0;
    return rates.map((p) => p.heartRate).reduce((a, b) => a > b ? a : b);
  }

  double get minHeartRate {
    final rates = points.where((p) => p.heartRate > 0);
    if (rates.isEmpty) return 0;
    return rates.map((p) => p.heartRate).reduce((a, b) => a < b ? a : b);
  }

  int get accelerations => points.where((p) => p.acceleration > 3).length;
  int get decelerations => points.where((p) => p.acceleration < -3).length;

  double get avgAcceleration {
    if (points.where((p) => p.acceleration != 0).isEmpty) return 0;
    return points.map((p) => p.acceleration.abs()).reduce((a, b) => a + b) / points.length;
  }

  Duration get timeInZone0to7 => _timeInZone(0, 7);
  Duration get timeInZone7to12 => _timeInZone(7, 12);
  Duration get timeInZone12to18 => _timeInZone(12, 18);
  Duration get timeInZone18plus => _timeInZone(18, 999);

  Duration _timeInZone(double min, double max) {
    final inZone = points.where((p) => p.speed >= min && p.speed < max);
    return Duration(seconds: inZone.length);
  }

  double get intensityIndex {
    if (points.isEmpty) return 0;
    final highIntensity = points.where((p) => p.speed > 12 || p.heartRate > 150).length;
    return (highIntensity / points.length) * 100;
  }

  double get workload => totalDistance * avgHeartRate / 100;

  Map<String, dynamic> toJson() => {
        'id': id,
        'deviceId': deviceId,
        'playerName': playerName,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'points': points.map((p) => p.toJson()).toList(),
        'summary': summary,
      };

  factory SessionData.fromJson(Map<String, dynamic> json) => SessionData(
        id: json['id'] as String,
        deviceId: json['deviceId'] as String,
        playerName: json['playerName'] as String,
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: json['endTime'] != null ? DateTime.parse(json['endTime'] as String) : null,
        points: (json['points'] as List<dynamic>).map((p) => GpsPoint.fromJson(p as Map<String, dynamic>)).toList(),
        summary: json['summary'] as Map<String, dynamic>?,
      );
}
