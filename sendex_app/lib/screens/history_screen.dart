import 'package:flutter/material.dart';
import '../models/session_data.dart';
import '../services/storage_service.dart';
import 'session_review_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _storage = StorageService.instance;
  List<_SessionEntry> _sessions = [];
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _load();
    StorageService.sessionNotifier.addListener(_load);
  }

  @override
  void dispose() {
    StorageService.sessionNotifier.removeListener(_load);
    super.dispose();
  }

  void _load() {
    final entries = <_SessionEntry>[];
    for (final d in _storage.getDevices()) {
      for (final s in _storage.getSessions(d.id)) {
        entries.add(_SessionEntry(session: s, deviceName: d.name));
      }
    }
    entries.sort((a, b) => b.session.startTime.compareTo(a.session.startTime));
    if (mounted) setState(() => _sessions = entries);
  }

  List<_SessionEntry> get _filtered {
    if (_filter.isEmpty) return _sessions;
    return _sessions
        .where((e) => e.session.playerName.toLowerCase().contains(_filter.toLowerCase()))
        .toList();
  }

  String _fmtDur(Duration d) {
    final h = d.inHours, m = d.inMinutes.remainder(60), s = d.inSeconds.remainder(60);
    return h > 0 ? "${h}h ${m}m" : "${m}m ${s}s";
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(title: const Text("History")),
      body: Column(
        children: [
          if (_sessions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Search by player name...",
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  filled: true,
                  fillColor: Colors.grey[900],
                ),
                onChanged: (v) => setState(() => _filter = v),
              ),
            ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey[700]),
                        const SizedBox(height: 12),
                        Text(_sessions.isEmpty ? "No sessions yet" : "No matches",
                            style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final e = filtered[i];
                      final s = e.session;
                      final date =
                          "${s.startTime.day.toString().padLeft(2, '0')}/${s.startTime.month.toString().padLeft(2, '0')}/${s.startTime.year}";
                      final time =
                          "${s.startTime.hour.toString().padLeft(2, '0')}:${s.startTime.minute.toString().padLeft(2, '0')}";
                      return Dismissible(
                        key: ValueKey(s.id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) => showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Delete Session"),
                            content:
                                Text("Remove session from ${s.playerName} on $date?"),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text("Cancel")),
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text("Delete",
                                      style: TextStyle(
                                          color: Theme.of(ctx).colorScheme.error))),
                            ],
                          ),
                        ).then((v) => v ?? false),
                        onDismissed: (_) {
                          _storage.deleteSession(s.deviceId, s.id);
                          setState(() => _load());
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Colors.red[900],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child:
                              const Icon(Icons.delete_outline, color: Colors.white),
                        ),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    SessionReviewScreen(session: s),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withAlpha(30),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        s.playerName.isNotEmpty
                                            ? s.playerName[0].toUpperCase()
                                            : "?",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(s.playerName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 4),
                                        Text("$date · $time",
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[500])),
                                        const SizedBox(height: 2),
                                        Text(e.deviceName,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[600])),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        "${s.maxSpeed.toStringAsFixed(1)} km/h",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _fmtDur(s.duration),
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500]),
                                      ),
                                      Text(
                                        "${s.totalDistance.toStringAsFixed(0)} m",
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.chevron_right,
                                      size: 18, color: Colors.grey[600]),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SessionEntry {
  final SessionData session;
  final String deviceName;
  const _SessionEntry({required this.session, required this.deviceName});
}
