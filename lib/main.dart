import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/api_config.dart';
import 'providers/auth_provider.dart';
import 'providers/class_provider.dart';
import 'providers/quiz_provider.dart';
import 'theme/app_theme.dart';
import 'screens/main_shell_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';

void main() {
  // ── Server IP configuration ─────────────────────────────────────────────
  // Set to your machine's local IP so physical devices on the same WiFi can reach it.
  // Run: ip addr show | grep "192.168"  to find your IP.
  ApiConfig.setHost('192.168.1.15');
  // ──────────────────────────────────────────────────────────────────────────

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..loadUser()),
        ChangeNotifierProvider(create: (_) => ClassProvider()),
        ChangeNotifierProvider(create: (_) => QuizProvider()),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qweez Student',
      theme: AppTheme.lightTheme,
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.isInitializing) {
            return const SplashScreen();
          }
          return auth.isAuthenticated ? const MainShellScreen() : const LoginScreen();
        },
      ),
    );
  }
}
