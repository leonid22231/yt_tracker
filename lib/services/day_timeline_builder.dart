import 'package:youtrack_timer/models/day_timeline.dart';
import 'package:youtrack_timer/models/issue_context.dart';
import 'package:youtrack_timer/models/time_estimate.dart';
import 'package:youtrack_timer/utils/date_utils.dart';

/// Собирает посуточную картину: уже в YouTrack + новый план.
class DayTimelineBuilder {
  static List<DayTimeline> build({
    required List<IssueContext> contexts,
    required List<PlannedEntry> plannedEntries,
    required DateTime periodStart,
    required DateTime periodEnd,
    required int targetMinutesPerDay,
    Set<DateTime> excludedDates = const {},
  }) {
    final workingDays = DateUtils.activeWorkingDays(
      periodStart,
      periodEnd,
      excludedDates: excludedDates,
    );
    final byDay = <DateTime, List<DayTaskLine>>{
      for (final d in workingDays) d: [],
    };

    for (final ctx in contexts) {
      for (final w in ctx.existingWorkItems) {
        if (w.minutes <= 0) continue;
        final day = DateTime(w.date.year, w.date.month, w.date.day);
        final dayKey = _matchWorkingDay(workingDays, day);
        if (dayKey == null) continue;
        byDay[dayKey]!.add(
          DayTaskLine(
            issueIdReadable: ctx.issue.idReadable,
            summary: ctx.issue.summary,
            minutes: w.minutes,
            kind: DayLineKind.existing,
            note: w.text,
          ),
        );
      }
    }

    for (final e in plannedEntries) {
      if (e.minutes <= 0) continue;
      final day = DateTime(e.date.year, e.date.month, e.date.day);
      final dayKey = _matchWorkingDay(workingDays, day);
      if (dayKey == null) continue;
      byDay[dayKey]!.add(
        DayTaskLine(
          issueIdReadable: e.issue.idReadable,
          summary: e.issue.summary,
          minutes: e.minutes,
          kind: DayLineKind.planned,
          note: e.reasoning ?? e.comment,
        ),
      );
    }

    return workingDays.map((day) {
      final lines = byDay[day]!
        ..sort((a, b) {
          final kindOrder = a.kind.index.compareTo(b.kind.index);
          if (kindOrder != 0) return kindOrder;
          return a.issueIdReadable.compareTo(b.issueIdReadable);
        });
      return DayTimeline(
        day: day,
        lines: lines,
        targetMinutes: targetMinutesPerDay,
      );
    }).toList();
  }

  static DateTime? _matchWorkingDay(List<DateTime> workingDays, DateTime day) {
    for (final d in workingDays) {
      if (DateUtils.isSameDay(d, day)) return d;
    }
    return null;
  }
}
