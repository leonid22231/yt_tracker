import 'package:youtrack_timer/models/issue.dart';
import 'package:youtrack_timer/models/issue_context.dart';
import 'package:youtrack_timer/models/time_estimate.dart';
import 'package:youtrack_timer/utils/date_utils.dart';

/// Добивает рабочие дни до [minutesPerDay] любыми подходящими задачами плана.
///
/// Не только daily и не только задачи с активностью в этот день —
/// подходит любая задача, созданная не позже этого дня.
class DayGapFiller {
  static const _chunkMinutes = 30;

  static List<PlannedEntry> fill({
    required List<PlannedEntry> entries,
    required List<YouTrackIssue> pool,
    required DateTime periodStart,
    required DateTime periodEnd,
    required List<IssueContext> existingContexts,
    required int minutesPerDay,
  }) {
    if (pool.isEmpty) return entries;

    final existingByDay = <String, int>{};
    for (final ctx in existingContexts) {
      for (final w in ctx.existingWorkItems) {
        final key = DateUtils.formatForQuery(w.date);
        existingByDay[key] = (existingByDay[key] ?? 0) + w.minutes;
      }
    }

    final result = List<PlannedEntry>.from(entries);
    final workingDays = DateUtils.workingDays(periodStart, periodEnd);

    for (final day in workingDays) {
      final key = DateUtils.formatForQuery(day);
      final existing = existingByDay[key] ?? 0;
      final plannedTotal = result
          .where((e) => DateUtils.isSameDay(e.date, day))
          .fold<int>(0, (s, e) => s + e.minutes);
      var gap = minutesPerDay - existing - plannedTotal;
      if (gap <= 0) continue;

      final candidates = _candidatesForDay(pool, day);
      if (candidates.isEmpty) continue;

      var round = 0;
      while (gap > 0 && round < 200) {
        round++;
        var placed = false;
        for (final issue in candidates) {
          if (gap <= 0) break;
          final add = gap >= _chunkMinutes ? _chunkMinutes : gap;
          _addMinutes(result, issue, day, add);
          gap -= add;
          placed = true;
        }
        if (!placed) break;
      }
    }

    return result;
  }

  static List<YouTrackIssue> _candidatesForDay(
    List<YouTrackIssue> pool,
    DateTime day,
  ) {
    final dayOnly = DateUtils.dateOnly(day);
    final eligible = pool
        .where((i) => !DateUtils.dateOnly(i.created).isAfter(dayOnly))
        .toList();

    eligible.sort((a, b) {
      if (a.isDaily != b.isDaily) return a.isDaily ? -1 : 1;
      final byUpdated = b.updated.compareTo(a.updated);
      if (byUpdated != 0) return byUpdated;
      return b.created.compareTo(a.created);
    });

    return eligible;
  }

  static void _addMinutes(
    List<PlannedEntry> result,
    YouTrackIssue issue,
    DateTime day,
    int minutes,
  ) {
    if (minutes <= 0) return;

    for (var i = 0; i < result.length; i++) {
      final e = result[i];
      if (e.issue.id == issue.id && DateUtils.isSameDay(e.date, day)) {
        result[i] = PlannedEntry(
          issue: issue,
          date: day,
          minutes: e.minutes + minutes,
          reasoning: e.reasoning,
          source: PlanSource.manual,
        );
        return;
      }
    }

    result.add(
      PlannedEntry(
        issue: issue,
        date: day,
        minutes: minutes,
        reasoning: 'Добивка дня до нормы',
        source: PlanSource.manual,
      ),
    );
  }
}
