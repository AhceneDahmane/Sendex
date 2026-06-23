import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import 'devices_screen.dart';
import 'club_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _controller = TextEditingController();
  final _storage = StorageService.instance;
  bool _isClub = false;

  void _login() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    _storage.playerName = name;
    _storage.isLoggedIn = true;
    _storage.role = _isClub ? 'club' : 'player';

    if (!_isClub) {
      _storage.addPlayer(name);
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => _isClub ? const ClubScreen() : const DevicesScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sports_soccer, size: 80, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text("Sendex", style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text("Athlete Performance Tracker",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey)),
              const SizedBox(height: 32),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text("Player"), icon: Icon(Icons.person)),
                  ButtonSegment(value: true, label: Text("Club"), icon: Icon(Icons.groups)),
                ],
                selected: {_isClub},
                onSelectionChanged: (v) => setState(() => _isClub = v.first),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  labelText: _isClub ? "Club Name" : "Player Name",
                  prefixIcon: Icon(_isClub ? Icons.groups : Icons.person),
                  border: const OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _login,
                icon: const Icon(Icons.arrow_forward),
                label: Text(_isClub ? "Enter Club" : "Get Started"),
                style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
