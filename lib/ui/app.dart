import 'package:flutter/material.dart';
import 'package:youtrack_timer/ui/screens/home_screen.dart';
import 'package:youtrack_timer/ui/theme/app_theme.dart';

/// Корневое приложение.
class YouTrackTimerApp extends StatelessWidget {
  const YouTrackTimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YouTrack Timer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const HomeScreen(),
    );
  }
}
