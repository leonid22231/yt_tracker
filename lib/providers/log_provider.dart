import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtrack_timer/logging/app_log.dart';
import 'package:youtrack_timer/logging/log_entry.dart';
import 'package:youtrack_timer/logging/log_level.dart';

/// Минимальный уровень отображения в UI.
final logMinLevelProvider = StateProvider<LogLevel>((_) => LogLevel.debug);

/// Показывать только выбранную категорию (null = все).
final logCategoryFilterProvider = StateProvider<String?>((_) => null);

/// Все записи журнала (синхронизация с [AppLog]).
final logEntriesProvider =
    StateNotifierProvider<LogEntriesNotifier, List<LogEntry>>(
  (ref) => LogEntriesNotifier(),
);

class LogEntriesNotifier extends StateNotifier<List<LogEntry>> {
  LogEntriesNotifier() : super(AppLog.instance.entries) {
    _subscription = AppLog.instance.stream.listen((entries) {
      state = entries;
    });
  }

  late final StreamSubscription<List<LogEntry>> _subscription;

  void clear() => AppLog.instance.clear();

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Отфильтрованные записи для панели логов.
final visibleLogEntriesProvider = Provider<List<LogEntry>>((ref) {
  final entries = ref.watch(logEntriesProvider);
  final minLevel = ref.watch(logMinLevelProvider);
  final category = ref.watch(logCategoryFilterProvider);

  return entries.where((e) {
    if (!e.level.satisfies(minLevel)) return false;
    if (category != null && e.category != category) return false;
    return true;
  }).toList();
});
