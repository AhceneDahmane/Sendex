import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'screens/login_screen.dart';
import 'screens/devices_screen.dart';
import 'screens/club_screen.dart';

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
    final home = s.isLoggedIn
        ? (s.role == 'club' ? const ClubScreen() : const DevicesScreen())
        : const LoginScreen();

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
        '/login': (_) => const LoginScreen(),
        '/devices': (_) => const DevicesScreen(),
        '/club': (_) => const ClubScreen(),
      },
    );
  }
}
