import 'dart:convert';

class PlayerInfo {
  final String name;
  final String club;
  final String sport;
  final String position;
  final double fieldLength;
  final double fieldWidth;

  PlayerInfo({
    required this.name,
    this.club = '',
    this.sport = 'Football',
    this.position = '',
    double? fieldLength,
    double? fieldWidth,
  })  : fieldLength = fieldLength ?? defaultLength(sport),

        fieldWidth = fieldWidth ?? defaultWidth(sport);
  static const List<String> sports = [
    'Football',
    'Basketball',
    'Rugby',
    'Handball',
    'Tennis',
    'Athletics',
    'Other',
  ];

  static const Map<String, List<String>> positionsBySport = {
    'Football': ['Goalkeeper', 'Defender', 'Midfielder', 'Forward'],
    'Basketball': ['Point Guard', 'Shooting Guard', 'Small Forward', 'Power Forward', 'Center'],
    'Rugby': ['Prop', 'Hooker', 'Lock', 'Flanker', 'Number 8', 'Scrum-half', 'Fly-half', 'Centre', 'Wing', 'Fullback'],
    'Handball': ['Goalkeeper', 'Left Wing', 'Left Back', 'Center Back', 'Right Back', 'Right Wing', 'Pivot'],
  };

  static List<String> positionsForSport(String sport) {
    return positionsBySport[sport] ?? [];
  }

  static double defaultLength(String sport) {
    switch (sport) {
      case 'Football': return 105;
      case 'Basketball': return 28;
      case 'Rugby': return 100;
      case 'Handball': return 40;
      case 'Tennis': return 23.77;
      case 'Athletics': return 100;
      default: return 100;
    }
  }

  static double defaultWidth(String sport) {
    switch (sport) {
      case 'Football': return 68;
      case 'Basketball': return 15;
      case 'Rugby': return 70;
      case 'Handball': return 20;
      case 'Tennis': return 10.97;
      case 'Athletics': return 100;
      default: return 50;
    }
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'club': club,
        'sport': sport,
        'position': position,
        'fieldLength': fieldLength,
        'fieldWidth': fieldWidth,
      };

  factory PlayerInfo.fromJson(Map<String, dynamic> json) => PlayerInfo(
        name: json['name'] as String? ?? '',
        club: json['club'] as String? ?? '',
        sport: json['sport'] as String? ?? 'Football',
        position: json['position'] as String? ?? '',
        fieldLength: (json['fieldLength'] as num?)?.toDouble(),
        fieldWidth: (json['fieldWidth'] as num?)?.toDouble(),
      );

  String get displayInfo {
    final parts = <String>[name];
    if (club.isNotEmpty) parts.add(club);
    if (position.isNotEmpty) parts.add(position);
    return parts.join('  •  ');
  }
}
