class GpsPoint {
  final double lat;
  final double lng;
  final double speed;
  final double heartRate;
  final DateTime timestamp;

  GpsPoint({
    required this.lat,
    required this.lng,
    required this.speed,
    this.heartRate = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  double get speedMps => speed * 1000 / 3600;

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'speed': speed,
        'heartRate': heartRate,
        'timestamp': timestamp.toIso8601String(),
      };

  factory GpsPoint.fromJson(Map<String, dynamic> json) => GpsPoint(
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        speed: (json['speed'] as num).toDouble(),
        heartRate: (json['heartRate'] as num?)?.toDouble() ?? 0,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
