import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:youtrack_timer/youtrack/youtrack_credentials.dart';

/// Глобальный экземпляр dotenv (загружается один раз).
final _dotenv = DotEnv(includePlatformEnvironment: true);

/// Настройки подключения к YouTrack.
class AppConfig {
  AppConfig({
    required this.baseUrl,
    required this.token,
    required this.startDate,
    required this.endDate,
    this.dryRun = false,
  });

  final String baseUrl;
  final String token;
  final DateTime startDate;
  final DateTime endDate;
  final bool dryRun;

  /// Загружает конфигурацию из .env, переменных окружения и аргументов CLI.
  static AppConfig load({
    String? baseUrl,
    String? token,
    required DateTime startDate,
    required DateTime endDate,
    bool dryRun = false,
  }) {
    _loadEnvFile();

    final resolvedBaseUrl = _firstNonEmpty([
      baseUrl,
      Platform.environment['YOUTRACK_URL'],
      _dotenv['YOUTRACK_URL'],
    ]);
    final resolvedToken = _firstNonEmpty([
      token,
      Platform.environment['YOUTRACK_TOKEN'],
      _dotenv['YOUTRACK_TOKEN'],
    ]);

    if (resolvedBaseUrl == null || resolvedBaseUrl.isEmpty) {
      throw ArgumentError(
        'Не указан URL YouTrack. Задайте YOUTRACK_URL в .env или --base-url.',
      );
    }
    if (resolvedToken == null || resolvedToken.isEmpty) {
      throw ArgumentError(
        'Не указан токен. Задайте YOUTRACK_TOKEN в .env или --token.',
      );
    }

    return AppConfig(
      baseUrl: YouTrackCredentials.normalizeBaseUrl(resolvedBaseUrl),
      token: YouTrackCredentials.normalizeToken(resolvedToken),
      startDate: _dateOnly(startDate),
      endDate: _dateOnly(endDate),
      dryRun: dryRun,
    );
  }

  static void _loadEnvFile() {
    final candidates = ['.env', '../.env'];
    for (final path in candidates) {
      if (File(path).existsSync()) {
        _dotenv.load([path]);
        return;
      }
    }
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
