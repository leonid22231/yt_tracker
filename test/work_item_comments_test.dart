import 'package:test/test.dart';
import 'package:youtrack_timer/youtrack/work_item_comments.dart';

void main() {
  test('распознаёт комментарий приложения', () {
    expect(
      WorkItemComments.isAppMarker('AI-оценка youtrack_timer'),
      isTrue,
    );
    expect(
      WorkItemComments.isAppMarker('Обычный комментарий'),
      isFalse,
    );
  });
}
