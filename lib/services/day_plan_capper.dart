import 'package:youtrack_timer/models/issue_context.dart';
import 'package:youtrack_timer/models/plan_calculation_options.dart';
import 'package:youtrack_timer/models/time_estimate.dart';
import 'package:youtrack_timer/utils/date_utils.dart';

/// Гарантирует: existing (YT) + planned <= [minutesPerDay] на каждый день.
class DayPlanCapper {
  static List<PlannedEntry> cap({
    required List<PlannedEntry> entries,
    required List<IssueContext> existingContexts,
    required int minutesPerDay,
    required PlanCalculationOptions options,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    final existingByDay = <String, int>{};
    for (final ctx in existingContexts) {
      for (final w in ctx.existingWorkItems) {
        final key = DateUtils.formatForQuery(w.date);
        existingByDay[key] = (existingByDay[key] ?? 0) + w.minutes;
      }
    }

    final result = List<PlannedEntry>.from(entries);
    final workingDays = options.workingDays(periodStart, periodEnd);

    for (final day in workingDays) {
      final key = DateUtils.formatForQuery(day);
      final existing = existingByDay[key] ?? 0;
      final allowedPlanned = minutesPerDay - existing;

      final dayEntries = result
          .where((e) => DateUtils.isSameDay(e.date, day))
          .toList();
      result.removeWhere((e) => DateUtils.isSameDay(e.date, day));

      if (dayEntries.isEmpty) continue;
      if (allowedPlanned <= 0) continue;

      final plannedTotal =
          dayEntries.fold<int>(0, (s, e) => s + e.minutes);
      if (plannedTotal <= allowedPlanned) {
        result.addAll(dayEntries);
        continue;
      }

      var allocated = 0;
      for (var i = 0; i < dayEntries.length; i++) {
        final entry = dayEntries[i];
        int minutes;
        if (i == dayEntries.length - 1) {
          minutes = allowedPlanned - allocated;
        } else {
          minutes = (entry.minutes * allowedPlanned / plannedTotal).round();
          allocated += minutes;
        }
        if (minutes > 0) {
          result.add(
            PlannedEntry(
              issue: entry.issue,
              date: entry.date,
              minutes: minutes,
              reasoning: entry.reasoning,
              comment: entry.comment,
              source: entry.source,
            ),
          );
        }
      }
    }

    return result;
  }
}
