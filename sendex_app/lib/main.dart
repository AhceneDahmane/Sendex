import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_shell.dart';
import 'screens/landing_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.instance.init();
  runApp(const SendexApp());
}

class SendexApp extends StatelessWidget {
  const SendexApp({super.key});

  @override
  Widget build(BuildContext context) {
    final s = StorageService.instance;

    Widget home;
    if (!s.onboardingDone) {
      home = const OnboardingScreen();
    } else if (s.isLoggedIn) {
      home = MainShell(role: s.role ?? 'player');
    } else {
      home = const LandingScreen();
    }

    return MaterialApp(
      title: 'Sendex',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF58A6FF),
          brightness: Brightness.dark,
        ),
      ),
      home: home,
      routes: {
        '/login': (_) => const LandingScreen(),
      },
    );
  }
}
