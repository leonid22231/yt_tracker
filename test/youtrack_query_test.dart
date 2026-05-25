import 'package:test/test.dart';
import 'package:youtrack_timer/youtrack/youtrack_query.dart';

void main() {
  test('assignedInPeriod не использует started', () {
    final q = YouTrackQuery.assignedInPeriod(
      startDate: DateTime(2024, 1, 1),
      endDate: DateTime(2024, 1, 31),
    );
    expect(q, contains('assignee: me'));
    expect(q, contains('updated: 2024-01-01 .. 2024-01-31'));
    expect(q, isNot(contains('started:')));
  });

  test('workByMeInPeriod находит списанное время', () {
    final q = YouTrackQuery.workByMeInPeriod(
      startDate: DateTime(2024, 1, 1),
      endDate: DateTime(2024, 1, 31),
    );
    expect(q, contains('work author: me'));
    expect(q, contains('work date: 2024-01-01 .. 2024-01-31'));
  });

  test('myWorkTimelineQueries содержит work author', () {
    final queries = YouTrackQuery.myWorkTimelineQueries(
      startDate: DateTime(2024, 1, 1),
      endDate: DateTime(2024, 1, 31),
    );
    expect(queries.first, contains('work author: me'));
    expect(queries.any((q) => q.contains('work author: me')), isTrue);
  });
}
