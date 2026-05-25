import 'package:test/test.dart';
import 'package:youtrack_timer/models/day_timeline.dart';
import 'package:youtrack_timer/models/issue.dart';
import 'package:youtrack_timer/models/issue_context.dart';
import 'package:youtrack_timer/models/time_estimate.dart';
import 'package:youtrack_timer/models/work_item.dart';
import 'package:youtrack_timer/services/day_timeline_builder.dart';

void main() {
  test('собирает existing и planned по дням', () {
    final issue = YouTrackIssue(
      id: '1',
      idReadable: 'A-1',
      summary: 'Task A',
      created: DateTime(2024, 1, 1),
      updated: DateTime(2024, 1, 5),
      isDaily: false,
    );

    final contexts = [
      IssueContext(
        issue: issue,
        activities: [],
        existingWorkItems: [
          YouTrackWorkItem(
            id: 'w1',
            date: DateTime(2024, 1, 1),
            minutes: 60,
          ),
        ],
      ),
    ];

    final planned = [
      PlannedEntry(
        issue: issue,
        date: DateTime(2024, 1, 1),
        minutes: 120,
      ),
    ];

    final timelines = DayTimelineBuilder.build(
      contexts: contexts,
      plannedEntries: planned,
      periodStart: DateTime(2024, 1, 1),
      periodEnd: DateTime(2024, 1, 1),
      targetMinutesPerDay: 480,
    );

    expect(timelines.length, 1);
    expect(timelines.first.existingMinutes, 60);
    expect(timelines.first.plannedMinutes, 120);
    expect(timelines.first.totalMinutes, 180);
    expect(
      timelines.first.lines.where((l) => l.kind == DayLineKind.existing).length,
      1,
    );
    expect(
      timelines.first.lines.where((l) => l.kind == DayLineKind.planned).length,
      1,
    );
  });
}
