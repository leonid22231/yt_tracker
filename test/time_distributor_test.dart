import 'package:test/test.dart';
import 'package:youtrack_timer/models/issue.dart';
import 'package:youtrack_timer/services/time_distributor.dart';
import 'package:youtrack_timer/utils/date_utils.dart';

void main() {
  group('DateUtils.workingDays', () {
    test('исключает субботу и воскресенье', () {
      // 2024-01-01 — понедельник, 2024-01-07 — воскресенье
      final days = DateUtils.workingDays(
        DateTime(2024, 1, 1),
        DateTime(2024, 1, 7),
      );
      expect(days.length, 5);
      expect(days.every((d) => d.weekday <= DateTime.friday), isTrue);
    });
  });

  group('TimeDistributor', () {
    final distributor = TimeDistributor(minutesPerWorkDay: 480);

    YouTrackIssue issue({
      required String id,
      required String readable,
      required String summary,
      required DateTime created,
      bool isDaily = false,
    }) {
      return YouTrackIssue(
        id: id,
        idReadable: readable,
        summary: summary,
        created: created,
        updated: created,
        isDaily: isDaily,
        tags: isDaily ? ['daily'] : [],
      );
    }

    test('каждый рабочий день суммарно 480 минут', () {
      final issues = [
        issue(
          id: '1',
          readable: 'A-1',
          summary: 'Daily standup',
          created: DateTime(2024, 1, 1),
          isDaily: true,
        ),
        issue(
          id: '2',
          readable: 'A-2',
          summary: 'Feature work',
          created: DateTime(2024, 1, 2),
        ),
      ];

      final plan = distributor.buildPlan(
        issues: issues,
        periodStart: DateTime(2024, 1, 1),
        periodEnd: DateTime(2024, 1, 5), // пн–пт
      );

      final summary = distributor.summarizeByDay(plan);
      expect(summary.length, 5);
      for (final total in summary.values) {
        expect(total, 480);
      }
    });

    test('daily задача присутствует каждый рабочий день', () {
      final daily = issue(
        id: '1',
        readable: 'D-1',
        summary: 'daily meeting',
        created: DateTime(2023, 12, 1),
        isDaily: true,
      );

      final plan = distributor.buildPlan(
        issues: [daily],
        periodStart: DateTime(2024, 1, 1),
        periodEnd: DateTime(2024, 1, 3),
      );

      expect(plan.length, 3);
      expect(plan.every((p) => p.issue.isDaily), isTrue);
      expect(plan.every((p) => p.minutes == 480), isTrue);
    });

    test('обычная задача не активна до даты создания', () {
      final regular = issue(
        id: '2',
        readable: 'R-1',
        summary: 'Bugfix',
        created: DateTime(2024, 1, 3), // среда
      );

      final plan = distributor.buildPlan(
        issues: [regular],
        periodStart: DateTime(2024, 1, 1),
        periodEnd: DateTime(2024, 1, 5),
      );

      expect(plan.length, 3); // ср, чт, пт
      expect(
        plan.every((p) => !p.date.isBefore(DateTime(2024, 1, 3))),
        isTrue,
      );
    });
  });
}
