import 'package:youtrack_timer/models/meetup_settings.dart';
import 'package:youtrack_timer/models/time_estimate.dart';
import 'package:youtrack_timer/utils/date_utils.dart';

/// Общие параметры расчёта плана: подсказка, исключённые даты, митап.
class PlanCalculationOptions {
  const PlanCalculationOptions({
    this.userHint = '',
    this.excludedDates = const {},
    this.meetup = const MeetupSettings(),
  });

  final String userHint;
  final Set<DateTime> excludedDates;
  final MeetupSettings meetup;

  String? get trimmedHint {
    final h = userHint.trim();
    return h.isEmpty ? null : h;
  }

  Set<DateTime> get normalizedExcludedDates =>
      excludedDates.map(DateUtils.dateOnly).toSet();

  List<DateTime> workingDays(DateTime start, DateTime end) =>
      DateUtils.activeWorkingDays(
        start,
        end,
        excludedDates: normalizedExcludedDates,
      );

  bool isDayExcluded(DateTime day) =>
      normalizedExcludedDates.contains(DateUtils.dateOnly(day));

  PlanCalculationOptions copyWith({
    String? userHint,
    Set<DateTime>? excludedDates,
    MeetupSettings? meetup,
  }) =>
      PlanCalculationOptions(
        userHint: userHint ?? this.userHint,
        excludedDates: excludedDates ?? this.excludedDates,
        meetup: meetup ?? this.meetup,
      );

  /// Убирает записи на исключённые дни (на случай если AI их проигнорировал).
  List<PlannedEntry> filterExcludedDays(List<PlannedEntry> entries) {
    if (normalizedExcludedDates.isEmpty) return entries;
    return entries
        .where((e) => !isDayExcluded(e.date))
        .toList();
  }
}
