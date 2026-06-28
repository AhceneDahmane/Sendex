import 'dart:math';

class GpsPoint {
  final double lat;
  final double lng;
  final double speed;
  final double heartRate;
  final double acceleration;
  final DateTime timestamp;

  GpsPoint({
    required this.lat,
    required this.lng,
    required this.speed,
    this.heartRate = 0,
    this.acceleration = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  double get speedMps => speed * 1000 / 3600;

  double distanceTo(GpsPoint other) {
    const R = 6371000;
    final dLat = _toRad(other.lat - lat);
    final dLng = _toRad(other.lng - lng);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat)) * cos(_toRad(other.lat)) * sin(dLng / 2) * sin(dLng / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * pi / 180;

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'speed': speed,
        'heartRate': heartRate,
        'acceleration': acceleration,
        'timestamp': timestamp.toIso8601String(),
      };

  factory GpsPoint.fromJson(Map<String, dynamic> json) => GpsPoint(
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        speed: (json['speed'] as num).toDouble(),
        heartRate: (json['heartRate'] as num?)?.toDouble() ?? 0,
        acceleration: (json['acceleration'] as num?)?.toDouble() ?? 0,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
