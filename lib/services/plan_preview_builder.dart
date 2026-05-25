import 'package:youtrack_timer/models/day_timeline.dart';
import 'package:youtrack_timer/models/plan_preview_entry.dart';
import 'package:youtrack_timer/models/time_estimate.dart';
import 'package:youtrack_timer/services/plan_builder_service.dart';
import 'package:youtrack_timer/utils/date_utils.dart';

/// Собирает данные календаря «как в YouTrack» для экрана проверки.
class PlanPreviewBuilder {
  static List<PlanPreviewDay> buildDays({
    required PlanBuildResult plan,
    required List<PlannedEntry> entriesToCheck,
    Map<String, PreviewWriteStatus>? plannedStatusByKey,
  }) {
    final status = plannedStatusByKey ?? {};
    final plannedByDayIssue = <String, PlannedEntry>{};

    for (final e in entriesToCheck) {
      final key = _issueDayKey(e.issue.idReadable, e.date);
      plannedByDayIssue[key] = e;
    }

    return plan.dayTimelines.map((timeline) {
      final merged = <String, PlanPreviewRow>{};

      for (final line in timeline.lines) {
        final key = line.issueIdReadable;
        final row = merged.putIfAbsent(
          key,
          () => PlanPreviewRow(
            issueIdReadable: line.issueIdReadable,
            summary: line.summary,
            existingMinutes: 0,
            plannedMinutes: 0,
          ),
        );

        if (line.kind == DayLineKind.existing) {
          merged[key] = PlanPreviewRow(
            issueIdReadable: row.issueIdReadable,
            summary: row.summary,
            existingMinutes: row.existingMinutes + line.minutes,
            plannedMinutes: row.plannedMinutes,
            plannedStatus: row.plannedStatus,
          );
        } else {
          final planKey = _issueDayKey(line.issueIdReadable, timeline.day);
          final planned = plannedByDayIssue[planKey];
          final mins = planned?.minutes ?? line.minutes;
          merged[key] = PlanPreviewRow(
            issueIdReadable: row.issueIdReadable,
            summary: row.summary,
            existingMinutes: row.existingMinutes,
            plannedMinutes: row.plannedMinutes + mins,
            plannedStatus: planned != null
                ? status[planKey] ?? PreviewWriteStatus.pending
                : row.plannedStatus,
          );
        }
      }

      // План без строки в timeline (редко)
      for (final e in entriesToCheck) {
        if (!DateUtils.isSameDay(e.date, timeline.day)) continue;
        if (merged.containsKey(e.issue.idReadable)) continue;
        final planKey = _issueDayKey(e.issue.idReadable, e.date);
        merged[e.issue.idReadable] = PlanPreviewRow(
          issueIdReadable: e.issue.idReadable,
          summary: e.issue.summary,
          existingMinutes: 0,
          plannedMinutes: e.minutes,
          plannedStatus: status[planKey] ?? PreviewWriteStatus.pending,
        );
      }

      final rows = merged.values.toList()
        ..sort((a, b) => a.issueIdReadable.compareTo(b.issueIdReadable));

      return PlanPreviewDay(
        day: timeline.day,
        rows: rows,
        targetMinutes: timeline.targetMinutes,
      );
    }).toList();
  }

  /// Ряды по 5 рабочих дней (пн–пт), как сетка в YouTrack.
  static List<List<PlanPreviewDay?>> buildWeekRows(List<PlanPreviewDay> days) {
    if (days.isEmpty) return [];

    final rows = <List<PlanPreviewDay?>>[];
    var current = List<PlanPreviewDay?>.filled(5, null);
    var usedCols = 0;

    for (final day in days) {
      final col = day.day.weekday - DateTime.monday;
      if (col < 0 || col > 4) continue;

      if (col == 0 && usedCols > 0) {
        rows.add(current);
        current = List<PlanPreviewDay?>.filled(5, null);
        usedCols = 0;
      }

      current[col] = day;
      usedCols++;
    }

    if (usedCols > 0) rows.add(current);
    return rows;
  }

  static String _issueDayKey(String idReadable, DateTime day) =>
      '$idReadable|${DateUtils.formatForQuery(day)}';

  static Map<String, PreviewWriteStatus> statusMapFromPreview({
    required List<PlannedEntry> entries,
    required Set<String> skipKeys,
  }) {
    final map = <String, PreviewWriteStatus>{};
    for (final e in entries) {
      final key = _issueDayKey(e.issue.idReadable, e.date);
      map[key] = skipKeys.contains(key)
          ? PreviewWriteStatus.willSkip
          : PreviewWriteStatus.willCreate;
    }
    return map;
  }
}
