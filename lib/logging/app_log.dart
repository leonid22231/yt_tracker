import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:youtrack_timer/logging/log_entry.dart';
import 'package:youtrack_timer/logging/log_level.dart';
import 'package:youtrack_timer/logging/log_sanitizer.dart';
import 'package:youtrack_timer/logging/log_sink.dart';

/// Категории для фильтрации в UI.
abstract class LogCategory {
  static const app = 'app';
  static const youtrack = 'youtrack';
  static const cursor = 'cursor';
  static const plan = 'plan';
  static const submit = 'submit';
}

/// Центральный журнал приложения (singleton).
class AppLog {
  AppLog._();
  static final AppLog instance = AppLog._();

  static const _maxEntries = 2000;

  final List<LogEntry> _entries = [];
  final List<LogSink> _sinks = [];
  final _streamController = StreamController<List<LogEntry>>.broadcast();

  Stream<List<LogEntry>> get stream => _streamController.stream;
  List<LogEntry> get entries => List.unmodifiable(_entries);

  /// Инициализация при старте (консоль + файл на desktop).
  Future<void> init({
    bool enableConsole = true,
    bool enableFile = !kIsWeb,
    LogLevel consoleLevel = LogLevel.debug,
    LogLevel fileLevel = LogLevel.info,
  }) async {
    if (enableConsole && !_hasSink<ConsoleLogSink>()) {
      addSink(ConsoleLogSink(minimumLevel: consoleLevel));
    }
    if (enableFile && !_hasSink<FileLogSink>()) {
      final fileSink = FileLogSink(minimumLevel: fileLevel);
      await fileSink.init();
      addSink(fileSink);
    }
  }

  bool _hasSink<T extends LogSink>() => _sinks.any((s) => s is T);

  void addSink(LogSink sink) {
    if (!_sinks.contains(sink)) _sinks.add(sink);
  }

  void debug(String category, String message) =>
      _log(LogLevel.debug, category, message);

  void info(String category, String message) =>
      _log(LogLevel.info, category, message);

  void success(String category, String message) =>
      _log(LogLevel.success, category, message);

  void warn(String category, String message) =>
      _log(LogLevel.warn, category, message);

  void error(String category, String message, [Object? err, StackTrace? st]) {
    final buf = StringBuffer(message);
    if (err != null) buf.write(' — $err');
    if (st != null) {
      final lines = st.toString().split('\n').take(4).join('\n');
      buf.write('\n$lines');
    }
    _log(LogLevel.error, category, buf.toString());
  }

  /// HTTP-запрос без чувствительных данных.
  void http(
    String category, {
    required String method,
    required String path,
    int? status,
    String? detail,
  }) {
    final statusPart = status != null ? ' → $status' : '';
    final detailPart = detail != null ? ' ($detail)' : '';
    info(category, '$method $path$statusPart$detailPart');
  }

  void clear() {
    _entries.clear();
    _emit();
  }

  void _log(LogLevel level, String category, String message) {
    final entry = LogEntry(
      time: DateTime.now(),
      level: level,
      category: category,
      message: LogSanitizer.sanitize(message),
    );

    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }

    for (final sink in _sinks) {
      sink.write(entry);
    }
    _emit();
  }

  void _emit() {
    if (!_streamController.isClosed) {
      _streamController.add(List.unmodifiable(_entries));
    }
  }

  Future<void> dispose() async {
    for (final sink in _sinks) {
      await sink.dispose();
    }
    await _streamController.close();
  }
}

/// Совместимость с CLI (`TimerService` и `bin/`).
class AppLogger {
  AppLogger({this.category = LogCategory.app});

  final String category;

  void info(String message) => AppLog.instance.info(category, message);
  void warn(String message) => AppLog.instance.warn(category, message);
  void error(String message) => AppLog.instance.error(category, message);
  void success(String message) => AppLog.instance.success(category, message);
  void debug(String message) => AppLog.instance.debug(category, message);
}
