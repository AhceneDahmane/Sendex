import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import 'player_profile_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _storage = StorageService.instance;
  List<MapEntry<String, int>> _entries = [];

  @override
  void initState() {
    super.initState();
    _reload();
    StorageService.sessionNotifier.addListener(_reload);
    StorageService.deviceNotifier.addListener(_reload);
  }

  @override
  void dispose() {
    StorageService.sessionNotifier.removeListener(_reload);
    StorageService.deviceNotifier.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    final players = _storage.getPlayerInfoList();
    final entries = <MapEntry<String, int>>[];
    for (final p in players) {
      final devices = _storage.getDevicesForPlayer(p.name);
      int total = 0;
      for (final d in devices) {
        total += _storage.getSessions(d.id).length;
      }
      entries.add(MapEntry(p.name, total));
    }
    entries.sort((a, b) => b.value.compareTo(a.value));
    if (mounted) setState(() => _entries = entries);
  }

  void _logout() {
    _storage.logout();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Leaderboard"),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _entries.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.leaderboard, size: 64, color: Colors.grey[600]),
                  const SizedBox(height: 12),
                  Text("No data yet", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                  const SizedBox(height: 8),
                  Text("Start a session to appear on the leaderboard",
                      style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _entries.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        const SizedBox(width: 40),
                        Expanded(child: Text("Player", style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w600))),
                        Text("Sessions", style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w600)),
                        const SizedBox(width: 16),
                      ],
                    ),
                  );
                }
                final entry = _entries[i - 1];
                final rank = i;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: rank == 1
                          ? Colors.amber
                          : rank == 2
                              ? Colors.grey[400]
                              : rank == 3
                                  ? Colors.brown[300]
                                  : Colors.grey[800],
                      child: Text("$rank", style: TextStyle(color: rank <= 3 ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(entry.key),
                    trailing: Text("${entry.value} sessions", style: const TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PlayerProfileScreen(playerName: entry.key)),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
