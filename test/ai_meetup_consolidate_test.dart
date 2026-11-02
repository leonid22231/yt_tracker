import 'package:flutter_test/flutter_test.dart';
import 'package:youtrack_timer/models/issue.dart';
import 'package:youtrack_timer/models/issue_context.dart';
import 'package:youtrack_timer/models/plan_calculation_options.dart';
import 'package:youtrack_timer/services/ai_time_estimator.dart';

void main() {
  test('митап из hint не схлопывается до 3 дней', () {
    final days = [
      for (var d = 1; d <= 10; d++) DateTime(2026, 10, d),
    ].where((d) => d.weekday <= 5).toList();

    final estimates = <Map<String, Object>>[];
    for (final d in days) {
      final day =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      estimates.add({
        'issueIdReadable': 'KIOSK-114',
        'day': day,
        'minutes': 60,
        'confidence': 0.95,
        'reasoning': 'Митап',
      });
      estimates.add({
        'issueIdReadable': 'KIOSK-999',
        'day': day,
        'minutes': 60,
        'confidence': 0.5,
        'reasoning': 'обычная',
      });
    }

    final buf = StringBuffer('{"summary":"test","estimates":[');
    for (var i = 0; i < estimates.length; i++) {
      final e = estimates[i];
      if (i > 0) buf.write(',');
      buf.write(
        '{"issueIdReadable":"${e['issueIdReadable']}","day":"${e['day']}",'
        '"minutes":${e['minutes']},"confidence":${e['confidence']},'
        '"reasoning":"${e['reasoning']}"}',
      );
    }
    buf.write(']}');

    final meetupIssue = YouTrackIssue(
      id: '1',
      idReadable: 'KIOSK-114',
      summary: 'Meetup',
      created: DateTime(2026, 1, 1),
      updated: DateTime(2026, 1, 1),
      isDaily: false,
    );
    final other = YouTrackIssue(
      id: '2',
      idReadable: 'KIOSK-999',
      summary: 'Other',
      created: DateTime(2026, 1, 1),
      updated: DateTime(2026, 1, 1),
      isDaily: false,
    );

    final result = AiTimeEstimator.parseRawResponse(
      raw: buf.toString(),
      periodStart: DateTime(2026, 10, 1),
      periodEnd: DateTime(2026, 10, 10),
      minutesPerWorkDay: 480,
      contexts: [
        IssueContext(
          issue: meetupIssue,
          activities: const [],
          existingWorkItems: const [],
        ),
        IssueContext(
          issue: other,
          activities: const [],
          existingWorkItems: const [],
        ),
      ],
      calculationOptions: const PlanCalculationOptions(
        userHint: 'МИТАП 1Ч KIOSK-114',
      ),
    );

    final meetupDays = result.estimates
        .where((e) => e.issueIdReadable == 'KIOSK-114')
        .map((e) => e.date)
        .toSet();
    final otherDays = result.estimates
        .where((e) => e.issueIdReadable == 'KIOSK-999')
        .map((e) => e.date)
        .toSet();

    expect(meetupDays.length, days.length);
    expect(
      result.estimates
          .where((e) => e.issueIdReadable == 'KIOSK-114')
          .every((e) => e.minutes == 60),
      isTrue,
    );
    expect(otherDays.length, lessThanOrEqualTo(3));
  });
}
