import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
      locale: const Locale('ru'),
      supportedLocales: const [
        Locale('ru'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.dark(),
      home: const HomeScreen(),
    );
  }
}
