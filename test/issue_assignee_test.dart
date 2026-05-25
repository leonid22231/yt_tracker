import 'package:test/test.dart';
import 'package:youtrack_timer/models/issue.dart';
import 'package:youtrack_timer/models/youtrack_user.dart';

void main() {
  final me = YouTrackUser(id: '1-1', login: 'ivan');

  YouTrackIssue issue({String? assigneeId, String? assigneeLogin}) =>
      YouTrackIssue(
        id: '2-1',
        idReadable: 'X-1',
        summary: 'Test',
        created: DateTime(2024, 1, 1),
        updated: DateTime(2024, 1, 1),
        isDaily: false,
        assigneeId: assigneeId,
        assigneeLogin: assigneeLogin,
      );

  test('isAssignedTo по login', () {
    expect(issue(assigneeLogin: 'ivan').isAssignedTo(me), isTrue);
    expect(issue(assigneeLogin: 'petr').isAssignedTo(me), isFalse);
  });

  test('без assignee — не на мне', () {
    expect(issue().isAssignedTo(me), isFalse);
  });
}
