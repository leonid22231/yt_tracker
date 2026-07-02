import 'package:youtrack_timer/models/issue.dart';
import 'package:youtrack_timer/models/plan_calculation_options.dart';
import 'package:youtrack_timer/models/work_item.dart';

/// Распределяет рабочее время по задачам на каждый день.
class TimeDistributor {
  static const int defaultMinutesPerWorkDay = 480;

  TimeDistributor({this.minutesPerWorkDay = defaultMinutesPerWorkDay});

  final int minutesPerWorkDay;

  /// Строит план записей времени на все рабочие дни периода.
  List<PlannedWorkItem> buildPlan({
    required List<YouTrackIssue> issues,
    required DateTime periodStart,
    required DateTime periodEnd,
    PlanCalculationOptions options = const PlanCalculationOptions(),
  }) {
    final workingDays = options.workingDays(periodStart, periodEnd);
    if (workingDays.isEmpty || issues.isEmpty) {
      return [];
    }

    final plan = <PlannedWorkItem>[];

    for (final day in workingDays) {
      final activeIssues = issues
          .where((issue) => _isActiveOnDay(issue, day, periodStart, periodEnd))
          .toList();

      if (activeIssues.isEmpty) continue;

      final allocations = _splitMinutes(minutesPerWorkDay, activeIssues.length);

      for (var i = 0; i < activeIssues.length; i++) {
        final minutes = allocations[i];
        if (minutes <= 0) continue;

        plan.add(
          PlannedWorkItem(
            issue: activeIssues[i],
            date: day,
            minutes: minutes,
          ),
        );
      }
    }

    return plan;
  }

  /// Проверяет, активна ли задача в указанный рабочий день.
  bool _isActiveOnDay(
    YouTrackIssue issue,
    DateTime day,
    DateTime periodStart,
    DateTime periodEnd,
  ) {
    if (issue.isDaily) {
      return true;
    }

    final issueStart = _dateOnly(issue.created);
    final effectiveStart =
        issueStart.isBefore(periodStart) ? periodStart : issueStart;
    final effectiveEnd = periodEnd;

    final dayOnly = _dateOnly(day);
    return !dayOnly.isBefore(effectiveStart) && !dayOnly.isAfter(effectiveEnd);
  }

  /// Делит [totalMinutes] на [count] частей; остаток отдаёт первым задачам.
  List<int> _splitMinutes(int totalMinutes, int count) {
    if (count <= 0) return [];
    final base = totalMinutes ~/ count;
    var remainder = totalMinutes % count;
    return List<int>.generate(count, (_) {
      if (remainder > 0) {
        remainder--;
        return base + 1;
      }
      return base;
    });
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Сводка по дням: сколько минут запланировано на каждую дату.
  Map<DateTime, int> summarizeByDay(List<PlannedWorkItem> plan) {
    final summary = <DateTime, int>{};
    for (final item in plan) {
      final key = _dateOnly(item.date);
      summary[key] = (summary[key] ?? 0) + item.minutes;
    }
    return summary;
  }
}
