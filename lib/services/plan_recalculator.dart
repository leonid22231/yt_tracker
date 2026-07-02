import 'package:youtrack_timer/models/issue.dart';
import 'package:youtrack_timer/models/issue_context.dart';
import 'package:youtrack_timer/services/meetup_allocator.dart';
import 'package:youtrack_timer/models/meetup_settings.dart';
import 'package:youtrack_timer/models/plan_calculation_options.dart';
import 'package:youtrack_timer/models/time_estimate.dart';
import 'package:youtrack_timer/utils/date_utils.dart';

/// Пересчёт плана: ручные часы на задачу + остаток дня другим задачам.
class PlanRecalculator {
  PlanRecalculator({this.minutesPerWorkDay = 480});

  final int minutesPerWorkDay;

  /// [issueTotalMinutes] — всего минут на задачу за период (ключ: issue.id).
  /// [weightEntries] — предыдущий план (AI/равный) для пропорций остальных задач.
  List<PlannedEntry> recalculate({
    required List<YouTrackIssue> issues,
    required DateTime periodStart,
    required DateTime periodEnd,
    required List<PlannedEntry> weightEntries,
    required Map<String, int> issueTotalMinutes,
    PlanCalculationOptions options = const PlanCalculationOptions(),
    MeetupSettings meetup = const MeetupSettings(),
    List<IssueContext> existingContexts = const [],
  }) {
    final workingDays = options.workingDays(periodStart, periodEnd);
    if (workingDays.isEmpty || issues.isEmpty) return [];

    final existingByDay = _existingMinutesByDay(existingContexts);

    final weights = _buildDayWeights(weightEntries);
    final result = <PlannedEntry>[];
    final meetupIssueId = meetup.isConfigured
        ? issues
            .cast<YouTrackIssue?>()
            .firstWhere(
              (i) =>
                  i!.idReadable.toUpperCase() ==
                  meetup.issueIdReadable.trim().toUpperCase(),
              orElse: () => null,
            )
            ?.id
        : null;
    final meetupRangeStart =
        DateUtils.dateOnly(meetup.startDate ?? periodStart);
    final meetupRangeEnd = DateUtils.dateOnly(meetup.endDate ?? periodEnd);

    for (final day in workingDays) {
      final active =
          issues.where((i) => _isActiveOnDay(i, day, periodStart, periodEnd)).toList();
      if (active.isEmpty) continue;

      final dayKey = DateUtils.formatForQuery(day);
      final existingOnDay = existingByDay[dayKey] ?? 0;

      final fixedOnDay = <String, int>{};
      var usedOnDay = 0;

      // 0. Митап — только дополнение до целевого итога (с учётом YT)
      if (meetup.isConfigured && meetupIssueId != null) {
        final dayOnly = DateUtils.dateOnly(day);
        if (!dayOnly.isBefore(meetupRangeStart) &&
            !dayOnly.isAfter(meetupRangeEnd)) {
          final additionalMeetup = MeetupAllocator.additionalMeetupMinutes(
            targetPerDay: meetup.minutesPerDay,
            existingOnDay: _existingMinutesOnDay(
              existingContexts,
              meetupIssueId,
              day,
            ),
          );
          if (additionalMeetup > 0) {
            fixedOnDay[meetupIssueId] = additionalMeetup;
            usedOnDay += additionalMeetup;
          }
        }
      }

      // 1. Задачи с ручным лимитом — доля на этот день
      for (final issue in active) {
        final total = issueTotalMinutes[issue.id];
        if (total == null || total <= 0) continue;

        final activeDaysCount = _countActiveDays(issue, periodStart, periodEnd, workingDays);
        if (activeDaysCount == 0) continue;

        final perDay = _splitMinutes(total, activeDaysCount);
        final dayIndex = _activeDayIndex(issue, day, periodStart, periodEnd, workingDays);
        if (dayIndex < 0 || dayIndex >= perDay.length) continue;

        final minutes = perDay[dayIndex];
        fixedOnDay[issue.id] = (fixedOnDay[issue.id] ?? 0) + minutes;
        usedOnDay += minutes;

        if (issue.id != meetupIssueId) {
          result.add(
            PlannedEntry(
              issue: issue,
              date: day,
              minutes: minutes,
              reasoning: 'Задано $total мин за период',
              source: PlanSource.manual,
            ),
          );
        }
      }

      // Записи митапа
      if (meetupIssueId != null && (fixedOnDay[meetupIssueId] ?? 0) > 0) {
        final meetupIssue =
            issues.firstWhere((i) => i.id == meetupIssueId);
        result.add(
          PlannedEntry(
            issue: meetupIssue,
            date: day,
            minutes: fixedOnDay[meetupIssueId]!,
            reasoning: 'Митап',
            source: PlanSource.manual,
          ),
        );
      }

      // 2. Остаток дня — задачи без ручного лимита и без митапа
      final flexible = active
          .where(
            (i) =>
                !issueTotalMinutes.containsKey(i.id) && i.id != meetupIssueId,
          )
          .toList();
      if (flexible.isEmpty) continue;

      var remaining = minutesPerWorkDay - existingOnDay - usedOnDay;
      if (remaining <= 0) {
        // День переполнен ручными лимитами — гибкие задачи получают 0
        continue;
      }

      final weightDayKey = DateTime(day.year, day.month, day.day);
      final weightSum = flexible.fold<int>(
        0,
        (s, i) => s + (weights[i.id]?[weightDayKey] ?? 1),
      );

      var allocated = 0;
      for (var i = 0; i < flexible.length; i++) {
        final issue = flexible[i];
        final w = weights[issue.id]?[weightDayKey] ?? 1;
        int minutes;
        if (i == flexible.length - 1) {
          minutes = remaining - allocated;
        } else {
          minutes = weightSum > 0
              ? (remaining * w / weightSum).round()
              : remaining ~/ flexible.length;
          allocated += minutes;
        }
        if (minutes <= 0) continue;

        result.add(
          PlannedEntry(
            issue: issue,
            date: day,
            minutes: minutes,
            source: PlanSource.ai,
          ),
        );
      }
    }

    return result;
  }

  Map<String, Map<DateTime, int>> _buildDayWeights(List<PlannedEntry> entries) {
    final map = <String, Map<DateTime, int>>{};
    for (final e in entries) {
      final day = DateTime(e.date.year, e.date.month, e.date.day);
      map.putIfAbsent(e.issue.id, () => {});
      map[e.issue.id]![day] = (map[e.issue.id]![day] ?? 0) + e.minutes;
    }
    return map;
  }

  int _countActiveDays(
    YouTrackIssue issue,
    DateTime periodStart,
    DateTime periodEnd,
    List<DateTime> workingDays,
  ) =>
      workingDays
          .where((d) => _isActiveOnDay(issue, d, periodStart, periodEnd))
          .length;

  int _activeDayIndex(
    YouTrackIssue issue,
    DateTime day,
    DateTime periodStart,
    DateTime periodEnd,
    List<DateTime> workingDays,
  ) {
    var idx = 0;
    for (final d in workingDays) {
      if (!_isActiveOnDay(issue, d, periodStart, periodEnd)) continue;
      if (DateUtils.isSameDay(d, day)) return idx;
      idx++;
    }
    return -1;
  }

  bool _isActiveOnDay(
    YouTrackIssue issue,
    DateTime day,
    DateTime periodStart,
    DateTime periodEnd,
  ) {
    if (issue.isDaily) return true;
    final issueStart = DateTime(issue.created.year, issue.created.month, issue.created.day);
    final effectiveStart =
        issueStart.isBefore(periodStart) ? periodStart : issueStart;
    final dayOnly = DateTime(day.year, day.month, day.day);
    return !dayOnly.isBefore(effectiveStart) && !dayOnly.isAfter(periodEnd);
  }

  Map<String, int> _existingMinutesByDay(List<IssueContext> contexts) {
    final map = <String, int>{};
    for (final ctx in contexts) {
      for (final w in ctx.existingWorkItems) {
        final key = DateUtils.formatForQuery(w.date);
        map[key] = (map[key] ?? 0) + w.minutes;
      }
    }
    return map;
  }

  int _existingMinutesOnDay(
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

  List<int> _splitMinutes(int total, int count) {
    if (count <= 0) return [];
    final base = total ~/ count;
    var remainder = total % count;
    return List<int>.generate(count, (_) {
      if (remainder > 0) {
        remainder--;
        return base + 1;
      }
      return base;
    });
  }
}
