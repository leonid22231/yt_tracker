import 'package:youtrack_timer/models/issue.dart';
import 'package:youtrack_timer/models/issue_context.dart';
import 'package:youtrack_timer/models/meetup_settings.dart';
import 'package:youtrack_timer/models/plan_calculation_options.dart';
import 'package:youtrack_timer/models/time_estimate.dart';
import 'package:youtrack_timer/utils/date_utils.dart';

/// Выравнивает митап: [MeetupSettings.minutesPerDay] — целевой итог в день
/// (уже списанное в YouTrack + новый план). Дубли не добавляются.
class MeetupAllocator {
  static List<PlannedEntry> apply({
    required List<PlannedEntry> entries,
    required MeetupSettings meetup,
    required PlanCalculationOptions options,
    required DateTime periodStart,
    required DateTime periodEnd,
    required List<YouTrackIssue> issues,
    List<IssueContext> existingContexts = const [],
  }) {
    if (!meetup.isConfigured) return entries;

    final issue = issues.cast<YouTrackIssue?>().firstWhere(
          (i) =>
              i!.idReadable.toUpperCase() ==
              meetup.issueIdReadable.trim().toUpperCase(),
          orElse: () => null,
        );
    if (issue == null) return entries;

    final rangeStart = DateUtils.dateOnly(meetup.startDate ?? periodStart);
    final rangeEnd = DateUtils.dateOnly(meetup.endDate ?? periodEnd);
    final workingDays = options.workingDays(periodStart, periodEnd);

    final result = List<PlannedEntry>.from(entries);
    for (final day in workingDays) {
      final dayOnly = DateUtils.dateOnly(day);
      if (dayOnly.isBefore(rangeStart) || dayOnly.isAfter(rangeEnd)) continue;

      final existing = _existingMinutesOnDay(
        existingContexts,
        issue.id,
        day,
      );
      final additional = additionalMeetupMinutes(
        targetPerDay: meetup.minutesPerDay,
        existingOnDay: existing,
      );

      result.removeWhere(
        (e) => e.issue.id == issue.id && DateUtils.isSameDay(e.date, day),
      );

      if (additional > 0) {
        result.add(
          PlannedEntry(
            issue: issue,
            date: day,
            minutes: additional,
            reasoning: existing > 0
                ? 'Митап (в YT $existing мин, дополнить до ${meetup.minutesPerDay})'
                : 'Митап',
            source: PlanSource.manual,
          ),
        );
      }
    }
    return result;
  }

  /// Дополнительные минуты к уже списанному в YouTrack.
  static int additionalMeetupMinutes({
    required int targetPerDay,
    required int existingOnDay,
  }) {
    if (targetPerDay <= 0) return 0;
    return (targetPerDay - existingOnDay).clamp(0, targetPerDay);
  }

  static int _existingMinutesOnDay(
    List<IssueContext> contexts,
    String issueId,
    DateTime day,
  ) {
    var total = 0;
    for (final ctx in contexts) {
      if (ctx.issue.id != issueId) continue;
      for (final w in ctx.existingWorkItems) {
        if (DateUtils.isSameDay(w.date, day)) total += w.minutes;
      }
    }
    return total;
  }
}
