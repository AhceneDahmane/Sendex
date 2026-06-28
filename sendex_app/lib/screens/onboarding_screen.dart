import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import 'landing_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  static const _pages = [
    _PageData(
      icon: Icons.sensors,
      title: "Welcome to Sendex",
      desc: "Pro-level GPS tracking for athletes and teams. Track every sprint, every run, every game.",
      color: Color(0xFF58A6FF),
    ),
    _PageData(
      icon: Icons.speed,
      title: "Live Performance Data",
      desc: "Real-time speed, heart rate, distance covered, and heatmaps. All synced to your phone via BLE.",
      color: Color(0xFF3FB950),
    ),
    _PageData(
      icon: Icons.groups,
      title: "For Players & Clubs",
      desc: "Individuals track their own progress. Clubs manage multiple players, compare stats, and export reports.",
      color: Color(0xFFD29922),
    ),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _ctrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _done();
    }
  }

  void _done() {
    StorageService.instance.onboardingDone = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LandingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _ctrl,
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                for (final p in _pages)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: p.color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: Icon(p.icon, size: 56, color: p.color),
                        ),
                        const SizedBox(height: 40),
                        Text(p.title, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: cs.onSurface)),
                        const SizedBox(height: 16),
                        Text(
                          p.desc,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, color: cs.onSurface.withOpacity(0.7), height: 1.5),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _pages.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _page ? cs.primary : cs.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 32),
          // Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _next,
                    child: Text(_page < _pages.length - 1 ? "Next" : "Get Started"),
                  ),
                ),
                const SizedBox(height: 12),
                if (_page < _pages.length - 1)
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: TextButton(
                      onPressed: _done,
                      child: const Text("Skip"),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageData {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  const _PageData({required this.icon, required this.title, required this.desc, required this.color});
}
