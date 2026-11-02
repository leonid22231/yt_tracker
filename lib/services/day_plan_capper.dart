import 'package:youtrack_timer/models/issue_context.dart';
import 'package:youtrack_timer/models/plan_calculation_options.dart';
import 'package:youtrack_timer/models/time_estimate.dart';
import 'package:youtrack_timer/utils/date_utils.dart';

/// Гарантирует: existing (YT) + planned <= [minutesPerDay] на каждый день.
/// Митап / protected ужимаются в последнюю очередь.
class DayPlanCapper {
  static List<PlannedEntry> cap({
    required List<PlannedEntry> entries,
    required List<IssueContext> existingContexts,
    required int minutesPerDay,
    required PlanCalculationOptions options,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    final resolved = options.resolveMeetupFromHint();
    final protectedIds = resolved.protectedDailyIssueIds;

    final existingByDay = <String, int>{};
    for (final ctx in existingContexts) {
      for (final w in ctx.existingWorkItems) {
        final key = DateUtils.formatForQuery(w.date);
        existingByDay[key] = (existingByDay[key] ?? 0) + w.minutes;
      }
    }

    final result = List<PlannedEntry>.from(entries);
    final workingDays = resolved.workingDays(periodStart, periodEnd);

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

      final fixed = <PlannedEntry>[];
      final flexible = <PlannedEntry>[];
      for (final entry in dayEntries) {
        if (protectedIds.contains(entry.issue.idReadable.toUpperCase())) {
          fixed.add(entry);
        } else {
          flexible.add(entry);
        }
      }

      final fixedTotal = fixed.fold<int>(0, (s, e) => s + e.minutes);
      if (fixedTotal >= allowedPlanned) {
        result.addAll(_scaleEntries(fixed, allowedPlanned));
        continue;
      }

      result.addAll(fixed);
      final flexibleBudget = allowedPlanned - fixedTotal;
      if (flexible.isNotEmpty && flexibleBudget > 0) {
        result.addAll(_scaleEntries(flexible, flexibleBudget));
      }
    }

    return result;
  }

  static List<PlannedEntry> _scaleEntries(
    List<PlannedEntry> group,
    int target,
  ) {
    if (group.isEmpty || target <= 0) return const [];
    final total = group.fold<int>(0, (s, e) => s + e.minutes);
    if (total == 0) return const [];

    final out = <PlannedEntry>[];
    var allocated = 0;
    for (var i = 0; i < group.length; i++) {
      final entry = group[i];
      final minutes = i == group.length - 1
          ? target - allocated
          : (entry.minutes * target / total).round();
      allocated += minutes;
      if (minutes > 0) {
        out.add(
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
    return out;
  }
}
