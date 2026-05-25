import 'package:test/test.dart';
import 'package:youtrack_timer/youtrack/issue_assignee_parser.dart';

void main() {
  test('читает assignee из customFields', () {
    final parsed = IssueAssigneeParser.parse({
      'customFields': [
        {
          'name': 'Assignee',
          'value': {'id': '1-2', 'login': 'ivan', 'name': 'Ivan'},
        },
      ],
    });

    expect(parsed.login, 'ivan');
    expect(parsed.id, '1-2');
  });
}
