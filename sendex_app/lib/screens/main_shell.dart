import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import 'club_dashboard_screen.dart';
import 'devices_screen.dart';
import 'club_screen.dart';
import 'leaderboard_screen.dart';
import 'history_screen.dart';
import 'trends_screen.dart';
import 'settings_screen.dart';
import 'subscription_screen.dart';

class MainShell extends StatefulWidget {
  final String role;
  const MainShell({super.key, required this.role});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final isClub = widget.role == 'club';

    final screens = isClub
        ? [const ClubDashboardScreen(), const ClubScreen(), const LeaderboardScreen(), const TrendsScreen(), const HistoryScreen(), const SubscriptionScreen()]
        : [const DevicesScreen(), const LeaderboardScreen(), const TrendsScreen(), const HistoryScreen(), const SubscriptionScreen()];

    final labels = isClub
        ? const ["Dashboard", "Club", "Leaderboard", "Trends", "History", "Subscription"]
        : const ["Devices", "Leaderboard", "Trends", "History", "Subscription"];

    final icons = isClub
        ? [Icons.monitor_heart, Icons.groups, Icons.leaderboard, Icons.trending_up, Icons.history, Icons.subscriptions]
        : [Icons.sensors, Icons.leaderboard, Icons.trending_up, Icons.history, Icons.subscriptions];

    return Scaffold(
      body: IndexedStack(index: _tab, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          for (var i = 0; i < labels.length; i++)
            NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: FloatingActionButton.small(
          heroTag: "settings",
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          child: const Icon(Icons.settings),
        ),
      ),
    );
  }
}
