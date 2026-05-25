import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtrack_timer/logging/log_entry.dart';
import 'package:youtrack_timer/logging/log_level.dart';

/// Приёмник записей лога.
abstract class LogSink {
  void write(LogEntry entry);
  Future<void> dispose() async {}
}

/// Вывод в консоль (CLI и `flutter run`).
class ConsoleLogSink implements LogSink {
  ConsoleLogSink({this.minimumLevel = LogLevel.debug});

  final LogLevel minimumLevel;

  @override
  void write(LogEntry entry) {
    if (!entry.level.satisfies(minimumLevel)) return;
    // ignore: avoid_print
    debugPrint(entry.line);
  }

  @override
  Future<void> dispose() async {}
}

/// Дозапись в файл (Windows / desktop).
class FileLogSink implements LogSink {
  FileLogSink({this.minimumLevel = LogLevel.info});

  final LogLevel minimumLevel;
  IOSink? _sink;
  final _init = Completer<void>();

  Future<void> ensureInitialized() => _init.future;

  Future<void> init() async {
    if (_init.isCompleted) return;
    try {
      final dir = await getApplicationSupportDirectory();
      final logsDir = Directory('${dir.path}${Platform.pathSeparator}logs');
      if (!logsDir.existsSync()) {
        logsDir.createSync(recursive: true);
      }
      final name = 'youtrack_timer_'
          '${DateTime.now().toIso8601String().substring(0, 10)}.log';
      final file = File('${logsDir.path}${Platform.pathSeparator}$name');
      _sink = file.openWrite(mode: FileMode.append);
      _sink!.writeln('--- session ${DateTime.now().toIso8601String()} ---');
    } catch (_) {
      // Файловый лог необязателен
    } finally {
      if (!_init.isCompleted) _init.complete();
    }
  }

  @override
  void write(LogEntry entry) {
    if (!entry.level.satisfies(minimumLevel)) return;
    final sink = _sink;
    if (sink == null) return;
    sink.writeln(entry.line);
  }

  @override
  Future<void> dispose() async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
  }
}
