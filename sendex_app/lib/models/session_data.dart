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

  int get sprintCount {
    return points.where((p) => p.speed > 18).length;
  }

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
        endTime: json['endTime'] != null
            ? DateTime.parse(json['endTime'] as String)
            : null,
        points: (json['points'] as List<dynamic>)
            .map((p) => GpsPoint.fromJson(p as Map<String, dynamic>))
            .toList(),
        summary: json['summary'] as Map<String, dynamic>?,
      );
}
