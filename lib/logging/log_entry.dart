import 'package:intl/intl.dart';
import 'package:youtrack_timer/logging/log_level.dart';

/// Одна запись журнала.
class LogEntry {
  LogEntry({
    required this.time,
    required this.level,
    required this.category,
    required this.message,
  });

  final DateTime time;
  final LogLevel level;
  final String category;
  final String message;

  String get timeLabel => DateFormat('HH:mm:ss.SSS').format(time);

  String get line => '[$timeLabel] [${level.label}] [$category] $message';

  @override
  String toString() => line;
}
