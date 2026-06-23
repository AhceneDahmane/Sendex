import 'dart:math';

class DeviceInfo {
  final String id;
  final String name;
  final String address;
  final String ownerName;
  final int batteryLevel;
  final int colorValue;
  final DateTime addedAt;

  DeviceInfo({
    required this.id,
    required this.name,
    required this.address,
    this.ownerName = '',
    this.batteryLevel = 0,
    this.colorValue = 0xFF58A6FF,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  DeviceInfo copyWith({
    String? name,
    String? address,
    int? batteryLevel,
    int? colorValue,
  }) => DeviceInfo(
    id: id,
    name: name ?? this.name,
    address: address ?? this.address,
    ownerName: ownerName,
    batteryLevel: batteryLevel ?? this.batteryLevel,
    colorValue: colorValue ?? this.colorValue,
    addedAt: addedAt,
  );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'ownerName': ownerName,
        'batteryLevel': batteryLevel,
        'colorValue': colorValue,
        'addedAt': addedAt.toIso8601String(),
      };

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String,
        ownerName: json['ownerName'] as String? ?? '',
        batteryLevel: json['batteryLevel'] as int? ?? 0,
        colorValue: json['colorValue'] as int? ?? 0xFF58A6FF,
        addedAt: DateTime.parse(json['addedAt'] as String),
      );

  static String randomMac() {
    final r = Random();
    return "02:${_byte(r)}:${_byte(r)}:${_byte(r)}:${_byte(r)}:${_byte(r)}";
  }

  static String _byte(Random r) =>
      r.nextInt(256).toRadixString(16).padLeft(2, '0').toUpperCase();

  static const List<int> presetColors = [
    0xFF58A6FF,
    0xFF3FB950,
    0xFFD29922,
    0xFFF85149,
    0xFFBC8CFF,
    0xFFDA3633,
    0xFF79C0FF,
    0xFF56D364,
    0xFFE3B341,
    0xFFFF7B72,
  ];
}
