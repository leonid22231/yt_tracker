import 'package:test/test.dart';
import 'package:youtrack_timer/models/issue.dart';
import 'package:youtrack_timer/models/time_estimate.dart';
import 'package:youtrack_timer/services/plan_recalculator.dart';

YouTrackIssue _issue(String id, String readable) => YouTrackIssue(
      id: id,
      idReadable: readable,
      summary: 'Test',
      created: DateTime(2024, 1, 1),
      updated: DateTime(2024, 1, 5),
      isDaily: false,
    );

void main() {
  test('ручной лимит 5ч на задачу перераспределяет остальные', () {
    final a = _issue('1', 'A-1');
    final b = _issue('2', 'B-1');
    final start = DateTime(2024, 1, 1);
    final end = DateTime(2024, 1, 3); // 3 рабочих дня

    final weights = [
      PlannedEntry(issue: a, date: DateTime(2024, 1, 1), minutes: 60),
      PlannedEntry(issue: a, date: DateTime(2024, 1, 2), minutes: 60),
      PlannedEntry(issue: b, date: DateTime(2024, 1, 1), minutes: 420),
      PlannedEntry(issue: b, date: DateTime(2024, 1, 2), minutes: 420),
    ];

    final result = PlanRecalculator(minutesPerWorkDay: 480).recalculate(
      issues: [a, b],
      periodStart: start,
      periodEnd: end,
      weightEntries: weights,
      issueTotalMinutes: {'1': 300}, // 5 часов на A-1
    );

    final aTotal = result.where((e) => e.issue.id == '1').fold(0, (s, e) => s + e.minutes);
    expect(aTotal, 300);

    for (final day in [DateTime(2024, 1, 1), DateTime(2024, 1, 2), DateTime(2024, 1, 3)]) {
      final dayTotal = result
          .where((e) => e.date.year == day.year && e.date.month == day.month && e.date.day == day.day)
          .fold(0, (s, e) => s + e.minutes);
      expect(dayTotal, lessThanOrEqualTo(480));
    }
  });
}
