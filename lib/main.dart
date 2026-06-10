import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'services/api_client.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Restore any saved login token so a kiosk device stays authenticated.
  await ApiClient.instance.restoreToken();
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
