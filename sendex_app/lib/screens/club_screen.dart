import 'package:flutter/material.dart';
import '../models/player_info.dart';
import '../services/storage_service.dart';
import '../widgets/register_player_dialog.dart';
import 'club_player_screen.dart';

class ClubScreen extends StatefulWidget {
  const ClubScreen({super.key});

  @override
  State<ClubScreen> createState() => _ClubScreenState();
}

class _ClubScreenState extends State<ClubScreen> {
  final _storage = StorageService.instance;

  void _logout() {
    _storage.isLoggedIn = false;
    _storage.playerName = null;
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _registerPlayer() async {
    final result = await showDialog<PlayerInfo>(
      context: context,
      builder: (_) => const RegisterPlayerDialog(),
    );
    if (result != null) {
      await _storage.savePlayerInfo(result);
      setState(() {});
    }
  }

  Future<void> _editPlayer(PlayerInfo player) async {
    final result = await showDialog<PlayerInfo>(
      context: context,
      builder: (_) => RegisterPlayerDialog(existing: player),
    );
    if (result != null) {
      await _storage.savePlayerInfo(result);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final players = _storage.getPlayerInfoList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_storage.playerName ?? "Club"),
        actions: [
          IconButton(icon: const Icon(Icons.person_add), onPressed: _registerPlayer, tooltip: "Register player"),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _registerPlayer,
        child: const Icon(Icons.add),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text("Players", style: Theme.of(context).textTheme.titleLarge),
          ),
          Expanded(
            child: players.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey[700]),
                        const SizedBox(height: 12),
                        Text("No players registered yet", style: TextStyle(color: Colors.grey[500])),
                        const SizedBox(height: 4),
                        Text("Tap + to add one", style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: players.length,
                    itemBuilder: (_, i) {
                      final p = players[i];
                      final sessionCount = _countSessionsForPlayer(p.name);
                      final deviceCount = _storage.getDevicesForPlayer(p.name).length;
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Text(p.name[0].toUpperCase())),
                          title: Text(p.displayInfo),
                          subtitle: Text("$deviceCount devices  •  $sessionCount sessions"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () => _editPlayer(p),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ClubPlayerScreen(playerName: p.name),
                              ),
                            ).then((_) => setState(() {}));
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  int _countSessionsForPlayer(String playerName) {
    int count = 0;
    for (final d in _storage.getDevices()) {
      for (final s in _storage.getSessions(d.id)) {
        if (s.playerName == playerName) count++;
      }
    }
    return count;
  }
}
