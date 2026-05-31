import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() {
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
