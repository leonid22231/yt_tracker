/// Уровни логирования (от самого подробного к критичному).
enum LogLevel {
  debug,
  info,
  success,
  warn,
  error;

  int get priority => index;

  bool satisfies(LogLevel minimum) => priority >= minimum.priority;

  String get label => switch (this) {
        LogLevel.debug => 'DEBUG',
        LogLevel.info => 'INFO',
        LogLevel.success => 'OK',
        LogLevel.warn => 'WARN',
        LogLevel.error => 'ERROR',
      };
}
