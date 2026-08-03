import 'package:flutter_test/flutter_test.dart';
import 'package:youtrack_timer/models/issue.dart';
import 'package:youtrack_timer/models/issue_context.dart';
import 'package:youtrack_timer/models/plan_calculation_options.dart';
import 'package:youtrack_timer/services/ai_time_estimator.dart';

void main() {
  test('parseRawResponse accepts Cursor JSON with estimates', () {
    const raw = '''
```json
{
  "summary": "Месяц по KIOSK",
  "estimates": [
    {
      "issueIdReadable": "KIOSK-114",
      "day": "2026-07-01",
      "minutes": 240,
      "confidence": 0.9,
      "reasoning": "основная работа"
    },
    {
      "issueIdReadable": "KIOSK-559",
      "day": "2026-07-01",
      "minutes": 240,
      "confidence": 0.8,
      "reasoning": "доработка"
    }
  ]
}
```
''';

    final issue = YouTrackIssue(
      id: '1',
      idReadable: 'KIOSK-114',
      summary: 'Main',
      created: DateTime(2026, 6, 1),
      updated: DateTime(2026, 6, 1),
      isDaily: false,
    );
    final other = YouTrackIssue(
      id: '2',
      idReadable: 'KIOSK-559',
      summary: 'Other',
      created: DateTime(2026, 6, 1),
      updated: DateTime(2026, 6, 1),
      isDaily: false,
    );

    final result = AiTimeEstimator.parseRawResponse(
      raw: raw,
      periodStart: DateTime(2026, 7, 1),
      periodEnd: DateTime(2026, 7, 2),
      minutesPerWorkDay: 480,
      contexts: [
        IssueContext(issue: issue, activities: const [], existingWorkItems: const []),
        IssueContext(issue: other, activities: const [], existingWorkItems: const []),
      ],
      calculationOptions: const PlanCalculationOptions(),
    );

    expect(result.usedAi, isTrue);
    expect(result.summary, 'Месяц по KIOSK');
    expect(result.estimates, isNotEmpty);
    final total = result.estimates
        .where((e) => e.date == DateTime(2026, 7, 1))
        .fold<int>(0, (s, e) => s + e.minutes);
    expect(total, 480);
  });
}
