import 'package:youtrack_timer/config/app_config.dart';
import 'package:youtrack_timer/models/work_item.dart';
import 'package:youtrack_timer/services/time_distributor.dart';
import 'package:youtrack_timer/utils/date_utils.dart';
import 'package:youtrack_timer/logging/app_log.dart';
import 'package:youtrack_timer/youtrack/youtrack_client.dart';

/// Оркестратор: загрузка задач, планирование и запись work items.
class TimerService {
  TimerService({
    required AppConfig config,
    required YouTrackClient client,
    AppLogger? logger,
    TimeDistributor? distributor,
  })  : _config = config,
        _client = client,
        _logger = logger ?? AppLogger(category: LogCategory.plan),
        _distributor = distributor ?? TimeDistributor();

  final AppConfig _config;
  final YouTrackClient _client;
  final AppLogger _logger;
  final TimeDistributor _distributor;

  /// Выполняет полный цикл автозаполнения времени.
  Future<TimerRunResult> run() async {
    _logger.info(
      'Период: ${DateUtils.formatForQuery(_config.startDate)}'
      ' — ${DateUtils.formatForQuery(_config.endDate)}',
    );
    _logger.info('YouTrack: ${_config.baseUrl}');
    if (_config.dryRun) {
      _logger.warn('Режим dry-run: записи в API не выполняются');
    }

    final issues = await _client.fetchAssignedIssues(
      startDate: _config.startDate,
      endDate: _config.endDate,
    );

    _logger.info('Найдено задач: ${issues.length}');
    final dailyCount = issues.where((i) => i.isDaily).length;
    final regularCount = issues.length - dailyCount;
    _logger.info('  — ежедневных (daily): $dailyCount');
    _logger.info('  — обычных: $regularCount');

    for (final issue in issues) {
      final kind = issue.isDaily ? 'daily' : 'обычная';
      _logger.info('  • ${issue.idReadable} [$kind] ${issue.summary}');
    }

    if (issues.isEmpty) {
      _logger.warn('Нет задач для распределения времени.');
      return TimerRunResult.empty();
    }

    final plan = _distributor.buildPlan(
      issues: issues,
      periodStart: _config.startDate,
      periodEnd: _config.endDate,
    );

    final daySummary = _distributor.summarizeByDay(plan);
    _logger.info('Рабочих дней в плане: ${daySummary.length}');

    var created = 0;
    var skipped = 0;
    var failed = 0;

    // Кэш существующих work items по issue.id
    final existingCache = <String, List<YouTrackWorkItem>>{};

    for (final planned in plan) {
      final issueId = planned.issue.id;
      if (!existingCache.containsKey(issueId)) {
        existingCache[issueId] = await _client.fetchWorkItems(issueId);
      }
      final existing = existingCache[issueId]!;

      final alreadyExists = existing.any(
        (w) => DateUtils.isSameDay(w.date, planned.date),
      );

      if (alreadyExists) {
        skipped++;
        _logger.warn(
          'Пропуск (уже есть запись): ${planned.issue.idReadable}'
          ' на ${DateUtils.formatForQuery(planned.date)}',
        );
        continue;
      }

      if (_config.dryRun) {
        created++;
        _logger.info(
          '[dry-run] ${planned.issue.idReadable}'
          ' ${DateUtils.formatForQuery(planned.date)}'
          ' — ${planned.minutes} мин',
        );
        continue;
      }

      try {
        await _client.createWorkItem(
          issueId: issueId,
          minutes: planned.minutes,
          date: planned.date,
          comment: planned.comment,
          allowWrite: !_config.dryRun,
        );
        created++;
        _logger.success(
          'Записано: ${planned.issue.idReadable}'
          ' ${DateUtils.formatForQuery(planned.date)}'
          ' — ${planned.minutes} мин (${_formatHours(planned.minutes)})',
        );
      } on YouTrackApiException catch (e) {
        failed++;
        _logger.error(e.message);
      }
    }

    _logger.info('--- Итог по дням ---');
    for (final entry in daySummary.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key))) {
      final hours = _formatHours(entry.value);
      final status = entry.value == TimeDistributor.defaultMinutesPerWorkDay
          ? 'OK'
          : 'ВНИМАНИЕ';
      _logger.info(
        '$status ${DateUtils.formatForQuery(entry.key)}: '
        '${entry.value} мин ($hours)',
      );
    }

    _logger.info('--- Сводка ---');
    _logger.info('Создано записей: $created');
    _logger.info('Пропущено (дубликаты): $skipped');
    if (failed > 0) {
      _logger.error('Ошибок: $failed');
    }

    return TimerRunResult(
      issuesCount: issues.length,
      plannedCount: plan.length,
      createdCount: created,
      skippedCount: skipped,
      failedCount: failed,
    );
  }

  String _formatHours(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '$hч';
    return '$hч $mм';
  }
}

/// Результат одного запуска.
class TimerRunResult {
  TimerRunResult({
    required this.issuesCount,
    required this.plannedCount,
    required this.createdCount,
    required this.skippedCount,
    required this.failedCount,
  });

  factory TimerRunResult.empty() => TimerRunResult(
        issuesCount: 0,
        plannedCount: 0,
        createdCount: 0,
        skippedCount: 0,
        failedCount: 0,
      );

  final int issuesCount;
  final int plannedCount;
  final int createdCount;
  final int skippedCount;
  final int failedCount;

  bool get hasErrors => failedCount > 0;
}
