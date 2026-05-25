import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:youtrack_timer/logging/app_log.dart';
import 'package:youtrack_timer/ui/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  await AppLog.instance.init();
  AppLog.instance.info(LogCategory.app, 'Приложение запущено');
  runApp(const ProviderScope(child: YouTrackTimerApp()));
}
