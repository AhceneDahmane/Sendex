import 'dart:convert';

class PlayerInfo {
  final String name;
  final String club;
  final String sport;
  final String position;

  PlayerInfo({
    required this.name,
    this.club = '',
    this.sport = 'Football',
    this.position = '',
  });

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

  Map<String, dynamic> toJson() => {
        'name': name,
        'club': club,
        'sport': sport,
        'position': position,
      };

  factory PlayerInfo.fromJson(Map<String, dynamic> json) => PlayerInfo(
        name: json['name'] as String? ?? '',
        club: json['club'] as String? ?? '',
        sport: json['sport'] as String? ?? 'Football',
        position: json['position'] as String? ?? '',
      );

  String get displayInfo {
    final parts = <String>[name];
    if (club.isNotEmpty) parts.add(club);
    if (position.isNotEmpty) parts.add(position);
    return parts.join('  •  ');
  }
}
