import 'dart:io';

import 'package:args/args.dart';
import 'package:youtrack_timer/config/app_config.dart';
import 'package:youtrack_timer/models/issue.dart';
import 'package:youtrack_timer/youtrack/work_item_comments.dart';
import 'package:youtrack_timer/youtrack/youtrack_client.dart';
import 'package:youtrack_timer/utils/date_utils.dart';

/// Удаляет служебные комментарии приложения из work items в YouTrack.
///
/// По умолчанию только просмотр. Для записи: `--write`.
Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag(
      'write',
      help: 'Реально очистить комментарии в YouTrack (без флага — только список)',
      negatable: false,
    )
    ..addOption(
      'start-date',
      abbr: 's',
      help: 'Начало периода (yyyy-MM-dd), по умолчанию — 1-е число текущего месяца',
    )
    ..addOption(
      'end-date',
      abbr: 'e',
      help: 'Конец периода (yyyy-MM-dd), по умолчанию — сегодня',
    );

  final rest = parser.parse(args);
  final write = rest['write'] as bool;

  final now = DateTime.now();
  final start = rest['start-date'] != null
      ? DateUtils.parseDate(rest['start-date'] as String)
      : DateTime(now.year, now.month, 1);
  final end = rest['end-date'] != null
      ? DateUtils.parseDate(rest['end-date'] as String)
      : now;

  final config = AppConfig.load(
    startDate: start,
    endDate: end,
    dryRun: !write,
  );

  final client = YouTrackClient(config);
  await client.ping();
  final me = await client.currentUser();
  stdout.writeln('Пользователь: ${me.login}');
  stdout.writeln(
    'Период: ${DateUtils.formatForQuery(start)} — ${DateUtils.formatForQuery(end)}',
  );
  stdout.writeln(write ? 'Режим: ЗАПИСЬ' : 'Режим: просмотр (добавьте --write)');
  stdout.writeln('');

  final assignee = await client.fetchAssignedIssues(
    startDate: start,
    endDate: end,
  );
  final extra = await client.fetchMyWorkTimelineIssues(
    startDate: start,
    endDate: end,
    excludeIssueIds: assignee.map((i) => i.id).toSet(),
  );
  final issues = _merge(assignee, extra);
  stdout.writeln('Задач для проверки: ${issues.length}');
  stdout.writeln('');

  final startDay = DateUtils.dateOnly(start);
  final endDay = DateUtils.dateOnly(end);

  var found = 0;
  var cleared = 0;
  var errors = 0;

  for (final issue in issues) {
    final items = await client.fetchWorkItems(issue.id, onlyMine: true);
    final inPeriod = items.where((w) {
      final d = DateUtils.dateOnly(w.date);
      return !d.isBefore(startDay) &&
          !d.isAfter(endDay) &&
          WorkItemComments.isAppMarker(w.text);
    }).toList();

    if (inPeriod.isEmpty) continue;

    for (final w in inPeriod) {
      found++;
      final line =
          '${issue.idReadable} ${DateUtils.formatForQuery(w.date)} '
          '${w.minutes}м  «${w.text}»';
      if (!write) {
        stdout.writeln('[найдено] $line');
        continue;
      }

      try {
        await client.clearWorkItemText(
          issueId: issue.id,
          workItemId: w.id,
          allowWrite: true,
        );
        cleared++;
        stdout.writeln('[очищено] $line');
      } catch (e) {
        errors++;
        stderr.writeln('[ошибка] $line — $e');
      }
    }
  }

  stdout.writeln('');
  stdout.writeln(
    write
        ? 'Готово: найдено $found, очищено $cleared, ошибок $errors'
        : 'Найдено $found записей с комментарием приложения. '
            'Запустите с --write для удаления.',
  );

  client.close();
}

List<YouTrackIssue> _merge(List<YouTrackIssue> a, List<YouTrackIssue> b) {
  final map = {for (final i in a) i.id: i};
  for (final i in b) {
    map[i.id] = i;
  }
  return map.values.toList();
}
