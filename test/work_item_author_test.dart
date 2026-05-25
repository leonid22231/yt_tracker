import 'package:test/test.dart';
import 'package:youtrack_timer/models/work_item.dart';
import 'package:youtrack_timer/models/youtrack_user.dart';

void main() {
  final me = YouTrackUser(id: '1-1', login: 'ivan', name: 'Ivan');

  YouTrackWorkItem item({
    String? authorId,
    String? authorLogin,
  }) =>
      YouTrackWorkItem(
        id: 'w1',
        date: DateTime(2024, 1, 1),
        minutes: 60,
        authorId: authorId,
        authorLogin: authorLogin,
      );

  test('isAuthoredBy по id', () {
    expect(item(authorId: '1-1').isAuthoredBy(me), isTrue);
    expect(item(authorId: '2-2').isAuthoredBy(me), isFalse);
  });

  test('isAuthoredBy по login без учёта регистра', () {
    expect(item(authorLogin: 'IVAN').isAuthoredBy(me), isTrue);
    expect(item(authorLogin: 'petr').isAuthoredBy(me), isFalse);
  });

  test('без автора в API — учитываем запись', () {
    expect(item().isAuthoredBy(me), isTrue);
  });
}
