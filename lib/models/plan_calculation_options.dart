import 'package:youtrack_timer/models/meetup_settings.dart';
import 'package:youtrack_timer/models/time_estimate.dart';
import 'package:youtrack_timer/services/user_hint_meetup_parser.dart';
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

  /// Митап из UI или распознанный из [userHint] (`МИТАП 1Ч KIOSK-114`).
  /// UI имеет приоритет, если уже настроен.
  MeetupSettings get effectiveMeetup {
    if (meetup.isConfigured) return meetup;
    return UserHintMeetupParser.parse(trimmedHint) ?? meetup;
  }

  /// Копия с [effectiveMeetup] в поле [meetup] — для allocator/AI/finalize.
  PlanCalculationOptions resolveMeetupFromHint() {
    if (meetup.isConfigured) return this;
    final parsed = UserHintMeetupParser.parse(trimmedHint);
    if (parsed == null || !parsed.isConfigured) return this;
    return copyWith(meetup: parsed);
  }

  /// idReadable задач, которые нельзя схлопывать до 1–3 дней.
  Set<String> get protectedDailyIssueIds {
    final ids = <String>{};
    final m = effectiveMeetup;
    if (m.isConfigured) {
      ids.add(m.issueIdReadable.trim().toUpperCase());
    }
    return ids;
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
