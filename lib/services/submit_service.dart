import 'package:youtrack_timer/logging/app_log.dart';
import 'package:youtrack_timer/models/time_estimate.dart';
import 'package:youtrack_timer/models/work_item.dart';
import 'package:youtrack_timer/services/submit_guard.dart';
import 'package:youtrack_timer/utils/date_utils.dart';
import 'package:youtrack_timer/youtrack/youtrack_client.dart';

/// Отправка плана в YouTrack с проверкой дубликатов.
class SubmitService {
  SubmitService(this._client);

  final YouTrackClient _client;

  /// Проверка плана: **никогда** не создаёт work items в YouTrack.
  /// Опционально читает существующие записи (только GET).
  Future<SubmitResult> preview({
    required List<PlannedEntry> entries,
    bool checkDuplicates = true,
  }) async {
    SubmitGuard.ensurePreviewOnly(previewMode: true);
    final log = AppLog.instance;
    var wouldCreate = 0;
    var wouldSkip = 0;

    if (entries.isEmpty) {
      log.warn(LogCategory.submit, 'Нет записей в плане');
      return SubmitResult(created: 0, skipped: 0, failed: 0, isPreview: true);
    }

    log.warn(
      LogCategory.submit,
      'РЕЖИМ ПРОВЕРКИ: в YouTrack ничего не записывается',
    );

    final cache = <String, List<YouTrackWorkItem>>{};

    for (final entry in entries) {
      var duplicate = false;

      if (checkDuplicates) {
        final issueId = entry.issue.id;
        if (!cache.containsKey(issueId)) {
          cache[issueId] = await _client.fetchWorkItems(issueId);
        }
        duplicate = cache[issueId]!.any(
          (w) => DateUtils.isSameDay(w.date, entry.date),
        );
      }

      if (duplicate) {
        wouldSkip++;
        log.info(
          LogCategory.submit,
          '[проверка] пропуск ${entry.issue.idReadable} '
          '${DateUtils.formatForQuery(entry.date)} — уже есть в YouTrack',
        );
      } else {
        wouldCreate++;
        log.info(
          LogCategory.submit,
          '[проверка] будет записано: ${entry.issue.idReadable} '
          '${DateUtils.formatForQuery(entry.date)} — ${entry.minutes} мин',
        );
      }
    }

    log.success(
      LogCategory.submit,
      'Проверка: записалось бы $wouldCreate, пропуск $wouldSkip',
    );

    return SubmitResult(
      created: wouldCreate,
      skipped: wouldSkip,
      failed: 0,
      isPreview: true,
    );
  }

  /// Проверка с детализацией: какие записи будут пропущены как дубликаты.
  Future<PreviewDetailResult> previewDetailed({
    required List<PlannedEntry> entries,
  }) async {
    SubmitGuard.ensurePreviewOnly(previewMode: true);
    final log = AppLog.instance;
    var wouldCreate = 0;
    var wouldSkip = 0;
    final skipKeys = <String>{};

    if (entries.isEmpty) {
      return PreviewDetailResult(
        result: SubmitResult(created: 0, skipped: 0, failed: 0, isPreview: true),
        skipKeys: skipKeys,
      );
    }

    final cache = <String, List<YouTrackWorkItem>>{};

    for (final entry in entries) {
      final key =
          '${entry.issue.idReadable}|${DateUtils.formatForQuery(entry.date)}';
      var duplicate = false;

      final issueId = entry.issue.id;
      if (!cache.containsKey(issueId)) {
        cache[issueId] = await _client.fetchWorkItems(issueId);
      }
      duplicate = cache[issueId]!.any(
        (w) => DateUtils.isSameDay(w.date, entry.date),
      );

      if (duplicate) {
        wouldSkip++;
        skipKeys.add(key);
      } else {
        wouldCreate++;
      }
    }

    log.success(
      LogCategory.submit,
      'Проверка: записалось бы $wouldCreate, пропуск $wouldSkip',
    );

    return PreviewDetailResult(
      result: SubmitResult(
        created: wouldCreate,
        skipped: wouldSkip,
        failed: 0,
        isPreview: true,
      ),
      skipKeys: skipKeys,
    );
  }

  /// Реальная запись в YouTrack (только после [SubmitGuard.ensureWriteAllowed]).
  Future<SubmitResult> write({
    required List<PlannedEntry> entries,
    required bool dryRunEnabled,
    required bool userConfirmed,
  }) async {
    SubmitGuard.ensureWriteAllowed(
      dryRunEnabled: dryRunEnabled,
      userConfirmed: userConfirmed,
    );

    final log = AppLog.instance;
    var created = 0;
    var skipped = 0;
    var failed = 0;

    if (entries.isEmpty) {
      log.warn(LogCategory.submit, 'Нет записей для записи');
      return SubmitResult(created: 0, skipped: 0, failed: 0);
    }

    log.warn(
      LogCategory.submit,
      'ЗАПИСЬ В YOUTRACK: ${entries.length} записей',
    );

    final cache = <String, List<YouTrackWorkItem>>{};

    for (final entry in entries) {
      final issueId = entry.issue.id;
      if (!cache.containsKey(issueId)) {
        cache[issueId] = await _client.fetchWorkItems(issueId);
      }
      final existing = cache[issueId]!;

      if (existing.any((w) => DateUtils.isSameDay(w.date, entry.date))) {
        skipped++;
        log.info(
          LogCategory.submit,
          'Пропуск ${entry.issue.idReadable} '
          '${DateUtils.formatForQuery(entry.date)} — дубликат',
        );
        continue;
      }

      try {
        await _client.createWorkItem(
          issueId: issueId,
          minutes: entry.minutes,
          date: entry.date,
          comment: entry.comment,
          allowWrite: true,
        );
        created++;
        log.success(
          LogCategory.submit,
          'Записано: ${entry.issue.idReadable} '
          '${DateUtils.formatForQuery(entry.date)} — ${entry.minutes} мин',
        );
      } catch (e, st) {
        failed++;
        log.error(
          LogCategory.submit,
          '${entry.issue.idReadable} ${DateUtils.formatForQuery(entry.date)}',
          e,
          st,
        );
      }
    }

    return SubmitResult(created: created, skipped: skipped, failed: failed);
  }
}

class SubmitResult {
  SubmitResult({
    required this.created,
    required this.skipped,
    required this.failed,
    this.isPreview = false,
  });

  final int created;
  final int skipped;
  final int failed;

  /// true = это была только проверка, без POST в API.
  final bool isPreview;
}

class PreviewDetailResult {
  PreviewDetailResult({
    required this.result,
    required this.skipKeys,
  });

  final SubmitResult result;
  final Set<String> skipKeys;
}
