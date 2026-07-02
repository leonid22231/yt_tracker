import 'package:test/test.dart';
import 'package:youtrack_timer/models/issue.dart';
import 'package:youtrack_timer/models/issue_context.dart';
import 'package:youtrack_timer/models/meetup_settings.dart';
import 'package:youtrack_timer/models/plan_calculation_options.dart';
import 'package:youtrack_timer/models/time_estimate.dart';
import 'package:youtrack_timer/models/work_item.dart';
import 'package:youtrack_timer/services/day_plan_capper.dart';
import 'package:youtrack_timer/services/meetup_allocator.dart';

YouTrackIssue _issue(String id, String readable) => YouTrackIssue(
      id: id,
      idReadable: readable,
      summary: 'Meetup',
      created: DateTime(2024, 6, 1),
      updated: DateTime(2024, 6, 1),
      isDaily: false,
    );

void main() {
  test('additionalMeetupMinutes не дублирует уже списанное', () {
    expect(
      MeetupAllocator.additionalMeetupMinutes(
        targetPerDay: 60,
        existingOnDay: 60,
      ),
      0,
    );
    expect(
      MeetupAllocator.additionalMeetupMinutes(
        targetPerDay: 60,
        existingOnDay: 30,
      ),
      30,
    );
  });

  test('MeetupAllocator не добавляет план если в YT уже достаточно', () {
    final issue = _issue('1', 'MTG-1');
    final day = DateTime(2024, 6, 10);
    final contexts = [
      IssueContext(
        issue: issue,
        activities: const [],
        existingWorkItems: [
          YouTrackWorkItem(id: 'w1', date: day, minutes: 60, text: ''),
        ],
      ),
    ];

    final result = MeetupAllocator.apply(
      entries: [
        PlannedEntry(
          issue: issue,
          date: day,
          minutes: 60,
          source: PlanSource.ai,
        ),
      ],
      meetup: const MeetupSettings(
        enabled: true,
        issueIdReadable: 'MTG-1',
        minutesPerDay: 60,
      ),
      options: const PlanCalculationOptions(),
      periodStart: DateTime(2024, 6, 10),
      periodEnd: DateTime(2024, 6, 10),
      issues: [issue],
      existingContexts: contexts,
    );

    expect(result.where((e) => e.issue.id == '1'), isEmpty);
  });

  test('DayPlanCapper ограничивает сумму дня', () {
    final issue = _issue('1', 'A-1');
    final day = DateTime(2024, 6, 10);
    final contexts = [
      IssueContext(
        issue: issue,
        activities: const [],
        existingWorkItems: [
          YouTrackWorkItem(id: 'w1', date: day, minutes: 60, text: ''),
        ],
      ),
    ];

    final capped = DayPlanCapper.cap(
      entries: [
        PlannedEntry(issue: issue, date: day, minutes: 480, source: PlanSource.ai),
      ],
      existingContexts: contexts,
      minutesPerDay: 480,
      options: const PlanCalculationOptions(),
      periodStart: day,
      periodEnd: day,
    );

    final plannedTotal = capped.fold<int>(0, (s, e) => s + e.minutes);
    expect(60 + plannedTotal, lessThanOrEqualTo(480));
  });
}
