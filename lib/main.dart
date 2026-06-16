import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'services/mock_auth.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Restore the saved session so the admin stays logged in across app
  // restarts (no automatic logout). Only the Log Out button signs out.
  await MockAuth.instance.restore();
  runApp(const ZegarApp());
}

class ZegarApp extends StatelessWidget {
  const ZegarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zegar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}
