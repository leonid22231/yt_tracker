import 'package:test/test.dart';
import 'package:youtrack_timer/youtrack/issue_estimate_parser.dart';

void main() {
  group('IssueEstimateParser', () {
    test('находит Estimation и игнорирует Spent time', () {
      final result = IssueEstimateParser.parse([
        {
          r'$type': 'PeriodIssueCustomField',
          'name': 'Spent time',
          'value': {'minutes': 120, 'presentation': '2h'},
        },
        {
          r'$type': 'PeriodIssueCustomField',
          'name': 'Estimation',
          'value': {'minutes': 480, 'presentation': '1d'},
        },
      ]);

      expect(result.minutes, 480);
      expect(result.fieldName, 'Estimation');
      expect(result.presentation, '1d');
    });

    test('распознаёт оценку по имени на русском', () {
      final result = IssueEstimateParser.parse([
        {
          r'$type': 'PeriodIssueCustomField',
          'name': 'Оценка',
          'value': {'minutes': 60},
        },
      ]);

      expect(result.minutes, 60);
      expect(result.fieldName, 'Оценка');
    });

    test('возвращает null без period-полей', () {
      final result = IssueEstimateParser.parse([
        {
          r'$type': 'SingleEnumIssueCustomField',
          'name': 'Priority',
          'value': {'name': 'Major'},
        },
      ]);

      expect(result.minutes, isNull);
    });
  });
}
